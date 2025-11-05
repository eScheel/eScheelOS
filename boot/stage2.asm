;   eScheelOS
;
;   stage2.asm
;
;   Author: Jacob Scheel
;
;   This code will do the following:
;       1) Store the boot drive number passed by boot.bin
;       2) Check and enable A20 using two of three methods. ; TODO: Eventually verify that A20 is actually enabled.
;       3) Initialize video mode and memory map from BIOS.
;       4) Load kernel code at address 4000h parse and relocate to 100000h.   (Seems more simple than parsing from uppermem.)
;       5) Bootstrap and then jump to kernel.elf
;
;   TODO: Write a file system driver to load a kernel from a data region as opposed to flat sectors.
;
[org 0x1000]
[bits 16]

jmp short ENTRY

kernel_addr_tmp equ 0x4000      ; Temporary address in low memory to hold the kernel while we parse elf.
kernel_size equ 32768
kernel_lba  equ 9               ; LBA for kernel.elf on disk.

video_mode: db 0    ; Default video mode passed to kernel via al register.
boot_drive: db 0    ; Boot drive passed to kernel via dl register.

msg_mmap_fail:   db 'error: Failed to get valid memory map form BIOS.',0
msg_kernel_fail: db 'error: Failed to load the kernel.',0
msg_invalid_elf: db 'error: Failed to locate a valid elf file.',0

;=============================================================================================

ENTRY:
    cli
    xor  ax, ax      
    mov  ds, ax             ; Initialize data segment register.
    mov  es, ax             ; Initialize extra data segment register.
    mov  gs, ax
    mov  fs, ax
    mov  ss, ax             
    mov  ax, 0x3000         ; Place stack 4096 bytes above stage2 address.
    mov  sp, ax             ; sp = 0x3000
    sti
.INIT:
    mov [boot_drive], dl      ; Save the boot_drive number.
    call BIOS_ENABLE_A20      ; 
    mov  dl, 3                ; Select video mode. 3 = 80*25
    call BIOS_VIDEO_MODE      ; Set video mode.
    call BIOS_MEMORY_MAP      ; Retrieve memory map from BIOS.
    jc   MEMORY_MAP_FAILED    ; If carry is set, the function failed.
    call LOAD_KERNEL
    call PARSE_ELF_AND_RELOCATE
.BOOTSTRAP:
    cli
    lgdt[GDT_DESC]      ; Load the GDTR register with the base address of the GDT.
    mov eax, cr0        ; Set the PE flag in cr0.
    or  eax, 1          ; We only need to change the bottom bit.
    mov cr0, eax
    mov ax, DATA_SEG    ; Load our data segment selector.
    mov ds, ax
    mov es, ax
    mov gs, ax
    mov fs, ax
    mov ss, ax
    jmp CODE_SEG:BITS32

;=============================================================================================

; Disk Address Packet for int 0x13, ah=0x42
DAP:
    db 0x10             ; Size of this packet (16 bytes)
    db 0                ; Reserved, always 0
.SECTORS:
    dw 0                ; Number of sectors to read. Will be filled in LOAD_KERNEL
.BUFFER:
    dd kernel_addr_tmp  ; 32-bit flat address (segment:offset) where ES:BX will be 0x0000:0x4000
.LBA_START:
    dq kernel_lba       ; 64-bit starting LBA

LOAD_KERNEL:
    mov ax, kernel_size / 512
    mov [DAP.SECTORS], ax
    mov ah, 0x42                ; AH = The "Extended Read" function
    mov dl, [boot_drive]        ; DL = Drive number
    mov si, DAP                 ; DS:SI -> Pointer to our DAP structure
    int 0x13                    ; Call the BIOS interrupt
    jc KERNEL_LOAD_FAILED       ; Check for errors (carry flag is set on failure)
    ret

;=============================================================================================

;   Elf file type is EXEC (Executable file)
;   Entry point 0x100600
;   There are 3 program headers, starting at offset 52
;
;   Program Headers:
;       Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
;       LOAD           0x001000 0x00100000 0x00100000 0x010f9 0x010f9 R E 0x1000
;       LOAD           0x003000 0x00102000 0x00102000 0x008fc 0x05678 RW  0x1000
;       GNU_STACK      0x000000 0x00000000 0x00000000 0x00000 0x00000 RW  0x10
;
;   Section to Segment mapping:
;       Segment Sections...
;       00     .text .rodata 
;       01     .data .bss 
;       02 
;
kernel_entry_point:   dd 0          ; Entry point address defined in the elf header.
program_header_count: dw 0          ; ...
filesz: dw 0
memsz:  dw 0
bsssz:  dw 0
physical_address: dd 0
;
PARSE_ELF_AND_RELOCATE:

    ; This will be used to parse the headers.
    xor si, si
    mov gs, si
    mov si, kernel_addr_tmp ; 4000h is where the LOAD_KERNEL routine loaded the kernel.

    ; This will be used as the source address in lower mem.
    xor bx, bx
    mov es, bx
    mov bx, kernel_addr_tmp + 0x1000    ; Skip past headers as well.

    ; This will be used as the destination address in upper mem.
    mov di, 0xfA00          ; Set up destination segment:offset.
    mov fs, di
    mov di, 0x6000          ; We are putting our kernel at 0x100000 or FA00:6000   

    ; Check the magic to see if valid elf file.
    mov al, byte [gs:si]
    cmp al, 0x7f
    jne ELF_PARSE_FAILED
    mov al, byte [gs:si + 1]
    cmp al, 'E'
    jne ELF_PARSE_FAILED 
    mov al, byte [gs:si + 2]
    cmp al, 'L'
    jne ELF_PARSE_FAILED
    mov al, byte [gs:si + 3]
    cmp al, 'F'
    jne ELF_PARSE_FAILED

    ; Get the kernel offset address address from the header.
    mov  eax, [gs:si + ELF32_HDR.e_entry]
    mov [kernel_entry_point], eax
;    nop
;    mov  dx, [kernel_entry_point + 2]
;    call BIOS_PRINTH
;    mov  dx, [kernel_entry_point]
;    call BIOS_PRINTH
;    mov  al, ' '
;    call BIOS_PRINTC

    ; Get the program header count.
    mov dx, [gs:si + ELF32_HDR.e_phnum]
    mov [program_header_count], dx
;    nop
;    call BIOS_PRINTH
;    call BIOS_PRINTNL

    ; Let's skip past the header now and start reading program headers.
    add si, ELF32_HDR_size

    ; Loop through each program header.
    xor cx, cx
PE_LOOP:
    ; Check if PT_LOAD == 1
    mov eax, [gs:si + ELF32_PHDR.p_type]
    cmp eax, 1
    jne SKIP_PH
;    nop
;    mov  dx, [gs:si + ELF32_PHDR.p_type]
;    call BIOS_PRINTH
;    mov  al, ' '
;    call BIOS_PRINTC

    ; For now we will just get lower 16bits of the memsz and filesz to fill in.
    mov dx, word [gs:si + ELF32_PHDR.p_memsz]
    mov [memsz], dx
;    nop
;    call BIOS_PRINTH
;    mov  al, ' '
;    call BIOS_PRINTC
    ;
    mov dx, word [gs:si + ELF32_PHDR.p_filesz]
    mov [filesz], dx  
;    nop
;    call BIOS_PRINTH
;    mov  al, ' '
;    call BIOS_PRINTC

    ; ...
    mov eax, [gs:si + ELF32_PHDR.p_paddr]
    mov [physical_address], eax

    ; Write the bytes to the destination address.
    push cx     ; Save cx since being used for program_header_count.
    xor  cx, cx
.LOOP:
    mov al, byte [es:bx]
    mov byte [fs:di], al    
    inc di
    inc bx                  ; TODO: Change this to use the rep instruction.
    inc cx
    cmp cx, word [memsz]
    jl .LOOP
    pop cx

    ; Take away what the previous loop incremented for easier calculation.
    sub bx, word [memsz]
    sub di, word [memsz]
;    nop
;    mov  dx, bx
;    call BIOS_PRINTH
;    mov  al, ' '
;    call BIOS_PRINTC
;    mov  dx, di
;    call BIOS_PRINTH
;    mov  al, ' '
;    call BIOS_PRINTC     

    ; If filesz == memsz , we probably ar not padded with zeros.
    mov ax, [memsz]
    cmp ax, [filesz]
    je  SKIP_BSS
    ; Let's get the difference and store it.
    sub  ax, [filesz]
    mov  [bsssz], ax
;    nop
;    mov  dx, [bsssz]
;    call BIOS_PRINTH
;    call BIOS_PRINTNL

    ; Zero BSS ...
    push di
    push cx
    xor  cx, cx
    add  di, [filesz]   ; Let's skip past the actual data size to zero .bss
.LOOP3:
    mov byte [fs:di], 0
    inc di
    inc cx
    cmp cx, [bsssz]
    jl .LOOP3
    pop cx
    pop di

SKIP_BSS:
;    nop
;    call BIOS_PRINTNL

    ; For now we will just skip 0x2000 ahead as it seems the linker adds sections together in 2's.
    ; Padded at 0x1000
    add bx, 0x2000
    add di, 0x2000

    ; Skip to the next phdr.
    add si, ELF32_PHDR_size

    ; Check if we are out of phdrs.
    inc cx
    cmp cx, [program_header_count]
    jl  PE_LOOP

    ret

SKIP_PH:
    ; Skip to the next phdr.
    add si, ELF32_PHDR_size

    ; ...
    inc cx
    cmp cx, [program_header_count]
    jl  PE_LOOP  

    ret

;=============================================================================================

struc ELF32_HDR
	.e_ident:     resb 16     ;	/* File identification. */
	.e_type:      resw 1      ;		/* File type. */
	.e_machine:   resw 1      ;	/* Machine architecture. */
	.e_version:   resd 1      ;	/* ELF format version. */
	.e_entry:     resd 1      ;	/* Entry point. */
	.e_phoff:     resd 1      ;	/* Program header offset. */
	.e_shoff:     resd 1      ;	/* Section header file offset. */
	.e_flags:     resd 1      ;	/* Architecture-specific flags. */
	.e_ehsize:    resw 1      ;	/* Size of ELF header in bytes. */
	.e_phentsize: resw 1      ;	/* Size of program header entry. */
	.e_phnum:     resw 1      ;	/* Number of program header entries. */
	.e_shentsize: resw 1      ;	/* Size of section header entry. */
	.e_shnum:     resw 1      ;	/* Number of section header entries. */
	.e_shstrndx:  resw 1      ;	/* Section name strings section. */
endstruc

struc ELF32_PHDR
    .p_type:      resd 1    ; Specifies the type of segment (e.g., PT_LOAD for loadable segments, PT_DYNAMIC for dynamic linking information).
    .p_offset:    resd 1    ; The offset from the beginning of the ELF file to the start of the segment's data.
    .p_vaddr:     resd 1    ; The virtual address where the segment should be loaded in memory.
    .p_paddr:     resd 1    ; The physical address (relevant for some systems, often the same as p_vaddr for typical applications).
    .p_filesz:    resd 1    ; The size of the segment in the ELF file.
    .p_memsz:     resd 1    ; The size of the segment in memory. This can be larger than p_filesz if the segment contains uninitialized data (e.g., the .bss section), which is zero-filled in memory.
    .p_flags:     resd 1    ; Flags indicating permissions and other attributes of the segment (e.g., PF_R for readable, PF_W for writable, PF_X for executable).
    .p_align:     resd 1    ; The required alignment for the segment in memory.
endstruc

;=============================================================================================

MEMORY_MAP_FAILED:
    lea  si, [msg_mmap_fail]
    call BIOS_PRINTS
    jmp  HALT

KERNEL_LOAD_FAILED:
    lea  si, [msg_kernel_fail]
    call BIOS_PRINTS
    jmp  HALT

ELF_PARSE_FAILED:
    lea  si, [msg_invalid_elf]
    call BIOS_PRINTS 

HALT:
    cli
.LOOP:    
    hlt
    jmp  .LOOP      ; Just incase a nmi hits.

;=============================================================================================

;   Prints a character to the screen.
;   Caller must put character in al register.
;
BIOS_PRINTC:
    pusha
    mov  ah, 0x0e       ; AH = 0x0e (BIOS function "VIDEO - TELETYPE OUTPUT")
    xor  bx, bx         ; BH = page number , BL = color.
    int  0x10
    popa
    ret

;
;
;
BIOS_PRINTNL:
    push ax
    mov  al, 0xa
    call BIOS_PRINTC
    mov  al, 0xd
    call BIOS_PRINTC
    pop  ax
    ret

;   Prints a string of characters to the screen.
;   Caller must put string in si register.
;
BIOS_PRINTS:
    pusha
.LOOP:
    lodsb                   ; Loads a byte from ds:si into al.
    or   al, al             ; Test for null character or if al is zero.
    jz   BIOS_PRINTS_DONE
    call BIOS_PRINTC        ; Print it out.
    jmp .LOOP               ; Do it again.
BIOS_PRINTS_DONE:
    popa
    ret

;   Prints a decimal value to the screen.
;   Caller must put data in AX register.
;
BIOS_PRINTD:
    pusha			    ; Save the stack.
    mov bx, 10		    ; Digits are extracted dividing by ten.
    xor cx, cx		    ; Start the counter off with zero.
.CONV_LOOP:
    mov  dx, 0		    ; Necessary to divide by BX.
    div  bx		        ; DX:AX / 10 = AX(quotient):DX(remainder)
    push dx		        ; Save DX for later use.
    inc  cx		        ; Increment the counter.
    cmp  ax, 0		    ; If number is not zero,
    jne .CONV_LOOP      ; then do it all again.
.DISP_LOOP:
    pop  dx		        ; Restore DX to get our number in reverse now.
    add  dl, 48		    ; Convert digit to character.
    mov  al, dl		    ; Now move our character in AL to be printed.
    call BIOS_PRINTC	; Print it out.
    dec  cx		        ; Decrement our counter.
    cmp  cx, 0		    ; If counter is zero then,
    je  .DONE	        ;  we are done.
    jmp .DISP_LOOP      ; Else, do it again.
.DONE:
    popa		 ; Restore the stack.
    ret			 ; Return.

;   Prints a hex value to the screen.
;   Caller must put data in DX register.
;
BIOS_PRINTH:
    pusha			        ; Save the stack.
    xor  cx, cx		        ; Start our counter off with zero.
    mov  si, bph_hexout     ; Move the addr of our template string into SI.
.NEXT_CHAR:
    mov  bx, dx		        ; Copy the next char into BX to be converted.
    shr  bx, 4		        ; Shift the current char right four times.
    add  bh, 0x30	        ; ASCII numbers start at a value of 0x30 || 48
    cmp  bh, 0x39	        ; ASCII numbers end at a value of   0x39 || 57
    jg  .ADD_SEVEN          ; ASCII (A-F):((57+1)+7):(0x41||65)-(0x46|| 70)
.ADD_CHAR:		
    mov byte [si], bh	    ; Move our current character to the addr of SI.
    inc  si		            ; Increment SI.
    inc  cx		            ; Increment our counter.
    shl  dx, 4		        ; Shift the next character left four times.
    or   dx, dx		        ; Logical OR DX with itself.
    jnz .NEXT_CHAR          ; If DX came back zero then do the next char.
    cmp  cx, 4	 	        ; If counter is four or higher, we are done. 
    jl  .NEXT_CHAR          ; Else, then do the next character.
    mov  si, bph_hexout      ; Move the addr of our formatted templated into SI. 
    call BIOS_PRINTS	    ; And print it out.
    popa		            ; Restore the stack.
    ret			            ; Return.
.ADD_SEVEN:
    add  bh, 0x07	        ; Add seven to BH so we are at (A-F)
    jmp .ADD_CHAR           ; Now add the next character.
bph_hexout: db '0000',0

;
;
;
BIOS_ENABLE_A20:
    mov ax, 0x2402              ; Get A20 gate status.
    int 0x15
    jc .A20_ENABLE_FALLBACK     ; If this fails, jump to the keyboard method!
    cmp al, 0x1                 ; Is it already enabled?
    je .A20_ENABLED             ; Yes, we're done.
    mov ax, 0x2401              ; Try to enable it.
    int 0x15
    jc .A20_ENABLE_FALLBACK     ; If this fails, jump to the keyboard method!
    mov ax, 0x2402              ; Verify it worked.
    int 0x15
    jc .A20_ENABLE_FALLBACK     ; If verification fails, try the other way
    cmp al, 0x1
    je .A20_ENABLED             ; Success!
.A20_ENABLE_FALLBACK:
    cli
    call KB_CONTROLLER_WAIT         ; Wait until controller is ready
    mov  al, 0xad                   ; Command to disable the keyboard
    out  0x64, al
    call KB_CONTROLLER_WAIT
    mov  al, 0xd0                   ; Command to read the output port.
    out  0x64, al
    call KB_WAIT
    in   al, 0x60                   ; Read the output port value
    push ax                         ; Save it
    call KB_CONTROLLER_WAIT
    mov  al, 0xd1                   ; Command to write to the output port
    out  0x64, al
    call KB_CONTROLLER_WAIT
    pop  ax                         ; Get the original value back
    or   al, 0x02                   ; Set bit 1 (the A20 gate enable bit)
    out  0x60, al                   ; Write the new value back
    call KB_CONTROLLER_WAIT
    mov  al, 0xae                   ; Command to enable the keyboard
    out  0x64, al
    call KB_CONTROLLER_WAIT
    sti
.A20_ENABLED:
    ret

; Helper function to wait until the keyboard controller has data ready to be read.
KB_WAIT:
    in   al, 0x64
    test al, 1                      ; Test bit 0 (output buffer status)
    jz   KB_WAIT
    ret

; Helper function to wait until the keyboard controller is ready for a command.
KB_CONTROLLER_WAIT:
    in   al, 0x64
    test al, 2                      ; Test bit 1 (input buffer status)
    jnz  KB_CONTROLLER_WAIT
    ret

;   Sets the video mode. Also can be used to clear the screen?
;   Caller must put desired mode in dl register.
;
BIOS_VIDEO_MODE:
    pusha
    mov  ah, 0x0f                ; AH = 0x0F (BIOS function “Get Video Mode”)
    int  0x10  
    mov [video_mode], al
    cmp  al, dl                  ; Compare current video mode with desired video mode.
    je  .SKIPSETVID              ; If same, let's skip.
    mov  ah, 0x00                ; AH = 0x00 (BIOS function “Set Video Mode”), AL = 0xXX (mode number)
    mov  al, dl
    int  0x10                    ; Call BIOS video interrupt.
    ; TODO: Account for error maybe.
.SKIPSETVID:
    popa
    ret

;   Retrieves the system memory map using INT 0x15, EAX=0xE820.
;   On success: Stores map in mmap_buffer, clears carry flag.
;   On failure: Sets carry flag.
;   Clobbers: EAX, EBX, ECX, EDX, DI, BP
;
BIOS_MEMORY_MAP:
    xor ebx, ebx         ; EBX must be 0 for the first call.
    xor bp, bp           ; BP will count the number of valid entries
    mov di, MMAP_DESC    ; Point DI to the start of the entries array. ES is 0.
    add di, 4           ; I guess if we don't do this then int 15 gets stuck? Need to pass count anyway.
.LOOP:
    mov eax, 0xE820                         ; E820 function number.
    mov edx, 0x534D4150                     ; Magic number 'SMAP'
    mov ecx, SMAP_ENTRY_size                ; Request 24 bytes for ACPI 3.0 compatibility.
    mov dword [es:di + SMAP_ENTRY.acpi], 1  ; ACPI 3.0: ask for extended attributes.
    int 0x15                                ; Call BIOS interrupt.
    jc .ERROR                               ; If carry is set, there's an error.
    ; BIOS may trash EDX, so we restore it for the signature check.
    mov  edx, 0x534D4150
    cmp  eax, edx           ; On success, EAX should return 'SMAP'
    jne .ERROR
    ; If EBX is 0 after the first successful call, it means the list might be empty or just one entry.
    ; The loop condition `test ebx, ebx` will handle this.
    ; Now Validate the returned entry and skip entries with a length of 0.
    mov ecx, [es:di + SMAP_ENTRY.length]
    or  ecx, [es:di + SMAP_ENTRY.length + 4] ; Check if the 64-bit length is zero
    jz .SKIPENT
    ; Check ACPI 3.0 "ignore this entry" bit if we got a 24-byte response.
    cmp  cl, 20
    jbe .NOTACPI3
    test byte [es:di + SMAP_ENTRY.acpi], 1
    je  .SKIPENT
.NOTACPI3:
    inc bp                  ; Increment valid entry count
    add di, SMAP_ENTRY_size ; Move to the next storage spot
.SKIPENT:
    test ebx, ebx           ; If EBX is 0, we are at the end of the list.
    jnz .LOOP               ; If not zero, continue to get the next entry.
    mov [MMAP_DESC], bp     ; Store the final count of valid entries.
    clc                     ; Clear carry flag to indicate success.
    ret
.ERROR:
    stc                     ; Set carry flag to indicate failure
    ret

;=============================================================================================

; A structure for a single E820 memory map entry (24 bytes).
struc SMAP_ENTRY
    .base_addr: resq 1  ; Base Address (64-bit)
    .length:    resq 1  ; Length (64-bit)
    .type:      resd 1  ; Type of memory region (32-bit)
    .acpi:      resd 1  ; ACPI 3.0 Extended Attributes
endstruc
; We'll allocate space for up to 32 entries for now.
SMAP_ENTRY_max equ 32

; A structure to hold the entire memory map, which will be passed to the kernel.
MMAP_DESC:
    dd 0                                               ; Number of valid entries we found
    times (SMAP_ENTRY_max * SMAP_ENTRY_size)  db 0     ; Array of entries

;=============================================================================================

GDT_ENTRY:
    GDT_NULL:
        dw 0x0000   ; Limit (bits 0-15)
        dw 0x0000   ; Base  (bits 0-15)
        db 0x00     ; Base  (bits 15-23)
        db 0x00     ; Type flags
        db 0x00     ; Limit flags
        db 0x00     ; Base (bits 23-31)
    GDT_CODE:
        dw 0xffff   ; Limit (bits 0-15)
        dw 0x0000   ; Base (bits 0-15)
        db 0x00     ; Base (bits 15-23)
        db 0x9a     ; Type flags
        db 0xcf     ; Limit flags
        db 0x00     ; Base (bits 23-31)
    GDT_DATA:
        dw 0xffff   ; Limit (bits 0-15)
        dw 0x0000   ; Base (bits 0-15)
        db 0x00     ; Base (bits 15-23)
        db 0x92     ; Type flags
        db 0xcf     ; Limit flags
        db 0x00     ; Base (bits 23-31)
GDT_END:

CODE_SEG: equ GDT_CODE-GDT_ENTRY
DATA_SEG: equ GDT_DATA-GDT_ENTRY

GDT_DESC:
    dw GDT_END-GDT_ENTRY-1  ; Size of GDT is always (size-1)
    dd GDT_ENTRY            ; Start address of the gdt.

;=============================================================================================

[bits 32]

BITS32:
    ; Pass boot drive and default video mode to kernel.
    mov dl, [boot_drive]      ; Pass boot drive to kernel.
    mov cl, [video_mode]      ; Pass default video mode to kernel.
    mov bx,  MMAP_DESC        ; Pass memory map buffer address to kernel.

    mov eax, [kernel_entry_point]
    jmp EAX

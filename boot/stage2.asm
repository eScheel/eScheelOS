;   eScheelOS Bootloader
;
;   stage2.asm
;
;   Author: Jacob Scheel
;
;   This code will do the following:
;       1) Setup segments and a stack, store the boot drive number passed by boot.bin
;       2) Check and enable A20 using two of three methods. Initialize video mode and memory map with BIOS.
;       3) Load kernel code from lba 9 at address 4000h and bootstrap to 32bits.
;       4) Parse and relocate elf executable to 100000h and pass some info before jumping to kernel.elf
;
;   TODO: Write a file system driver to load a kernel from a data region as opposed to flat sectors.
;
[org 0x1000]
[bits 16]

jmp short ENTRY

kernel_addr_tmp equ 0x4000      ; Temporary address in low memory to hold the kernel while we parse elf.
kernel_size equ 36864
kernel_lba  equ 9               ; LBA for kernel.elf on disk.

video_mode: db 0    ; Default video mode passed to kernel via al register.
boot_drive: db 0    ; Boot drive passed to kernel via dl register.

msg_mmap_fail:   db 'error: Failed to get valid memory map form BIOS.',0
msg_kernel_fail: db 'error: Failed to load the kernel.',0

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

MEMORY_MAP_FAILED:
    lea  si, [msg_mmap_fail]
    call BIOS_PRINTS
    jmp  HALT

KERNEL_LOAD_FAILED:
    lea  si, [msg_kernel_fail]
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
    add di, 4            ; I guess if we don't do this then int 15 gets stuck? Need to pass count anyway.
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

msg_invalid_elf: db 'error: Failed to locate a valid elf file.',0

BITS32:
    mov  ebp, 0x4000    ; Setup temporary stack for 32bit stub.
    call PARSE_ELF_AND_RELOCATE

    ; Pass boot drive and default video mode to kernel.
    xor edx, edx
    xor ecx, ecx
    xor ebx, ebx
    mov dl, [boot_drive]      ; Pass boot drive to kernel.
    mov cl, [video_mode]      ; Pass default video mode to kernel.
    mov bx,  MMAP_DESC        ; Pass memory map buffer address to kernel.

    ; ...
    mov eax, [kernel_entry_point]
    jmp EAX

;=============================================================================================

kernel_entry_point:   dd 0          ; Entry point address defined in the elf header.
program_header_count: dw 0          ; ...
file_size: dd 0
mem_size:  dd 0
bss_size:  dd 0
physical_address: dd 0
section_offset:   dd 0
;
PARSE_ELF_AND_RELOCATE:

    ; This will be used to parse the headers.
    xor esi, esi
    mov esi, kernel_addr_tmp ; 4000h is where the LOAD_KERNEL routine loaded the kernel.

    ; Check the magic to see if valid elf file.
    mov al, byte [esi]
    cmp al, 0x7f
    jne ELF_PARSE_FAILED
    mov al, byte [esi + 1]
    cmp al, 'E'
    jne ELF_PARSE_FAILED 
    mov al, byte [esi + 2]
    cmp al, 'L'
    jne ELF_PARSE_FAILED
    mov al, byte [esi + 3]
    cmp al, 'F'
    jne ELF_PARSE_FAILED

    ; Get the kernel offset address address from the header.
    mov  eax, [esi + ELF32_HDR.e_entry]
    mov [kernel_entry_point], eax

    ; Get the program header count.
    mov dx, [esi + ELF32_HDR.e_phnum]
    mov [program_header_count], dx

    ; Let's skip past the header now and start reading program headers.
    add esi, ELF32_HDR_size

    ; Loop through each program header.
    xor ecx, ecx
PHDR_LOOP:
    ; Check if PT_LOAD == 1
    mov eax, [esi + ELF32_PHDR.p_type]
    cmp eax, 1
    jne ELF_SKIP_PH

    ; Get the memory size and file size from the program header.
    mov eax, [esi + ELF32_PHDR.p_memsz]
    mov [mem_size], eax
    mov eax, [esi + ELF32_PHDR.p_filesz]
    mov [file_size], eax

    ; Get the physical address of where we need to load this section.
    mov eax, [esi + ELF32_PHDR.p_paddr]
    mov [physical_address], eax

    ; ...
    mov eax, [esi + ELF32_PHDR.p_offset]
    mov [section_offset], eax

    ; Set source(ebx) to where BIOS loaded the kernel into lower memory.
    ; Then add the offset to ebx to get the start of the section.
    mov ebx, kernel_addr_tmp
    add ebx, [section_offset]

    ; Set destination(edi) to the physical address where we need to move the kernel.
    mov edi, [physical_address]

    ; Write the bytes to the destination address.
    push ecx            ; Save ecx since being used for program_header_count.
    xor  ecx, ecx
.WRITE_LOOP:
    mov al, byte [ebx]
    mov byte [edi], al    
    inc edi
    inc ebx                  ; TODO: Change this to use the rep instruction.
    inc ecx
    cmp ecx, [file_size]
    jl .WRITE_LOOP
    pop ecx

    ; Take away what the previous loop incremented for easier calculation.
    sub ebx, [file_size]
    sub edi, [file_size]

    ; If filesz == memsz , we probably are not padded with zeros.
    mov eax, [mem_size]
    cmp eax, [file_size]
    je  ELF_SKIP_PH

    ; Let's get the difference and store it.
    sub  eax, [file_size]
    mov  [bss_size], eax

    ; Let's skip past the actual data size to zero .bss
    add edi, [file_size]

    ; Zero BSS ...
    push ecx
    xor  ecx, ecx
.BSS_LOOP:
    mov byte [edi], 0
    inc edi
    inc ecx
    cmp ecx, [bss_size]
    jl .BSS_LOOP
    pop ecx

ELF_SKIP_PH:

    ; Skip to the next phdr.
    add esi, ELF32_PHDR_size

    ; Check if we are out of program headers.
    inc ecx
    cmp cx, [program_header_count]
    jl  PHDR_LOOP  

    ; Looks like we are done with everything.
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

;============================================================================================

vga_off_addr  equ 0xb8000
vga_top_addr  equ 0xb8000 + (80 * 25)
vga_curr_addr: dd 0xb8000

grey_on_black   equ 0x07
vga_curr_color: db  grey_on_black

;   Print a character to the screen.
;   Caller must put character in al register.
;
VGA_PRINTC:
    push ebx
    push ecx
    mov  ebx, [vga_curr_addr]
    mov  ah,  [vga_curr_color]
    mov word [ebx], ax
    add  ebx, 2
    mov [vga_curr_addr], ebx
    pop  ecx
    pop  ebx
    ret

;   Prints a string to the screen.
;   Caller must put string address in esi.
;
VGA_PRINTS:
    push eax
.LOOP:
    mov  al, byte [esi]
    or   al, al
    jz  .DONE
    call VGA_PRINTC
    inc  esi
    jmp .LOOP
.DONE:
    pop eax
    ret

;=============================================================================================

ELF_PARSE_FAILED:
    lea  esi, [msg_invalid_elf]
    call VGA_PRINTS 

HALT32:
    cli
.LOOP:    
    hlt
    jmp  .LOOP      ; Just incase a nmi hits.

times 4096-($-$$) db 0
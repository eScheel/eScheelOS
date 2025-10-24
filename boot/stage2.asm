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
    jmp CODE_SEG:BOOTSTRAP32

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

;
;   kernel.elf
;
;   Entry point address:    0x100150
;
;   Section Headers:
;         [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
;         [ 1] .text             PROGBITS        00100000 001000 000844 00  AX  0   0 4096
;         [ 2] .rodata           PROGBITS        00101000 002000 00004a 00   A  0   0 4096
;         [ 3] .data             PROGBITS        00102000 003000 000014 00  WA  0   0 4096
;         [ 4] .bss              NOBITS          00103000 003014 004c6c 00  WA  0   0 4096
;
;   Program Headers:
;       Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
;       LOAD           0x001000 0x00100000 0x00100000 0x0104a 0x0104a R E 0x1000
;       LOAD           0x003000 0x00102000 0x00102000 0x00014 0x05c6c RW  0x1000
;
;   Eventually we should maybe change this to actually parse the header in the boot loader rather than using i686-elf-readelf.
;   But I'm not sure we need to do that since we know our kernel and this is our bootloader. And this seems to work. So far ..
;
;   EDIT: I am finding out it is becoming very annoying to manually change the code when the kernel changes. I will need to parse elf hdr.
;
kernel_entry_point equ 0x100150                    ; Address that elf_hdr + kernel_code/data will be loaded.
text_rodata_size   equ 0x104a
data_section_size  equ 0x14                        ; If the FileSiz above changes, change this to it.
bss_zero_size      equ 0x5c6c - data_section_size  ; .data(MemSiz - FileSiz) = .bss
;
PARSE_ELF_AND_RELOCATE:
    xor si, si              ; Set up destination segment:offset.
    mov gs, si
    mov si, kernel_addr_tmp ; 4000h is where the LOAD_KERNEL routine loaded the kernel.

    call ENSURE_ELF         ; Let's at least make sure it is an ELF file.
    add si, 0x1000          ; We know that our section .text starts at. + 0x1000 after elf header.

    mov di, 0xfA00          ; Set up destination segment:offset.
    mov fs, di
    mov di, 0x6000          ; We are putting our kernel at 0x100000

    xor cx, cx
.LOOP1:
    mov al, byte [gs:si]
    mov byte [fs:di], al    ; Move whats at section .text into 0x100000
    inc di
    inc si                  ; TODO: Change this to use the rep instruction.
    inc cx
    cmp cx, text_rodata_size
    jl .LOOP1

    mov si, 0x7000          ; This should be where our section .data starts after .text and .rodata. 0x4000 + 0x1000 + 0x2000
    mov di, 0x8000          ; This should be where we load it into memory. fA00h:8000h = 0x102000

    xor cx, cx
.LOOP2:
    mov al, byte [gs:si]
    mov byte [fs:di], al    ; Move whats at section .text into 0x100000
    inc di
    inc si                  ; TODO: Change this to use the rep instruction.
    inc cx
    cmp cx, data_section_size
    jl .LOOP2       

    mov di, 0x8000              ; Let's reset di to be 0x8000 where we loaded .data into upper mem.
    add di, data_section_size   ; Let's skip past the actual data size to zero .bss
    xor cx, cx
.LOOP3:
    mov byte [fs:di], 0
    inc di
    inc cx
    cmp cx, bss_zero_size
    jl .LOOP3

    ret

ENSURE_ELF:
    pusha
;    mov al, byte [gs:di]
;    cmp al, 0x7f
;    jne ELF_PARSE_FAILED
    inc si
    mov al, byte [gs:si]
    cmp al, 'E'
    jne ELF_PARSE_FAILED 
    inc si
    mov al, byte [gs:si]
    cmp al, 'L'
    jne ELF_PARSE_FAILED
    inc si
    mov al, byte [gs:si]
    cmp al, 'F'
    jne ELF_PARSE_FAILED
    popa
    ret

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
    or   al, 2                      ; Set bit 1 (the A20 gate enable bit)
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
    mov ecx, SMAP_entry_size                ; Request 24 bytes for ACPI 3.0 compatibility.
    mov dword [es:di + SMAP_entry.acpi], 1  ; ACPI 3.0: ask for extended attributes.
    int 0x15                                ; Call BIOS interrupt.
    jc .ERROR                               ; If carry is set, there's an error.
    ; BIOS may trash EDX, so we restore it for the signature check.
    mov  edx, 0x534D4150
    cmp  eax, edx           ; On success, EAX should return 'SMAP'
    jne .ERROR
    ; If EBX is 0 after the first successful call, it means the list might be empty or just one entry.
    ; The loop condition `test ebx, ebx` will handle this.
    ; Now Validate the returned entry and skip entries with a length of 0.
    mov ecx, [es:di + SMAP_entry.length]
    or  ecx, [es:di + SMAP_entry.length + 4] ; Check if the 64-bit length is zero
    jz .SKIPENT
    ; Check ACPI 3.0 "ignore this entry" bit if we got a 24-byte response.
    cmp  cl, 20
    jbe .NOTACPI3
    test byte [es:di + SMAP_entry.acpi], 1
    je  .SKIPENT
.NOTACPI3:
    inc bp                  ; Increment valid entry count
    add di, SMAP_entry_size ; Move to the next storage spot
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
struc SMAP_entry
    .base_addr: resq 1  ; Base Address (64-bit)
    .length:    resq 1  ; Length (64-bit)
    .type:      resd 1  ; Type of memory region (32-bit)
    .acpi:      resd 1  ; ACPI 3.0 Extended Attributes
endstruc
; We'll allocate space for up to 16 entries for now.
SMAP_entry_max equ 32

; A structure to hold the entire memory map, which will be passed to the kernel.
MMAP_DESC:
    dd 0                                               ; Number of valid entries we found
    times (SMAP_entry_max * SMAP_entry_size)  db 0     ; Array of entries

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

BOOTSTRAP32:
    mov ax, DATA_SEG        ; Load our data segment selector.
    mov ds, ax
    mov es, ax
    mov gs, ax
    mov fs, ax
    mov ss, ax

    ; Pass boot drive and default video mode to kernel.
    mov dl, [boot_drive]      ; Pass boot drive to kernel.
    mov al, [video_mode]      ; Pass default video mode to kernel.
    mov bx,  MMAP_DESC        ; Pass memory map buffer address to kernel.
    
    ; ...
    jmp CODE_SEG:kernel_entry_point 

;   eScheelOS
;
;   stage2.asm
;
;   Author: Jacob Scheel
;
;   Purpose: This file will do the following:
;       1) Store the boot drive number passed by boot.bin
;       2) Initialize video mode and memory map from BIOS.
;       3) Load kernel.bin code at address A000h and relocate to 100000h. (Not using EDD)
;       4) Bootstrap and then jump to kernel.bin
;
;   TODO: Write a file system driver to load the kernel from a data region as opposed to flat sectors. Also implement LBA as well.
;
[org 0x7e00]
[bits 16]

jmp short ENTRY

kernel_addr_tmp equ 0xA000
kernel_addr equ 0x100000
kernel_size equ 4096
kernel_sect equ 10          ; Sector Offset.

video_mode: db 0    ; Default video mode passed to kernel via al register.
boot_drive: db 0    ; Boot drive passed to kernel via dl register.

msg_mmap_fail:   db 'e','3'
msg_kernel_fail: db 'e','4'

;=============================================================================================

ENTRY:
    cli
    xor  ax, ax      
    mov  ds, ax             ; Initialize data segment register.
    mov  es, ax             ; Initialize extra data segment register.
    mov  gs, ax
    mov  fs, ax
    mov  ss, ax             
    mov  ax, 0x7c00
    mov  sp, ax             ; sp = 0x7c00.
    sti
.INIT:
    mov [boot_drive], dl      ; Save the boot_drive number.
    mov  dl, 3                ; Select video mode. 3 = 80*25
    call BIOS_VIDEO_MODE      ; Set video mode.
    call BIOS_MEMORY_MAP      ; Retrieve memory map from BIOS.
    jc   MEMORY_MAP_FAILED    ; If carry is set, the function failed.
.LOAD_KERNEL:
    ; TODO: For now we will just be lazy and assume the kernel can be loaded at 0xA000 and 0x100000. Seems to be safe in most cases..
    ; The reason for two address is standard BIOS routines are unable to load above 1MB I guess. So load low(A000h), copy high(100000h).
    ; Eventually we will add logic to check memory map and place at actually available location. Maybe, since in most cases ...
    xor bx, bx         
    mov es, bx              ; Indirectly set ES for ES:BX.
    mov bx, kernel_addr_tmp ; Set BX to start of kernel for ES:BX.
    mov al, kernel_size/512 ; Number of sectors to read.
    mov cl, kernel_sect     ; Sector index to read.
    mov ch, 0               ; Cylinder index to read.
    mov dh, 0               ; Head index to read.
    mov dl, [boot_drive]
    mov ah, 0x02            ; BIOS Read Sectors function.
    int 0x13                ; Call BIOS disk interrupt.
    jc  KERNEL_LOAD_FAILED
.RELOCATE_KERNEL:
    xor si, si              ; Set up source segment:offset.
    mov gs, si
    mov si, kernel_addr_tmp ; A000h
    mov di, 0xf800          ; Set up destination segment:offset.
    mov fs, di
    mov di, 0x8000          ; We are putting our kernel at 0x100000
    xor cx, cx
.LOOP:
    mov al, byte [gs:si]
    mov byte [fs:di], al    ; Move whats at 0xA000 into 0x100000
    inc di
    inc si                  ; Change this to use the rep instruction.
    inc cx
    cmp cx, kernel_size
    jl .LOOP
.BOOTSTRAP:
    cli
    lgdt[GDT_DESC]      ; Load the GDTR register with the base address of the GDT.
    mov eax, cr0        ; Set the PE flag in cr0.
    or  eax, 1          ; We only need to change the bottom bit.
    mov cr0, eax
    jmp CODE_SEG:BOOTSTRAP32

;=============================================================================================

MEMORY_MAP_FAILED:
    mov  al, byte [msg_mmap_fail]
    call BIOS_PRINTC
    mov  al, byte [msg_mmap_fail+1]
    call BIOS_PRINTC
    jmp  HALT

KERNEL_LOAD_FAILED:
    mov  al, byte [msg_kernel_fail]
    call BIOS_PRINTC
    mov  al, byte [msg_kernel_fail+1]
    call BIOS_PRINTC

HALT:
    cli         ; Disable Interrupts.
    jmp  $      ; hlt , but safe for NMI as well.

;=============================================================================================

;   Prints a character to the screen.
;   Caller must put character in al register.
;
BIOS_PRINTC:
    push ax
    push bx
    mov  ah, 0x0e       ; AH = 0x0e (BIOS function "VIDEO - TELETYPE OUTPUT")
    xor  bx, bx         ; BH = page number , BL = color.
    int  0x10
    pop  bx
    pop  ax
    ret

;   Sets the video mode. Also can be used to clear the screen?
;   Caller must put desired mode in dl register.
;
BIOS_VIDEO_MODE:
    push ax
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
    pop ax
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
SMAP_entry_max equ 16

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

    ; Pass boot drive and default video mode to kernel.
    mov dl, [boot_drive]      ; Pass boot drive to kernel.
    mov al, [video_mode]      ; Pass default video mode to kernel.
    mov bx,  MMAP_DESC       ; Pass memory map buffer address to kernel.
    
    ; ...
    jmp CODE_SEG:kernel_addr   ; CS:100000h

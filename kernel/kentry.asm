[org 0x100000]
[bits 32]

jmp short ENTRY32

boot_drive: db 0
video_mode: db 0

mmap_desc_addr: dw 0

;magic: db 0x5A,0x55,0x48,0x55,0x49,0x44,0x41,0x49,0   ;'ZUHUIDAI'
magic: db "eScheelOS",0
;magic: db "This is a test string ...",0

;==============================================================================================

ENTRY32:
    mov esp, 0x90000

    mov [boot_drive], dl
    mov [video_mode], al
    mov [mmap_desc_addr], bx

    call TTY_CLEAR
    lea  esi, [magic]
    call TTY_PRINTS
    call TTY_PRINTNL



    jmp  $

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

;=============================================================================================

%include 'kernel/tty.inc'




[org 0x100000]
[bits 32]

_START:
    mov ebp, 0x90000
    mov esp, ebp

    mov [boot_drive], dl
    mov [video_mode], al
    mov [mmap_desc_addr], bx

    call TTY_CLEAR
    lea  esi, [magic]
    call TTY_PRINTS
    call TTY_PRINTNL

    jmp  $

%include 'kernel/tty.inc'

;=============================================================================================

boot_drive: db 0
video_mode: db 0

mmap_desc_addr: dw 0

;magic: db 0x5A,0x55,0x48,0x55,0x49,0x44,0x41,0x49,0   ;'ZUHUIDAI'
magic: db "eScheelOS",0
;magic: db "This is a test string ...",0


[bits 32]

;=============================================================================================

section .text

global _ENTRY
extern kernel_main

_ENTRY:
    mov ebp, stack_top
    mov esp, ebp

    mov [boot_drive], dl
    mov [video_mode], al
    mov [mmap_desc_addr], bx

    call kernel_main

HALT:
    cli
.LOOP    
    hlt
    jmp  .LOOP

;=============================================================================================

section .data

boot_drive: db 0
video_mode: db 0

mmap_desc_addr: dw 0

;=============================================================================================

section .bss

stack_bottom:
    resb 8192       ; The stack grows downward.
stack_top:
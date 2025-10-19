[bits 32]

;=============================================================================================

section .text

global _ENTRY
global OUTB
global INB
extern kernel_main
extern vga_prints

_ENTRY:
    mov ebp, stack_top
    mov esp, ebp

    mov [boot_drive], dl
    mov [video_mode], al
    mov [mmap_desc_addr], bx

    push word [mmap_desc_addr]
    call kernel_main

HALT:
    push dword msg_halted
    call vga_prints
    cli
.LOOP:    
    hlt
    jmp  .LOOP      ; Just incase a nmi hits.

;=============================================================================================

OUTB:
    mov edx, [esp + 4]	; Move first argument onto the stack.
    mov al,  [esp + 8]	; Move second argument onto the stack.
    out dx,  al		    ; Write to the I/O port.
    ret 	

INB:
    mov edx, [esp + 4]	; Move first argument onto the stack.
    in  al,  dx		    ; Read from the I/O port.
    ret

;=============================================================================================

section .rodata

msg_halted: db  "System Halted ...",0

;=============================================================================================

section .data

boot_drive: db 0
video_mode: db 0

mmap_desc_addr: dw 0

;=============================================================================================

section .bss

stack_bottom:
    resb 16384       ; The stack grows downward.
stack_top:
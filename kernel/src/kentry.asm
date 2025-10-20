;   eScheelOS
;
;   kentry.asm
;
;   Author: Jacob Scheel
;
;   This code will do the following:
;       1) Store the boot drive number and the current video mode passed by stage2
;       2) Initialize our own GDT, IDT, PAGING, etc...
;       3) Pass the boot drive number and the current video mode to kernel_main.
;
;   This file also holds some helper routines only available with assembly.
;
[bits 32]

;=============================================================================================

section .text

global _ENTRY
global OUTB
global INB
extern kernel_main
extern vga_prints

_ENTRY:
    mov ebp, stack_top          ; Stack is located at the top of BSS and grows downward.
    mov esp, ebp

    mov [boot_drive], dl        ; So the kernel knows what drive it is on.
    mov [video_mode], al        ; So the kernel knows what video driver to use. vga , vesa.
    mov [mmap_desc_addr], bx    ; So the kernel knows where it should be using memory.

    ; TODO: GDT, IDT, PAGING, ETC... 

    xor  ebx, ebx                   ; Maybe I don't need to do this?
    xor  eax, eax                   ; Just a bit worried about the top bits being initialized.
    xor  edx, edx                   ; I guess I need to push 32bit registers to my kernel main arguments.
    mov  bx, word [mmap_desc_addr]
    mov  al, byte [video_mode]
    mov  dl, byte [boot_drive]
    push edx                    ; Pass boot drive to kernel main.
    push eax                    ; Pass video mode to kernel main.
    push ebx                    ; Pass mmap desc addr to kernel main.
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
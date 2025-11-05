;   eScheelOS
;
;   kentry.asm
;
;   Author: Jacob Scheel
;
;   This code will do the following:
;       1) Setup the stack and store the boot drive number and the current video mode passed by stage2. 
;       2) Reinitialize our own GDT, VGA, System Memory Map, and IDT / ISRs / IRQs.
;       3) Initialize Paging and then call kernel_main to take control.
;
[bits 32]

section .note.GNU-stack
    ; This empty section's presence tells the linker
    ; that the stack should be NON-EXECUTABLE.

;=============================================================================================
section .text

global KERNEL_INIT
extern GDT_REINIT
extern vga_init
extern vga_putc
extern vga_printc
extern vga_prints
extern vga_printh
extern vga_printd
extern memory_map_init
extern memory_map
extern available_memory_map
extern available_memory_size
extern mmap_avail_entry_count
extern REMAP_PICS
extern IDT_INIT
extern timer_init
extern keyboard_init
extern kernel_main
global KERNEL_IDLE
global SYSTEM_HALT

;=============================================================================================

KERNEL_INIT:
    mov ebp, stack_top          ; Stack is located at the top of BSS and grows downward.
    mov esp, ebp
    mov [boot_drive], dl        ; Save some values passed from boot.bin and stage2.bin
    mov [video_mode], cl
    mov [mmap_desc_addr], bx
    call GDT_REINIT                     ; Reinitialize the Global Descriptor Table.
    call vga_init                       ; Initialize graphics array and print for success.
    push dword str_os_name
    call vga_prints
    push dword str_mmap_init            ; Parse and take control of the memory map passed by BIOS.
    call vga_prints
    xor  ebx, ebx
    mov  bx, word [mmap_desc_addr] 
    push ebx
    call memory_map_init                ; This will print some useful values to the screen.
    call REMAP_PICS                     ; Initialize interrupts and service routines.
    call IDT_INIT
    call timer_init
    call keyboard_init
    ;TODO: PAGING. 
    xor  eax, eax
    mov  al, byte [boot_drive]
    push eax
    call kernel_main

;=============================================================================================

KERNEL_IDLE:
.LOOP:
    jmp .LOOP

;=============================================================================================

SYSTEM_HALT:
    push dword str_halted
    call vga_prints
    cli
.LOOP:    
    hlt
    jmp  .LOOP      ; Just incase a nmi hits.

;=============================================================================================
section .rodata

str_os_name:   db "eScheel OS",0xa,0
str_mmap_init: db "Initializing System Memory Map ...",0xa,0
str_halted:    db "System Halted ...",0

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
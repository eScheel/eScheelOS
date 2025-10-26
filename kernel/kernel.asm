;   eScheelOS
;
;   kentry.asm
;
;   Author: Jacob Scheel
;
;   This code will do the following:
;       1) Store the boot drive number and the current video mode passed by stage2
;       2) Setup the stack and initialize our own GDT.
;       3) Continue to setup the IDT, PAGING, etc...
;
;   This is the main kernel file.
;
[bits 32]

;=============================================================================================
section .text

global INIT
global OUTB
global INB
extern vga_init
extern memory_map_init

extern vga_putc
extern vga_printc
extern vga_prints
extern vga_printh
extern vga_printd

extern memory_map
extern available_memory_size
extern available_memory_map

;=============================================================================================

INIT:
    mov ebp, stack_top          ; Stack is located at the top of BSS and grows downward.
    mov esp, ebp

    mov [boot_drive], dl
    mov [video_mode], al
    mov [mmap_desc_addr], bx

    call vga_init                       ; Initialize graphics.
    push dword str_os_name
    call vga_prints
    xor  ebx, ebx                       ; Parse and take control of the memory map passed by BIOS.
    mov  bx, word [mmap_desc_addr] 
    push ebx
    call memory_map_init
    push dword str_total_mem            ; Display total available memory.
    call vga_prints
    xor  edx, edx                             
    mov  eax, dword [available_memory_size]
    mov  ecx, 1048576                   ; Divide by 1024*1024 to get MB value.
    div  ecx                
    push dword eax
    call vga_printd
    push dword str_megabytes
    call vga_prints

HALT:
    push dword str_halted
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

str_halted:    db "System Halted ...",0
str_os_name:   db "eScheel OS",0xa,0
str_total_mem: db "Total Memory: ",0
str_megabytes: db "MB",10,0

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
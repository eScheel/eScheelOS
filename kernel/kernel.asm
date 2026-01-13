[bits 32]

section .note.GNU-stack
    ; This empty section's presence tells the linker
    ; that the stack should be NON-EXECUTABLE.

;=============================================================================================
section .text

global KERNEL_INIT
extern GDT_REINIT
extern vga_init
extern vga_prints
extern draw_logo
extern memory_map_init
extern REMAP_PICS
extern IDT_INIT
extern paging_init
extern timer_init
extern keyboard_init
extern heap_init
extern ide_init
extern fat32_init
extern serial_init
extern tasking_init
extern kernel_task
global SYSTEM_HALT
global EFLAGS_VALUE

;=============================================================================================

KERNEL_INIT:
    cli
    cld

    ; Setup our main kernel stack.
    mov ebp, stack_top
    mov esp, ebp

    ; Save some values passed from boot.bin and stage2.bin
    mov [boot_drive], dl
    mov [video_mode], cl
    mov [mmap_desc_addr], bx

    ; Reinitialize the Global Descriptor Table.
    call GDT_REINIT

    ; We need to set this value early.
    mov byte [tasking_enabled], 0

    ; Initialize graphics array and print for success.
    call vga_init
    call draw_logo
    push dword str_os_name
    call vga_prints
    push dword str_kern_init
    call vga_prints
    add  esp, 8

    ; Parse and take control of the memory map passed by BIOS.
    push dword str_mmap_init
    call vga_prints
    xor  ebx, ebx
    mov  bx, word [mmap_desc_addr] 
    push ebx
    call memory_map_init
    push dword str_okay
    call vga_prints
    add  esp, 12

    ; Initialize interrupts and service routines.
    push dword str_intr_init
    call vga_prints
    call REMAP_PICS
    call IDT_INIT
    push dword str_okay
    call vga_prints
    add  esp, 8
    
    ; Initialize system paging.
    push dword str_page_init
    call vga_prints
    add  esp, 4
    call paging_init
    mov  eax, [page_dir_phys_addr]
    mov  cr3, eax
    mov  eax, cr0
    or   eax, 0x80000000     ; Enable the PG (Paging) bit in CR0
    mov  cr0, eax
    jmp .AFTER_PAGING
.AFTER_PAGING:
    ; No need to remap anything since we are (1:1) identity page mapping.
    push dword str_okay
    call vga_prints
    add  esp, 4

    ; Initialize pit timer.
    push dword str_pit_init
    call vga_prints
    call timer_init
    push dword str_okay
    call vga_prints
    add  esp, 8

    ; Initialize keyboard driver.
    push dword str_kbd_init
    call vga_prints
    call keyboard_init
    push dword str_okay
    call vga_prints
    add  esp, 8

    ; Probably ok to enable interrupts now.
    sti

    ; Initialize the system heap.
    push dword str_heap_init
    call vga_prints
    call heap_init
    push dword str_okay
    call vga_prints
    add  esp, 8

    ; Initialize the IDE driver.
    push dword str_ide_init
    call vga_prints
    call ide_init
    push dword str_okay
    call vga_prints
    add  esp, 8

    ; Initialize fat32 driver.
    push dword str_fat32_init
    call vga_prints
    call fat32_init
    push dword str_okay
    call vga_prints
    add  esp, 8

    ; Initialize serial driver.
    push dword str_rs232_init
    call vga_prints
    call serial_init
    push dword str_okay
    call vga_prints
    add  esp, 8

    ; Initialize multi-tasking.
    push dword str_task_init
    call vga_prints
    call tasking_init
    push dword str_okay
    call vga_prints
    add  esp, 8

    ; This will be TASK[0]. Our main task.
    call kernel_task

;=============================================================================================

SYSTEM_HALT:
    push dword str_halted
    call vga_prints
    add  esp, 4
    cli
.LOOP:    
    hlt
    jmp  .LOOP      ; Just incase a nmi hits.

;=============================================================================================

; Returns the value of eflags register.
EFLAGS_VALUE:
    pushf           ; Push EFLAGS register onto the stack
    pop eax         ; Pop it into EAX to return it
    ret

;=============================================================================================
section .rodata

str_os_name:    db "eScheel OS",0xa,0
str_kern_init:  db "Initializing the kernel:",0xa,0
str_mmap_init:  db "  bios memory map .... ",0
str_intr_init:  db "  interrupts ......... ",0
str_page_init:  db "  identity paging .... ",0
str_pit_init:   db "  pit timer .......... ",0
str_kbd_init:   db "  keyboard driver .... ",0
str_heap_init:  db "  system heap ........ ",0
str_ide_init:   db "  ide driver ......... ",0
str_fat32_init: db "  fat32 driver ....... ",0
str_rs232_init: db "  serial driver ...... ",0
str_task_init:  db "  multi-tasking ...... ",0
str_okay:       db "[OK]",0xa,0
str_halted:     db "System Halted ...",0

;=============================================================================================
section .data

extern tasking_enabled
extern page_dir_phys_addr

boot_drive: db 0
video_mode: db 0
mmap_desc_addr: dw 0

;=============================================================================================
section .bss

stack_bottom:
    resb 16384       ; The stack grows downward.
stack_top:
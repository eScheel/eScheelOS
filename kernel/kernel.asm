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
extern memory_map_init
extern REMAP_PICS
extern IDT_INIT
extern timer_init
extern keyboard_init
extern paging_init
extern heap_init
extern pci_probe_devices
extern ide_init
extern serial_init
extern kernel_main
global SYSTEM_HALT

;=============================================================================================

KERNEL_INIT:
    cli     ; stage2.asm should of done this for us.
    cld     ; boot.asm should of done this for us.

    ; Setup our main kernel stack.
    mov ebp, stack_top
    mov esp, ebp

    ; Save some values passed from boot.bin and stage2.bin
    mov [boot_drive], dl
    mov [video_mode], cl
    mov [mmap_desc_addr], bx

    ; Reinitialize the Global Descriptor Table.
    call GDT_REINIT

    ; Initialize graphics array and print for success.
    call vga_init
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
    call timer_init
    call keyboard_init
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
    ; No need to remap anything since we are 1:1 page mapping.
    push dword str_okay
    call vga_prints
    add  esp, 4

    ; Probably ok to enable interrupts now.
    sti

    ; Initialize the system heap.
    push dword str_heap_init
    call vga_prints
    call heap_init
    push dword str_okay
    call vga_prints
    add  esp, 8

    ; Probe for device controllers.
    push dword str_pci_probe
    call vga_prints
    call pci_probe_devices
    push dword str_okay
    call vga_prints
    add  esp, 8

    ; Initialize the IDE driver.
    push dword str_ide_init
    call vga_prints
    xor  edx, edx
    mov  dl, byte [boot_drive]
    push edx
    call ide_init
    push dword str_okay
    call vga_prints
    add  esp, 12

    ; Initialize serial driver.
    push dword str_rs232_init
    call vga_prints
    call serial_init
    push dword str_okay
    call vga_prints
    add  esp, 8

    ; ...
    call kernel_main

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
section .rodata

str_os_name:   db "eScheel OS",0xa,0
str_kern_init: db "Initializing the kernel:",0xa,0
str_mmap_init: db "  bios memory map ... ",0
str_intr_init: db "  interrupts ........ ",0
str_page_init: db "  identity paging ... ",0
str_heap_init: db "  system heap ....... ",0
str_pci_probe: db "  pci devices ....... ",0
str_ide_init:  db "  ide driver ........ ",0
str_rs232_init:db "  serial driver ..... ",0
str_okay:      db "[OK]",0xa,0
str_halted:    db "System Halted ...",0

;=============================================================================================
section .data

extern page_dir_phys_addr

boot_drive: db 0
video_mode: db 0
mmap_desc_addr: dw 0

;=============================================================================================
section .bss

stack_bottom:
    resb 16384       ; The stack grows downward.
stack_top:
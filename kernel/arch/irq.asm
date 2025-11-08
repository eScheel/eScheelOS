[bits 32]

section .note.GNU-stack
    ; This empty section's presence tells the linker
    ; that the stack should be NON-EXECUTABLE.

;=============================================================================================
section .text

global REMAP_PICS
global IRQ1_HANDLER
global IRQ0_HANDLER
global IRQ14_HANDLER

extern keyboard_interrupt_handler
extern timer_interrupt_handler
extern ide_interrupt_handler

;=============================================================================================
;
;		     PIC1	PIC2
;	Command  0x20	0xA0
;	Data	 0x21	0xA1
REMAP_PICS:
    ; ICW1 - begin initialization
    mov al, 0x11
    out 0x20, al      
    out 0xa0, al

    ; ICW2 - remap offset address of IDT
    mov al, 0x20    ; PIC1 (IRQs 0-7)  -> IDT entries 0x20-0x27 (32-39)
    out 0x21, al      
    mov al, 0x28    ; PIC2 (IRQs 8-15) -> IDT entries 0x28-0x2F (40-47)
    out 0xa1, al

    ; ICW3 - setup cascading
    mov al, 0x04    ; Master (PIC1) needs to know *which* IR line the slave is on.
    out 0x21, al    ; It's on line 2, so we set bit 2 (00000100b = 0x04) 
    mov al, 0x02    ; Slave (PIC2) needs to know *its* IR line number (0-7)
    out 0xa1, al    ; It's on line 2 (00000010b = 0x02)

    ; ICW4 - environment info
    mov al, 0x01
    out 0x21, al      
    out 0xa1, al

    ; Mask interrupts accordingly.
    mov al, 0xfc        ; 11111100b.
    out 0x21, al        ; Send mask to PIC1
    mov al, 0xdf        ; 11011111b.
    out 0xa1, al        ; Send mask to PIC2

    ret

;=============================================================================================
;
; This is the handler for IRQ 0 (PIT)
; After remapping, it's at IDT entry 32 (0x20)
IRQ0_HANDLER:
    pusha
    call timer_interrupt_handler
    mov  al, 0x20
    out  0x20, al
    popa
    iret

; This is the handler for IRQ 1 (keyboard)
IRQ1_HANDLER:
    pusha                               ; Save all general-purpose registers
    call keyboard_interrupt_handler 
    mov al, 0x20                        ; ACK PIC1 for the interrupt to stop firing.
    out 0x20, al
    popa                                ; Restore all registers
    iret                                ; Return from interrupt

; This is the handler for IRQ 14 (primary ata)
IRQ14_HANDLER:
    pusha                               ; Save all general-purpose registers
    call ide_interrupt_handler
    mov al, 0xa0                        ; ACK PIC2 for the interrupt to stop firing.
    out 0xa0, al
    mov al, 0x20                        ; ACK PIC1 either way.
    out 0x20, al
    popa                                ; Restore all registers
    iret                                ; Return from interrupt
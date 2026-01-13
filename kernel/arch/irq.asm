[bits 32]

section .note.GNU-stack
    ; This empty section's presence tells the linker
    ; that the stack should be NON-EXECUTABLE.

;=============================================================================================
section .text

global REMAP_PICS
global IRQ1_HANDLER
global IRQ0_HANDLER
global IRQ4_HANDLER
global IRQ14_HANDLER

extern keyboard_interrupt_handler
extern timer_interrupt_handler
extern com1_interrupt_handler
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
    mov al, 0xf8        ; 11111000b.
    out 0x21, al        ; Send mask to PIC1
    mov al, 0xbf        ; 10111111b.
    out 0xa1, al        ; Send mask to PIC2

    ret

;=============================================================================================
;
; After remapping, it's at IDT entry 32 (0x20)
; This is the handler for IRQ 0 (PIT)
; This is also used for round robin scheduling.
IRQ0_HANDLER:
    pusha
    mov  eax, esp                   ; Get the current stack pointer
    push eax                        ; Push it as an argument for current_esp.
    call timer_interrupt_handler    ; Call the C handler. It returns the NEW esp in EAX.
    add  esp, 4                     ; Clean up the argument we pushed
    ; We are overwriting the esp register. 
    ; esp no longer points to the stack of the task that was interrupted. 
    ; It now points to the top of the stack for the new task that the scheduler chose.
    mov  esp, eax       ; Load the new task's stack pointer into ESP.
    mov  al, 0x20       ; ACK the interrupt.
    out  0x20, al
    popa
    iret

; This is the handler for IRQ 1 (keyboard)
IRQ1_HANDLER:
    pusha                               ; Save all general-purpose registers
    call keyboard_interrupt_handler 
    mov  al, 0x20                        ; ACK PIC1 for the interrupt to stop firing.
    out  0x20, al
    popa                                ; Restore all registers
    iret                                ; Return from interrupt

; This is the handler for IRQ 4 (COM1)
IRQ4_HANDLER:
    pusha                               ; Save all general-purpose registers
    call com1_interrupt_handler 
    mov  al, 0x20                       ; ACK PIC1 for the interrupt to stop firing.
    out  0x20, al
    popa                                ; Restore all registers
    iret                                ; Return from interrupt

; This is the handler for IRQ 14 (primary ata)
IRQ14_HANDLER:
    pusha                               ; Save all general-purpose registers
    call ide_interrupt_handler
    mov  al, 0x20                        ; ACK PIC2 for the interrupt to stop firing.
    out  0xa0, al
    mov  al, 0x20                        ; ACK PIC1 either way.
    out  0x20, al
    popa                                ; Restore all registers
    iret                                ; Return from interrupt
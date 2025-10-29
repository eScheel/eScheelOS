;=============================================================================================
section .text

global REMAP_PICS           ;; --- NEW ---
global irq1_handler         ;; --- NEW ---

extern INB, OUTB            ;; --- NEW ---
extern vga_prints           ;; --- NEW ---

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
    ; PIC1 (IRQs 0-7)  -> IDT entries 0x20-0x27 (32-39)
    ; PIC2 (IRQs 8-15) -> IDT entries 0x28-0x2F (40-47)
    mov al, 0x20
    out 0x21, al      
    mov al, 0x28
    out 0xa1, al

    ;; --- NEW ---
    ; ICW3 - setup cascading
    ; Master (PIC1) needs to know *which* IR line the slave is on.
    ; It's on line 2, so we set bit 2 (00000100b = 0x04)
    mov al, 0x04
    out 0x21, al
    ; Slave (PIC2) needs to know *its* IR line number (0-7)
    ; It's on line 2 (00000010b = 0x02)
    mov al, 0x02
    out 0xa1, al
    ;; --- END NEW ---

    ; ICW4 - environment info
    mov al, 0x01
    out 0x21, al      
    out 0xa1, al

    ; Mask all interrupts for now
    mov al, 0xff
    out 0x21, al      
    out 0xa1, al

    ;; --- NEW ---
    ;; Unmask the keyboard interrupt (IRQ 1)
    mov al, 0xfd        ; 11111101b. Bit 1 (keyboard) is 0 (unmasked).
    out 0x21, al        ; Send new mask to PIC1
    ;; --- END NEW ---

    ret


;; --- NEW ---
;; irq1_handler: This is the handler for IRQ 1 (keyboard)
;; After remapping, it's at IDT entry 33 (0x21)
irq1_handler:
    pusha                   ; Save all general-purpose registers

    ; We *must* read from the keyboard's data port (0x60)
    ; to acknowledge the interrupt, otherwise it will keep firing.
    in al, 0x60
    
    ; We don't do anything with the scancode yet, just print a message
    push dword str_key_press
    call vga_prints
    add esp, 4

    ; CRITICAL: We *must* send an End of Interrupt (EOI) signal
    ; to the PIC chip, or it won't send any more interrupts.
    ; Since this was from PIC1 (master), we only send to 0x20.
    mov al, 0x20
    out 0x20, al

    popa                    ; Restore all registers
    iret                    ; Return from interrupt
;; --- NEW ---


;=============================================================================================
section .rodata           ;; --- NEW ---

str_key_press: db "Key Pressed!", 0xa, 0
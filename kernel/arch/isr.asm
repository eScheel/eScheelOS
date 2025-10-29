;=============================================================================================
section .text

global isr_stub         ;; --- NEW ---

extern vga_prints       ;; --- NEW ---

;; --- NEW ---
;; isr_stub: Our generic, "catch-all" interrupt handler
isr_stub:
    pusha                   ; Save all general-purpose registers (eax, ecx, etc.)

    push dword str_unhandled
    call vga_prints         ; Print "Unhandled Interrupt!"
    add  esp, 4             ; Clean up stack

    ;; This is a stub, so we still need to send an EOI (End of Interrupt)
    ;; just in case this was a hardware interrupt.
    ;; It's safe to send to both.
    mov al, 0x20
    out 0x20, al            ; EOI to PIC1
    out 0xA0, al            ; EOI to PIC2

    popa                    ; Restore all registers
    iret                    ; Return from interrupt
;; --- NEW ---

;=============================================================================================
section .rodata           ;; --- NEW ---

str_unhandled: db "Unhandled Interrupt!", 0xa, 0
;=============================================================================================
section .text

global ISR_STUB

extern vga_prints

;; isr_stub: Our generic, "catch-all" isr handler
ISR_STUB:
    pusha                   ; Save all general-purpose registers (eax, ecx, etc.)

    push dword str_unhandled
    call vga_prints         ; Print "Unhandled Interrupt!"
    add  esp, 4             ; Clean up stack

    ; This is a stub, so we still need to send an EOI (End of Interrupt) just in case this was a hardware interrupt.
    ; For now we will just send the ACK to both PICs.
    mov al, 0x20
    out 0x20, al            ; EOI to PIC1
    out 0xA0, al            ; EOI to PIC2

    popa                    ; Restore all registers
    iret                    ; Return from interrupt

;=============================================================================================
section .rodata 

str_unhandled: db "Unhandled Interrupt!", 0xa, 0

;Exception # 	Description 	Error Code?
;0 	Division By Zero Exception 	No
;1 	Debug Exception 	No
;2 	Non Maskable Interrupt Exception 	No
;3 	Breakpoint Exception 	No
;4 	Into Detected Overflow Exception 	No
;5 	Out of Bounds Exception 	No
;6 	Invalid Opcode Exception 	No
;7 	No Coprocessor Exception 	No
;8 	Double Fault Exception 	Yes
;9 	Coprocessor Segment Overrun Exception 	No
;10 	Bad TSS Exception 	Yes
;11 	Segment Not Present Exception 	Yes
;12 	Stack Fault Exception 	Yes
;13 	General Protection Fault Exception 	Yes
;14 	Page Fault Exception 	Yes
;15 	Unknown Interrupt Exception 	No
;16 	Coprocessor Fault Exception 	No
;17 	Alignment Check Exception (486+) 	No
;18 	Machine Check Exception (Pentium/586+) 	No
;19 to 31 	Reserved Exceptions 	No
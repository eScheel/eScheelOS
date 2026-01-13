[bits 32]

section .note.GNU-stack
    ; This empty section's presence tells the linker
    ; that the stack should be NON-EXECUTABLE.

;=============================================================================================
section .text

global IDT_INIT
global IDT_SET_GATE     
extern CODE_SEG
extern ISR_0
extern ISR_1
extern ISR_2
extern ISR_3
extern ISR_4
extern ISR_5
extern ISR_6
extern ISR_7
extern ISR_8
extern ISR_9
extern ISR_10
extern ISR_11
extern ISR_12
extern ISR_13
extern ISR_14
extern ISR_15
extern ISR_16
extern ISR_17
extern ISR_18
extern ISR_STUB
extern ISR_ROUTINES
extern IRQ0_HANDLER      
extern IRQ1_HANDLER
extern IRQ4_HANDLER
extern IRQ14_HANDLER

;=============================================================================================

IDT_INIT:
    lidt[IDT_DESC]      ; Load the descriptor. We can do this now and fill it in after.

    ; Loop through first 32 ISRs and set the exceptions.
    xor  ecx, ecx
    mov  edx, ISR_ROUTINES
.ISR_LOOP:
    mov  eax, [edx]     ; Get the current ISR_ROUTINE
    push ecx            ; Push the number.
    push eax            ; Push the address.
    call IDT_SET_GATE
    pop  eax
    pop  ecx
    ;
    add  edx, 4         ; Each ISR_ROUTINE is a double word.
    inc  ecx
    cmp  ecx, 31        ; Exceptions are 0 - 31.
    jl  .ISR_LOOP

    ; Loop is complete.
    ; Now, we manually set for the IRQS we want to use.(32-48)
.IRQS:    
    push dword 32
    push dword IRQ0_HANDLER     ; PIT
    call IDT_SET_GATE
    add  esp, 8
    ;
    push dword 33
    push dword IRQ1_HANDLER     ; KBD
    call IDT_SET_GATE
    add  esp, 8
    ;
    push dword 36
    push dword IRQ4_HANDLER     ; COM1
    call IDT_SET_GATE
    add  esp, 8
    ;
    push dword 46
    push dword IRQ14_HANDLER    ; Primary ATA
    call IDT_SET_GATE
    add esp, 8

    ret

;=============================================================================================
;
; IDT_SET_GATE(interrupt_number, handler_address)
; Expects: [ebp + 8] = handler_address (pushed last)
;          [ebp + 12] = interrupt_number (pushed first)
IDT_SET_GATE:
    push ebp
    mov  ebp, esp
    mov  eax, [ebp + 12]    ; Get the interrupt number (arg 2)
    mov  ebx, [ebp + 8]     ; Get the handler address (arg 1)
    
    ; Each IDT entry is 8 bytes, so we multiply the number by 8
    shl  eax, 3                                     ; eax = eax * 8
    add  eax, IDT_PTR                               ; eax is now the address of the correct IDT_ENTRY
    mov  [eax + IDT_ENTRY.offset_low], bx           ; [eax + 0] = offset_low (lower 16 bits of handler address)    
    mov  word [eax + IDT_ENTRY.selector], CODE_SEG  ; [eax + 2] = selector (our GDT code segment selector)
    mov  byte [eax + IDT_ENTRY.zero], 0             ; [eax + 4] = zero (must be 0)
    mov  byte [eax + IDT_ENTRY.type], 0x8E          ; [eax + 5] = type flags (0x8E = 32-bit Interrupt Gate, Ring 0, Present)  
    
    ; [eax + 6] = offset_high (upper 16 bits of handler address)
    shr  ebx, 16                                    ; Shift high bits of address into low bits
    mov  [eax + IDT_ENTRY.offset_high], bx          ; Store them

    pop  ebp
    ret


;=============================================================================================
section .data

struc IDT_ENTRY
    .offset_low:  resw 1
    .selector:    resw 1
    .zero:        resb 1
    .type:        resb 1
    .offset_high: resw 1
endstruc
; Intel has a max of 256 entries.
IDT_ENTRY_max equ   256

IDT_PTR:
    times (IDT_ENTRY_max * IDT_ENTRY_size) db 0

IDT_DESC:
    dw  (IDT_ENTRY_max * IDT_ENTRY_size) - 1
    dd  IDT_PTR
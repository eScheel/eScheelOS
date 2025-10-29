;=============================================================================================
section .text

global IDT_INIT
global IDT_SET_GATE     

extern CODE_SEG
extern isr_stub         
extern irq1_handler     

IDT_INIT:
    mov  ecx, 256           
    mov  eax, isr_stub      
.LOOP:
    dec  ecx                
    push ecx                
    push eax                
    
    call IDT_SET_GATE
    
    pop  eax                
    pop  ecx                
    
    test ecx, ecx           
    jnz .LOOP              

    push dword 33           
    push dword irq1_handler 
    call IDT_SET_GATE
    add  esp, 8             

    lidt[IDT_DESC]
    ret


;; IDT_SET_GATE(interrupt_number, handler_address)
;; Expects: [ebp + 8] = handler_address (pushed last)
;;          [ebp + 12] = interrupt_number (pushed first)
IDT_SET_GATE:
    push ebp
    mov  ebp, esp

    ;; --- FIX ---
    ;; Load interrupt number into EAX
    ;; Load handler address into EBX
    mov  eax, [ebp + 12]    ; Get the interrupt number (arg 2)
    mov  ebx, [ebp + 8]     ; Get the handler address (arg 1)
    ;; --- END FIX ---
    
    ; Each IDT entry is 8 bytes, so we multiply the number by 8
    shl  eax, 3             ; eax = eax * 8
    add  eax, IDT_PTR       ; eax is now the address of the correct IDT_ENTRY

    ; [eax + 0] = offset_low (lower 16 bits of handler address)
    mov  [eax], bx          
    
    ; [eax + 2] = selector (our GDT code segment selector)
    mov  word [eax + 2], CODE_SEG
    
    ; [eax + 4] = zero (must be 0)
    mov  byte [eax + 4], 0
    
    ; [eax + 5] = type flags (0x8E = 32-bit Interrupt Gate, Ring 0, Present)
    mov  byte [eax + 5], 0x8E
    
    ; [eax + 6] = offset_high (upper 16 bits of handler address)
    shr  ebx, 16            ; Shift high bits of address into low bits
    mov  [eax + 6], bx      ; Store them
    
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
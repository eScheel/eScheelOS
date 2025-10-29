;=============================================================================================
section .text

global IDT_INIT
global IDT_SET_GATE     

extern CODE_SEG
extern ISR_STUB         
extern IRQ1_HANDLER     

IDT_INIT:
    mov  ecx, 256               ; Set up a loop to initialize all 256 IDT entries.
    mov  eax, ISR_STUB          ; EAX will hold the address of the default "catch-all" handler.
.LOOP:
    dec  ecx                ; This value (255, 254, ... 0) will be our interrupt number.
    
    ; Prepare to call IDT_SET_GATE(interrupt_number, handler_address)
    ; The cdecl calling convention pushes arguments onto the stack from right to left.
    push ecx                ; Push the first argument (interrupt_number), which is our counter (ECX).
    push eax                ; Push the second argument (handler_address), which is in EAX.
    call IDT_SET_GATE
    
    ; --- Clean up the stack after the call ---
    ; We pushed EAX and ECX (8 bytes total), but IDT_SET_GATE
    ; doesn't clean up its own stack arguments (per cdecl).
    ; We can't just use `add esp, 8` here because we need the values
    ; back in their registers for the loop.
    pop  eax                ; Restore the handler address to EAX for the next loop iteration.
    pop  ecx                ; Restore the counter to ECX.
    test ecx, ecx           ; Check if ECX is zero.
    jnz .LOOP

    ; --- Loop is finished, all 256 entries now point to isr_stub ---
    
    ; Now, we override a specific entry for the keyboard (IRQ 1).
    ; After remapping, IRQ 1 becomes interrupt number 33 (0x20 + 1).
    push dword 33           ; Push the interrupt number (33). Keyboard.
    push dword IRQ1_HANDLER ; Push the specific handler address for the keyboard.
    call IDT_SET_GATE       ; Call the function to set IDT entry 33.
    
    add  esp, 8             ; Clean up the 8 bytes (2 dwords) we pushed for this call.
    lidt[IDT_DESC]          ; All entries are set. Load the IDT Register (IDTR) with the address and size of our new IDT. The CPU will now use this table.
    ret


;; IDT_SET_GATE(interrupt_number, handler_address)
;; Expects: [ebp + 8] = handler_address (pushed last)
;;          [ebp + 12] = interrupt_number (pushed first)
IDT_SET_GATE:
    push ebp
    mov  ebp, esp
    mov  eax, [ebp + 12]    ; Get the interrupt number (arg 2)
    mov  ebx, [ebp + 8]     ; Get the handler address (arg 1)
                            ; Each IDT entry is 8 bytes, so we multiply the number by 8
    shl  eax, 3             ; eax = eax * 8
    add  eax, IDT_PTR       ; eax is now the address of the correct IDT_ENTRY
    mov  [eax], bx                  ; [eax + 0] = offset_low (lower 16 bits of handler address)    
    mov  word [eax + 2], CODE_SEG   ; [eax + 2] = selector (our GDT code segment selector)
    mov  byte [eax + 4], 0          ; [eax + 4] = zero (must be 0)
    mov  byte [eax + 5], 0x8E       ; [eax + 5] = type flags (0x8E = 32-bit Interrupt Gate, Ring 0, Present)  
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
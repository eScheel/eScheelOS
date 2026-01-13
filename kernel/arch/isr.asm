[bits 32]

section .note.GNU-stack
    ; This empty section's presence tells the linker
    ; that the stack should be NON-EXECUTABLE.

;=============================================================================================
section .text

global ISR_0
global ISR_1
global ISR_2
global ISR_3
global ISR_4
global ISR_5
global ISR_6
global ISR_7
global ISR_8
global ISR_9
global ISR_10
global ISR_11
global ISR_12
global ISR_13
global ISR_14
global ISR_15
global ISR_16
global ISR_17
global ISR_18
global ISR_19
global ISR_20
global ISR_21
global ISR_22
global ISR_23
global ISR_24
global ISR_25
global ISR_26
global ISR_27
global ISR_28
global ISR_29
global ISR_30
global ISR_31
global ISR_STUB
extern DATA_SEG
extern fault_handler
extern vga_prints
global ISR_ROUTINES

;=============================================================================================

; 0: Divide By Zero         
ISR_0:         
    cli             
    push byte 0         
    push byte 0         
    jmp  ISR_STUB     

; 1: Debug
ISR_1:         
    cli         
    push byte 0     
    push byte 1     
    jmp  ISR_STUB 

; 2: Non Maskable Interrupt
ISR_2:         
    cli         
    push byte 0     
    push byte 2     
    jmp  ISR_STUB 

; 3: Int 3  
ISR_3:         
    cli         
    push byte 0     
    push byte 3     
    jmp  ISR_STUB 

; 4: INTO   
ISR_4:         
    cli         
    push byte 0     
    push byte 4     
    jmp  ISR_STUB 

; 5: Out of Bounds 
ISR_5:         
    cli         
    push byte 0     
    push byte 5     
    jmp  ISR_STUB 

; 6: Invalid Opcode
ISR_6:         
    cli         
    push byte 0     
    push byte 6     
    jmp  ISR_STUB 

; 7: Coprocessor Not Available
ISR_7:         
    cli         
    push byte 0     
    push byte 7     
    jmp  ISR_STUB 

; 8: Double Fault  With Error Code
ISR_8:         
    cli         
    push byte 8     
    jmp  ISR_STUB 

; 9: Coprocessor Segment Overrun
ISR_9:         
    cli         
    push byte 0     
    push byte 9     
    jmp  ISR_STUB 

; 10: Bad TSS With Error Code
ISR_10:        
    cli         
    push byte 10    
    jmp  ISR_STUB 

; 11: Seg Not Present With Err Code
ISR_11:        
    cli         
    push byte 11    
    jmp  ISR_STUB 

; 12: Stack Fault With Error Code
ISR_12:        
    cli         
    push byte 12    
    jmp  ISR_STUB 

; 13: Gen Protect Fault With Error Code
ISR_13:        
    cli         
    push byte 13    
    jmp  ISR_STUB 

; 14: Page Fault With Error Code
ISR_14:
    cli         
    push byte 14    
    jmp  ISR_STUB 

; 15: Reserved
ISR_15: 
    cli         
    push byte 0     
    push byte 15    
    jmp  ISR_STUB 

; 16: Floating Point
ISR_16:
    cli         
    push byte 0     
    push byte 16    
    jmp  ISR_STUB 

; 17: Alignment Check 
ISR_17:
    cli         
    push byte 0     
    push byte 17    
    jmp  ISR_STUB 

; 18: Machine Check
ISR_18:
    cli         
    push byte 0     
    push byte 18    
    jmp  ISR_STUB

; 19: Reserved
ISR_19:    
    cli     
    push byte 0   
    push byte 19  
    jmp ISR_STUB 
 
; 20: Reserved  
ISR_20:    
    cli     
    push byte 0   
    push byte 20  
    jmp ISR_STUB 

; 21: Reserved      
ISR_21:    
    cli     
    push byte 0   
    push byte 21  
    jmp ISR_STUB 
   
; 22: Reserved
ISR_22:    
    cli     
    push byte 0   
    push byte 22  
    jmp ISR_STUB 
  
; 23: Reserved
ISR_23:    
    cli     
    push byte 0   
    push byte 23  
    jmp ISR_STUB 

; 24: Reserved  
ISR_24:    
    cli     
    push byte 0   
    push byte 24  
    jmp ISR_STUB 

; 25: Reserved  
ISR_25:    
    cli     
    push byte 0   
    push byte 25  
    jmp ISR_STUB 
  
; 26: Reserved
ISR_26:    
    cli     
    push byte 0   
    push byte 26  
    jmp ISR_STUB 

; 27: Reserved  
ISR_27:    
    cli     
    push byte 0   
    push byte 27  
    jmp ISR_STUB 
   
; 28: Reserved
ISR_28:    
    cli     
    push byte 0   
    push byte 28  
    jmp ISR_STUB 
  
; 29: Reserved
ISR_29:    
    cli     
    push byte 0   
    push byte 29  
    jmp ISR_STUB 

; 30: Reserved
ISR_30:    
    cli     
    push byte 0   
    push byte 30  
    jmp ISR_STUB 
 
; 31: Reserved  
ISR_31:    
    cli     
    push byte 0   
    push byte 31  
    jmp ISR_STUB

;=============================================================================================

ISR_STUB:
    ; The interrupted code (especially if it was in user-mode) might have had different segments loaded.
    ; The kernel needs to save them before loading its own.
    pusha 
    push ds	  
    push es	  
    push fs			  
    push gs

    ; This block switches the processor's view of memory to the kernel's. 	
    mov  ax, DATA_SEG	  ; Set up for kernel mode segments.
    mov  ds,  ax			
    mov  es,  ax			
    mov  fs,  ax			
    mov  gs,  ax	

    ; After all the push instructions, esp (the stack pointer) 
    ; now points to the top of a complete structure containing all the saved registers.
    mov  eax, esp
    push eax		 
    call fault_handler
    pop  eax    ; Removes the argument (the pointer) that was pushed.

    ; Restores the original data segment registers from the stack.
    pop  gs			
    pop  fs			
    pop  es			
    pop  ds	
    popa			; Restores stack frame.

    ; The stubs without an error code (like ISR_1) pushed a dummy error code (4 bytes) and the interrupt number (4 bytes).
    ; The stubs with an error code (like ISR_13) just pushed the interrupt number (4 bytes) (since the CPU already pushed the error code).
    ; In both cases, we needed to add 8 bytes to the stack before jumping here.
    add  esp, 8		; Clean the pushed err_code & isr_num
    iret			; Interrupt Return.

;=============================================================================================

section .data

; A list of ISR Addresses for use in IDT_SET_GATE.
ISR_ROUTINES:
    dd ISR_0
    dd ISR_1
    dd ISR_2
    dd ISR_3
    dd ISR_4
    dd ISR_5
    dd ISR_6
    dd ISR_7
    dd ISR_8
    dd ISR_9
    dd ISR_10
    dd ISR_11
    dd ISR_12
    dd ISR_13
    dd ISR_14
    dd ISR_15
    dd ISR_16
    dd ISR_17
    dd ISR_18
    dd ISR_19
    dd ISR_20
    dd ISR_21
    dd ISR_22
    dd ISR_23
    dd ISR_24
    dd ISR_25
    dd ISR_26
    dd ISR_27
    dd ISR_28
    dd ISR_29
    dd ISR_30
    dd ISR_31


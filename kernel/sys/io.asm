[bits 32]

section .note.GNU-stack
    ; This empty section's presence tells the linker
    ; that the stack should be NON-EXECUTABLE.

;=============================================================================================
section .text

global OUTB
global INB

OUTB:
    mov edx, [esp + 4]	; Move first argument onto the stack.
    mov al,  [esp + 8]	; Move second argument onto the stack.
    out dx,  al		    ; Write to the I/O port.
    ret 	

INB:
    mov edx, [esp + 4]	; Move first argument onto the stack.
    in  al,  dx		    ; Read from the I/O port.
    ret
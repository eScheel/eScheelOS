[bits 32]

section .note.GNU-stack
    ; This empty section's presence tells the linker
    ; that the stack should be NON-EXECUTABLE.

;=============================================================================================
section .text

global OUTB
global INB
global OUTW
global INW
global OUTL
global INL

;=============================================================================================

OUTB:
    mov edx, [esp + 4]  ; Get port from stack
    mov al,  [esp + 8]  ; Get data from stack
    out dx,  al         ; Write to the I/O port
    ret     

INB:
    mov edx, [esp + 4]  ; Get port from stack
    xor eax, eax        ; Zero eax to prevent returning garbage in upper bits
    in  al,  dx         ; Read from the I/O port into al
    ret

;=============================================================================================

OUTW:
    mov edx, [esp + 4]  ; Get port from stack
    mov ax,  [esp + 8]  ; Get data from stack
    out dx,  ax         ; Write to the I/O port
    ret     

INW:
    mov edx, [esp + 4]  ; Get port from stack
    xor eax, eax        ; Zero eax to prevent returning garbage in upper bits
    in  ax,  dx         ; Read from the I/O port into ax
    ret

;=============================================================================================

OUTL:
    mov edx,  [esp + 4] ; Get port from stack
    mov eax,  [esp + 8] ; Get data from stack
    out dx,   eax       ; Write to the I/O port
    ret     

INL:
    mov edx, [esp + 4]  ; Get port from stack
    in  eax,  dx        ; Read from the I/O port (already uses full eax)
    ret
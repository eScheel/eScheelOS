[bits 32]

section .note.GNU-stack
    ; This empty section's presence tells the linker
    ; that the stack should be NON-EXECUTABLE.
    
;=============================================================================================
section .text

global GDT_REINIT
global CODE_SEG
global DATA_SEG

GDT_REINIT:
    lgdt[GDT_DESC]
    mov ax, DATA_SEG               ; Load our data segment selector.
    mov ds, ax
    mov es, ax
    mov gs, ax
    mov fs, ax
    mov ss, ax                     ; I'm really not sure if this is a good idea or how I should properly set ss.
    jmp CODE_SEG:.FLUSH            ; Far jump to flush the GDT.     
.FLUSH:
    ret                            ; Return to Kinit.

;=============================================================================================
section .data

GDT_ENTRY:
    GDT_NULL:
        dw 0x0000       ; Limit (bits 0-15)
        dw 0x0000       ; Base  (bits 0-15)
        db 0x00         ; Base  (bits 15-23)
        db 0x00         ; Type flags
        db 0x00         ; Limit flags
        db 0x00         ; Base (bits 23-31)
    GDT_CODE:
        dw 0xffff       ; Limit (bits 0-15)
        dw 0x0000       ; Base (bits 0-15)
        db 0x00         ; Base (bits 15-23)
        db 0x9a         ; Type flags
        db 0xcf         ; Limit flags
        db 0x00         ; Base (bits 23-31)
    GDT_DATA:
        dw 0xffff       ; Limit (bits 0-15)
        dw 0x0000       ; Base (bits 0-15)
        db 0x00         ; Base (bits 15-23)
        db 0x92         ; Type flags
        db 0xcf         ; Limit flags
        db 0x00         ; Base (bits 23-31)
GDT_END:

CODE_SEG: equ GDT_CODE-GDT_ENTRY
DATA_SEG: equ GDT_DATA-GDT_ENTRY

GDT_DESC:
    dw GDT_END-GDT_ENTRY-1  ; Size of GDT is always (size-1)
    dd GDT_ENTRY            ; Start address of the gdt.
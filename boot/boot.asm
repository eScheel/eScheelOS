;   eScheelOS
;
;   boot.asm
;
;   Author: Jacob Scheel
;
;   This code will do the following:
;       1) Clear the direction flag, force set CS to zero, and store boot drive number passed by BIOS.
;       2) Reset the drive and, Load and execute the stage2.bin code at address 1000h.
;
[org 0x7c00]
[bits 16]

jmp 0:ENTRY     ; Force set CS to zero.

stage2_addr equ 0x1000
stage2_size equ 4096
stage2_sect equ 2           ; Sector Offset.

boot_drive: db  0

msg_disk_reset_failed: db 'error: Failed resetting drive.'
msg_stage2_failed:     db 'error: Failed loading stage2.'

;=============================================================================================

ENTRY:
    cld                         ; Ensures that string manipulation instructions (like movsb, lodsb, etc.) increment their pointers
    cli                         ; Disable Interrupts.
    xor ax, ax                  ; Set ax to zero.
    mov ds, ax                  ; Initialize data segment register.
    mov es, ax                  ; Initialize extra data segment register.
    mov ss, ax                  ; Initialize stack segment register.
    mov ax, 0x7c00              ;
    mov sp, ax                  ; sp = 0x7c00 just below boot code.
    sti                         ; Enable Interrupts.
    mov [boot_drive], dl        ; BIOS Stores boot drive number in dl. Save it.
    xor cx, cx                  ; Initialze counter for retry logic with disk reset.
.LOOP:
    mov  ah, 0x00	            ; Disk reset function.
    mov  dl, [boot_drive]
    int  0x13
    jc  .FAILED
    jmp .STAGE2
.FAILED:
    inc  cx
    cmp  cx, 2                  ; Let's give it 3 retries.
    jle .LOOP
    jmp  DISK_RESET_FAILED
.STAGE2:
    xor bx, bx         
    mov es, bx                  ; Indirectly set ES to zero for ES:BX.
    mov bx, stage2_addr         ; Set BX to start of stage2 for ES:BX.
    mov al, stage2_size/512     ; Number of sectors to read.
    mov cl, stage2_sect         ; Sector index to read.
    mov ch, 0                   ; Cylinder index to read.
    mov dh, 0                   ; Head index to read.
    mov dl, [boot_drive]
    mov ah, 0x02                ; AH = 0x02 (BIOS function "Read").
    int 0x13
    jc  STAGE2_FAILED
    mov dl, [boot_drive]        ; Doing this again to be safe.
    jmp 0:stage2_addr           ; Leave to stage2.

;=============================================================================================

;   Prints a character to the screen.
;   Caller must put character in al register.
;
BIOS_PRINTC:
    push bx
    mov  ah, 0x0e       ; AH = 0x0e (BIOS function "VIDEO - TELETYPE OUTPUT")
    xor  bx, bx         ; BH = page number , BL = color.
    int  0x10
    pop  bx
    ret

;   Prints a string of characters to the screen.
;   Caller must put string in si register.
;
BIOS_PRINTS:
    pusha
.LOOP:
    lodsb                   ; Loads a byte from ds:si into al.
    or   al, al             ; Test for null character or if al is zero.
    jz   BIOS_PRINTS_DONE
    call BIOS_PRINTC        ; Print it out.
    jmp .LOOP               ; Do it again.
BIOS_PRINTS_DONE:
    popa
    ret

;=============================================================================================

DISK_RESET_FAILED:
    lea  si, [msg_disk_reset_failed]
    call BIOS_PRINTS
    jmp  ERROR

STAGE2_FAILED:
    lea  si, [msg_stage2_failed]
    call BIOS_PRINTS

ERROR:
    cli         ; Disable Interrupts.
.LOOP:
    hlt         ; Stop execution.
    jmp .LOOP   ; Incase a NMI fires.

;=============================================================================================

times 510-($-$$) db 0
dw 0xAA55
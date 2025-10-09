;   eScheelOS
;
;   boot.asm
;
;   Author: Jacob Scheel
;
;   Purpose: This file will do the following:
;       1) Force set CS to zero and store boot drive number passed by BIOS.
;       2) Check and enable A20 using two of three methods. ; TODO: Eventually verify that A20 is actually enabled.
;       3) Load and execute the stage2.bin code at address 7E00h.
;
[org 0x7c00]
[bits 16]

jmp 0:ENTRY     ; Force set CS to zero.

stage2_addr equ 0x7e00
stage2_size equ 4096
stage2_sect equ 2           ; Sector Offset.

boot_drive: db  0

msg_disk_reset_failed: db 'error: Failed resetting the boot drive.'
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
    mov ax, 0x2402              ; Get A20 gate status.
    int 0x15
    jc .A20_ENABLE_FALLBACK     ; If this fails, jump to the keyboard method!
    cmp al, 0x1                 ; Is it already enabled?
    je .A20_ENABLED             ; Yes, we're done.
    mov ax, 0x2401              ; Try to enable it.
    int 0x15
    jc .A20_ENABLE_FALLBACK     ; If this fails, jump to the keyboard method!
    mov ax, 0x2402              ; Verify it worked.
    int 0x15
    jc .A20_ENABLE_FALLBACK     ; If verification fails, try the other way
    cmp al, 0x1
    je .A20_ENABLED             ; Success!
.A20_ENABLE_FALLBACK:
    cli
    call KB_CONTROLLER_WAIT         ; Wait until controller is ready
    mov  al, 0xad                   ; Command to disable the keyboard
    out  0x64, al
    call KB_CONTROLLER_WAIT
    mov  al, 0xd0                   ; Command to read the output port.
    out  0x64, al
    call KB_WAIT
    in   al, 0x60                   ; Read the output port value
    push ax                         ; Save it
    call KB_CONTROLLER_WAIT
    mov  al, 0xd1                   ; Command to write to the output port
    out  0x64, al
    call KB_CONTROLLER_WAIT
    pop  ax                         ; Get the original value back
    or   al, 2                      ; Set bit 1 (the A20 gate enable bit)
    out  0x60, al                   ; Write the new value back
    call KB_CONTROLLER_WAIT
    mov  al, 0xae                   ; Command to enable the keyboard
    out  0x64, al
    call KB_CONTROLLER_WAIT
    sti
.A20_ENABLED:
    xor cx, cx               ; Initialze counter for retry logic with disk reset.
.LOOP:
    mov  ah, 0x00	         ; Disk reset function.
    mov  dl, [boot_drive]
    int  0x13
    jc  .FAILED
    jmp .STAGE2
.FAILED:
    inc  cx
    cmp  cx, 2               ; Let's give it 3 retries.
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

; Helper function to wait until the keyboard controller has data ready to be read.
KB_WAIT:
    in   al, 0x64
    test al, 1                      ; Test bit 0 (output buffer status)
    jz   KB_WAIT
    ret

; Helper function to wait until the keyboard controller is ready for a command.
KB_CONTROLLER_WAIT:
    in   al, 0x64
    test al, 2                      ; Test bit 1 (input buffer status)
    jnz  KB_CONTROLLER_WAIT
    ret

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
    cli     ; Disable Interrupts.
    hlt     ; Stop execution.

;=============================================================================================

times 510-($-$$) db 0
dw 0xAA55
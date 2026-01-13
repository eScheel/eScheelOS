;   eScheelOS Bootloader
;
;   mbr.asm
;
;   Author: Jacob Scheel
;
;   This code will do the following:
;       1) Relocate itself to 0x1000 and parse the partition table for an active parition.
;       2) We should hopefully find boot.bin at the fat32 partition and load and execute it.
;
[org 0x1000]
[bits 16]

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

.RELOCATE:
    mov cx, 512                 ; We are 512 bytes.
    mov si, 0x7c00
    mov di, 0x1000
    rep movsb
    jmp 0:RELOCATED

;=============================================================================================
RELOCATED:
    sti
    mov [boot_drive], dl
    mov bx, PARTITION_TABLE_OFFSET
    mov cx, 4                       ; 4 partition tables.

.SCAN_LOOP:
    cmp byte [bx], 0x80             ; Check for Active Boot Flag
    je  LOAD_BOOT

    add bx, 16                      ; 16 bit wide partition tables.
    loop .SCAN_LOOP                 ; Do the next one until cx is zero.

    ; If we fall through, no bootable partition found
    jmp ERROR_SCAN

;=============================================================================================
LOAD_BOOT:
    mov  eax, [bx + 8]      ; Copy LBA from partition entry to DAP
    call DISK_READ
    mov  ax, 0xAA55         ; VBR should have boot magic as well.
    cmp  word[0x7dfe], ax   ; Check last 512 word of 0x7c00 where we loaded our VBR.
    jne  ERROR_VBR
    jmp  0:boot_addr

boot_addr equ   0x7c00

;=============================================================================================
; Disk Address Packet for int 0x13, ah=0x42
dap:
    db 0x10             ; Size of this packet (16 bytes)
    db 0                ; Reserved, always 0
.sectors:
    dw 1                ; Number of sectors to read.
.offset:
    dw boot_addr
.segment:
    dw 0
.lba_start:
    dq 0                ; 64-bit starting LBA

DISK_READ:
    mov dword [dap.lba_start], eax
    mov ah, 0x42                ; AH = The "Extended Read" function
    mov dl, [boot_drive]        ; DL = Drive number
    mov si, dap                 ; DS:SI -> Pointer to our DAP structure
    int 0x13                    ; Call the BIOS interrupt
    jc  ERROR_READ              ; Check for errors (carry flag is set on failure)
    ret

;=============================================================================================
msg_scan_failed: db "Failed to find an active partition.",0
msg_read_failed: db "Failed to read the drive.",0
msg_vbr_failed:  db "Magic missing from vbr.",0

ERROR_SCAN:
    lea  si, [msg_scan_failed]
    call BIOS_PRINTS
    jmp  ERROR

ERROR_READ:
    lea  si, [msg_read_failed]
    call BIOS_PRINTS
    jmp  ERROR

ERROR_VBR:
    lea  si, [msg_vbr_failed]
    call BIOS_PRINTS

ERROR:
    cli
.LOOP:
    hlt
    jmp .LOOP

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
boot_drive: db  0

;=============================================================================================
; Dummy MBR Partition Tables
; We must pad our code from its end ($) up to the partition table offset (446 decimal, or 0x1BE).
; This is only present because some real hardware fails to boot without it.
times 446-($-$$) db 0
PARTITION_TABLE_OFFSET:
; Partition 1
times 16 db 0
; Partition 2
times 16 db 0
; Partition 3
times 16 db 0
; Partition 4
times 16 db 0
; End of Partition Table
dw 0xAA55
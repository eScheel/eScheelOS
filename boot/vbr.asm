;   eScheelOS Bootloader
;
;   vbr.asm
;
;   Author: Jacob Scheel
;
;   This code will do the following:
;       1) Clear the direction flag and setup segments and a stack.
;       2) Store boot drive number passed by BIOS. Reset the drive and Load and execute the stage2.bin.
;
[org 0x7c00]
[bits 16]

jmp short ENTRY
nop
;
; Dummy FAT32 BIOS Parameter Block (BPB).
;
OEMName         times 8 db ' '
BytesPerSec     dw 0
SecPerClust     db 0
ReservedSecCnt  dw 0
NumFATs         db 0
RootEntryCnt    dw 0
TotalSec16      dw 0
Media           db 0
FATSz16         dw 0
SecPerTrk       dw 0
NumHeads        dw 0
HiddenSec       dd 0
TotalSec32      dd 0
;
; FAT32 Extended BPB
;
FATSz32         dd 0
ExtFlags        dw 0
FSVer           dw 0
RootClus        dd 0
FSInfo          dw 0
BkBootSec       dw 0
Reserved        times 12 db 0
DriveNum        db 0
Reserved1       db 0
BootSig         db 0
VolID           dd 0
VolLab          times 11 db ' '
FilSysType      times 8 db ' '

;=============================================================================================

ENTRY:
    cli                         ; Disable Interrupts.
    xor ax, ax                  ; Set ax to zero.
    mov ds, ax                  ; Initialize data segment register.
    mov es, ax                  ; Initialize extra data segment register.
    mov ss, ax                  ; Initialize stack segment register.
    mov ax, 0x7c00              ;
    mov sp, ax                  ; sp = 0x7c00 just below boot code.
    sti                         ; Enable Interrupts.
    mov [DriveNum], dl
    xor cx, cx                  ; Initialze counter for retry logic with disk reset.
.DISK_RESET:
    mov  ah, 0x00	            ; Disk reset function.
    mov  dl, [DriveNum]
    int  0x13
    jnc .STAGE2
.FAILED:
    inc  cx
    cmp  cx, 2                  ; Let's give it 3 retries.
    jle .DISK_RESET
    jmp  DISK_RESET_FAILED      ; Too many tries.
.STAGE2:
    call DISK_READ
    mov  dl, [DriveNum]
    jmp  0:stage2_addr           ; Leave to stage2.

stage2_addr equ 0x1000
stage2_size equ 4096
stage2_lba  equ 8           ; Sector Offset.

;=============================================================================================

; Disk Address Packet for int 0x13, ah=0x42
dap:
    db 0x10             ; Size of this packet (16 bytes)
    db 0                ; Reserved, always 0
.sectors:
    dw 0                ; Number of sectors to read. Will be filled in LOAD_KERNEL
.offset:
    dw stage2_addr
.segment:
    dw 0
.lba_start:
    dq stage2_lba       ; 64-bit starting LBA

DISK_READ:
    mov ax, stage2_size / 512
    mov [dap.sectors], ax
    mov ah, 0x42                ; AH = The "Extended Read" function
    mov dl, [DriveNum]          ; DL = Drive number
    mov si, dap                 ; DS:SI -> Pointer to our DAP structure
    int 0x13                    ; Call the BIOS interrupt
    jc STAGE2_FAILED            ; Check for errors (carry flag is set on failure)
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
msg_disk_reset_failed: db 'error: Failed resetting drive.',0
msg_stage2_failed:     db 'error: Failed loading stage2.',0

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
    hlt         ; Put the CPU to sleep.
    jmp .LOOP   ; Incase a NMI fires.

;=============================================================================================
times 510-($-$$) db 0
dw 0xAA55
;   eScheelOS Bootloader
;
;   boot.asm
;
;   Author: Jacob Scheel
;
;   This code will do the following:
;       1) Clear the direction flag and setup segments and a stack.
;       2) Store boot drive number passed by BIOS. Reset the drive and Load and execute the stage2.bin.
;
[org 0x7c00]
[bits 16]

stage2_addr equ 0x1000
stage2_size equ 4096
stage2_lba  equ 8           ; Sector Offset.

jmp short ENTRY
nop
;
;newfs_msdos -F 32 -S 512 -m 0xf8 -u 63 -o 0 -h 16 -c 64 -s 4949278 /home/jscheel/VirtualBox\ VMs/eScheel\ OS/eScheel\ OS.vhd
;
; TODO: Let the driver fill in some of these values to be more dynamic.
;
; FAT32 BIOS Parameter Block (BPB)
;
OEMName         db 'BSD4.4  '   ; 8 Bytes
BytesPerSec     dw 512
SecPerClust     db 64
ReservedSecCnt  dw 32
NumFATs         db 2
RootEntryCnt    dw 0            ; 0 for FAT32
TotalSec16      dw 0            ; 0 for FAT32
Media           db 0xF8
FATSz16         dw 0            ; 0 for FAT32
SecPerTrk       dw 63
NumHeads        dw 16
HiddenSec       dd 0
TotalSec32      dd 4949278
;
; FAT32 Extended BPB
;
FATSz32         dd 605
ExtFlags        dw 0
FSVer           dw 0
RootClus        dd 2
FSInfo          dw 1
BkBootSec       dw 6
Reserved        times 12 db 0
DriveNum        db 0x80
Reserved1       db 0
BootSig         db 0x29
VolID           dd 0x7A711AFA
VolLab          db 'ESCHEEL OS ' ; 11 Bytes
FilSysType      db 'FAT32   '    ; 8 Bytes

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

;=============================================================================================

; Disk Address Packet for int 0x13, ah=0x42
DAP:
    db 0x10             ; Size of this packet (16 bytes)
    db 0                ; Reserved, always 0
.SECTORS:
    dw 0                ; Number of sectors to read. Will be filled in LOAD_KERNEL
.BUFFER:
    dd stage2_addr      ; 32-bit flat address.
.LBA_START:
    dq stage2_lba       ; 64-bit starting LBA

DISK_READ:
    mov ax, stage2_size / 512
    mov [DAP.SECTORS], ax
    mov ah, 0x42                ; AH = The "Extended Read" function
    mov dl, [DriveNum]          ; DL = Drive number
    mov si, DAP                 ; DS:SI -> Pointer to our DAP structure
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
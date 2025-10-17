;   eScheelOS
;
;   stage2.asm
;
;   Author: Jacob Scheel
;
;   Purpose: This file will do the following:
;       1) Store the boot drive number passed by boot.bin
;       2) Initialize video mode and memory map from BIOS.
;       3) Load kernel code at address A000h and relocate to 100000h. (Not using EDD)
;       4) Bootstrap and then jump to kernel.elf
;
;   TODO: Write a file system driver to load a kernel from a data region as opposed to flat sectors.
;
[org 0x7e00]
[bits 16]

jmp short ENTRY

kernel_addr_tmp equ 0xA000      ; Temporary address since we are not using BIOS extended functions.
kernel_addr equ 0x100000        ; Address that elf_hdr + kernel_code/data will be loaded.
kernel_size equ 24576
kernel_lba  equ 9               ; LBA for kernel.elf on disk.
kernel_text_offset: dd 0        ; The address we will eventually need to jump to start the kernel.

video_mode: db 0    ; Default video mode passed to kernel via al register.
boot_drive: db 0    ; Boot drive passed to kernel via dl register.

msg_mmap_fail:   db 'error: Failed to get valid memory map form BIOS.',0
msg_kernel_fail: db 'error: Failed to load the kernel.',0

;=============================================================================================

ENTRY:
    cli
    xor  ax, ax      
    mov  ds, ax             ; Initialize data segment register.
    mov  es, ax             ; Initialize extra data segment register.
    mov  gs, ax
    mov  fs, ax
    mov  ss, ax             
    mov  ax, 0x7c00
    mov  sp, ax             ; sp = 0x7c00.
    sti
.INIT:
    mov [boot_drive], dl      ; Save the boot_drive number.
    mov  dl, 3                ; Select video mode. 3 = 80*25
    call BIOS_VIDEO_MODE      ; Set video mode.
    call BIOS_MEMORY_MAP      ; Retrieve memory map from BIOS.
    jc   MEMORY_MAP_FAILED    ; If carry is set, the function failed.
    call LOAD_KERNEL
    call PARSE_ELF_AND_RELOCATE
.BOOTSTRAP:
    cli
    lgdt[GDT_DESC]      ; Load the GDTR register with the base address of the GDT.
    mov eax, cr0        ; Set the PE flag in cr0.
    or  eax, 1          ; We only need to change the bottom bit.
    mov cr0, eax
    jmp CODE_SEG:BOOTSTRAP32

;=============================================================================================

;
;   Complements of nanobyte. Thanks!
;   https://github.com/nanobyte-dev/nanobyte_os/blob/master/src/bootloader/stage1/boot.asm
;
;   Converts LBA to CHS.
;   Store LBA Address in AX when calling. 
;   Returns CX bits 0-5 sector , CX bits 6-15 cylinder , DH = head.
;
; For now we will just assume a disk size of 2 heads and 63 Sectors per track.
; Eventually, I believe we are supposed to get these values from file system headers or something?
;
lba_to_chs_heads: db 2
lba_to_chs_spt:   db 63     ; Sectors per track.
;
LBA_TO_CHS:
    push ax
    push dx
    xor dx, dx			                 ; Set DX to zero before dividing
    div word[lba_to_chs_spt]             ; AX = LBA / SectorsPerTrack
  	; DX = LBA % SectorsPerTrack
    inc dx			                     ; DX = (LBA % SectorsPerTrack + 1) = Sector			
    mov cx, dx			                 ; Move our sector into CX
    xor dx, dx
    div word[lba_to_chs_heads]		     ; AX = (LBA / SectorsPerTrack) / Heads = cylinder
  	; DX = (LBA / SectorsPerTrack) % Heads = head
    mov dh, dl			                 ; Move our head into DH.
    mov ch, al			                 ; 
    shl ah, 6
    or  cl, ah
    pop ax
    mov dl, al
    pop ax
    ret

;=============================================================================================

LOAD_KERNEL:
    xor  bx, bx         
    mov  es, bx              ; Indirectly set ES for ES:BX.
    mov  ax, kernel_lba
    call LBA_TO_CHS          ; This will return proper setup in cx - dh.
    mov  bx, kernel_addr_tmp ; Set BX to start of kernel for ES:BX.
    mov  al, kernel_size/512 ; Number of sectors to read.
    mov  dl, [boot_drive]
    mov  ah, 0x02            ; BIOS Read Sectors function.
    int  0x13                ; Call BIOS disk interrupt.
    jc   KERNEL_LOAD_FAILED
    ret

;=============================================================================================

;
;   kernel.elf
;
;   Section Headers:
;         [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
;         [ 1] .text             PROGBITS        00100000 001000 00003f 00  AX  0   0 4096
;         [ 2] .data             PROGBITS        00101000 002000 00000e 00  WA  0   0 4096
;         [ 3] .bss              NOBITS          00102000 00200e 002000 00  WA  0   0 4096
;
;   Program Headers:
;       Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
;       LOAD           0x001000 0x00100000 0x00100000 0x0003f 0x0003f R E 0x1000
;       LOAD           0x002000 0x00101000 0x00101000 0x0000e 0x03000 RW  0x1000
;
;   Eventually we should maybe change this to actually parse the header in the boot loader rather than using i686-elf-readelf.
;   But I'm not sure we need to do that since we know our kernel and this is our bootloader.
;
PARSE_ELF_AND_RELOCATE:
    xor si, si              ; Set up destination segment:offset.
    mov gs, si
    mov si, kernel_addr_tmp ; A000h is where the LOAD_KERNEL routine loaded the kernel.
    add si, 0x1000          ; We know that our section .text starts at. + 0x1000

    mov di, 0xf800          ; Set up destination segment:offset.
    mov fs, di
    mov di, 0x8000          ; We are putting our kernel at 0x100000

    xor cx, cx
.LOOP1:
    mov al, byte [gs:si]
    mov byte [fs:di], al    ; Move whats at section .text into 0x100000
    inc di
    inc si                  ; Change this to use the rep instruction.
    inc cx
    cmp cx, 0x1000          ; Let's just load 4k here even though it might be less.
    jl .LOOP1

    mov si, 0xC000          ; This should be where our section .data starts. That BIOS loaded into memory.
    mov di, 0x9000          ; This should be where we load it into memory. 0x101000

    xor cx, cx
.LOOP2:
    mov al, byte [gs:si]
    mov byte [fs:di], al    ; Move whats at section .text into 0x100000
    inc di
    inc si                  ; Change this to use the rep instruction.
    inc cx
    cmp cx, 0x3000          ; Let's just load 12k here for .data and .bss which follows right behind.
    jl .LOOP2       

    ret


;=============================================================================================

MEMORY_MAP_FAILED:
    lea  si, [msg_mmap_fail]
    call BIOS_PRINTS
    jmp  HALT

KERNEL_LOAD_FAILED:
    lea  si, [msg_kernel_fail]
    call BIOS_PRINTS

HALT:
    cli         ; Disable Interrupts.
    jmp  $      ; hlt , but safe for NMI as well.

;=============================================================================================

;   Prints a character to the screen.
;   Caller must put character in al register.
;
BIOS_PRINTC:
    pusha
    mov  ah, 0x0e       ; AH = 0x0e (BIOS function "VIDEO - TELETYPE OUTPUT")
    xor  bx, bx         ; BH = page number , BL = color.
    int  0x10
    popa
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

;
;
;
BIOS_PRINTNL:
    push ax
    mov  al, 0xa
    call BIOS_PRINTC
    mov  al, 0xd
    call BIOS_PRINTC
    pop  ax
    ret

;   Sets the video mode. Also can be used to clear the screen?
;   Caller must put desired mode in dl register.
;
BIOS_VIDEO_MODE:
    pusha
    mov  ah, 0x0f                ; AH = 0x0F (BIOS function “Get Video Mode”)
    int  0x10  
    mov [video_mode], al
    cmp  al, dl                  ; Compare current video mode with desired video mode.
    je  .SKIPSETVID              ; If same, let's skip.
    mov  ah, 0x00                ; AH = 0x00 (BIOS function “Set Video Mode”), AL = 0xXX (mode number)
    mov  al, dl
    int  0x10                    ; Call BIOS video interrupt.
    ; TODO: Account for error maybe.
.SKIPSETVID:
    popa
    ret

;   Retrieves the system memory map using INT 0x15, EAX=0xE820.
;   On success: Stores map in mmap_buffer, clears carry flag.
;   On failure: Sets carry flag.
;   Clobbers: EAX, EBX, ECX, EDX, DI, BP
;
BIOS_MEMORY_MAP:
    xor ebx, ebx         ; EBX must be 0 for the first call.
    xor bp, bp           ; BP will count the number of valid entries
    mov di, MMAP_DESC    ; Point DI to the start of the entries array. ES is 0.
    add di, 4           ; I guess if we don't do this then int 15 gets stuck? Need to pass count anyway.
.LOOP:
    mov eax, 0xE820                         ; E820 function number.
    mov edx, 0x534D4150                     ; Magic number 'SMAP'
    mov ecx, SMAP_entry_size                ; Request 24 bytes for ACPI 3.0 compatibility.
    mov dword [es:di + SMAP_entry.acpi], 1  ; ACPI 3.0: ask for extended attributes.
    int 0x15                                ; Call BIOS interrupt.
    jc .ERROR                               ; If carry is set, there's an error.
    ; BIOS may trash EDX, so we restore it for the signature check.
    mov  edx, 0x534D4150
    cmp  eax, edx           ; On success, EAX should return 'SMAP'
    jne .ERROR
    ; If EBX is 0 after the first successful call, it means the list might be empty or just one entry.
    ; The loop condition `test ebx, ebx` will handle this.
    ; Now Validate the returned entry and skip entries with a length of 0.
    mov ecx, [es:di + SMAP_entry.length]
    or  ecx, [es:di + SMAP_entry.length + 4] ; Check if the 64-bit length is zero
    jz .SKIPENT
    ; Check ACPI 3.0 "ignore this entry" bit if we got a 24-byte response.
    cmp  cl, 20
    jbe .NOTACPI3
    test byte [es:di + SMAP_entry.acpi], 1
    je  .SKIPENT
.NOTACPI3:
    inc bp                  ; Increment valid entry count
    add di, SMAP_entry_size ; Move to the next storage spot
.SKIPENT:
    test ebx, ebx           ; If EBX is 0, we are at the end of the list.
    jnz .LOOP               ; If not zero, continue to get the next entry.
    mov [MMAP_DESC], bp     ; Store the final count of valid entries.
    clc                     ; Clear carry flag to indicate success.
    ret
.ERROR:
    stc                     ; Set carry flag to indicate failure
    ret

;=============================================================================================

; A structure for a single E820 memory map entry (24 bytes).
struc SMAP_entry
    .base_addr: resq 1  ; Base Address (64-bit)
    .length:    resq 1  ; Length (64-bit)
    .type:      resd 1  ; Type of memory region (32-bit)
    .acpi:      resd 1  ; ACPI 3.0 Extended Attributes
endstruc
; We'll allocate space for up to 16 entries for now.
SMAP_entry_max equ 16

; A structure to hold the entire memory map, which will be passed to the kernel.
MMAP_DESC:
    dd 0                                               ; Number of valid entries we found
    times (SMAP_entry_max * SMAP_entry_size)  db 0     ; Array of entries

;=============================================================================================

GDT_ENTRY:
    GDT_NULL:
        dw 0x0000   ; Limit (bits 0-15)
        dw 0x0000   ; Base  (bits 0-15)
        db 0x00     ; Base  (bits 15-23)
        db 0x00     ; Type flags
        db 0x00     ; Limit flags
        db 0x00     ; Base (bits 23-31)
    GDT_CODE:
        dw 0xffff   ; Limit (bits 0-15)
        dw 0x0000   ; Base (bits 0-15)
        db 0x00     ; Base (bits 15-23)
        db 0x9a     ; Type flags
        db 0xcf     ; Limit flags
        db 0x00     ; Base (bits 23-31)
    GDT_DATA:
        dw 0xffff   ; Limit (bits 0-15)
        dw 0x0000   ; Base (bits 0-15)
        db 0x00     ; Base (bits 15-23)
        db 0x92     ; Type flags
        db 0xcf     ; Limit flags
        db 0x00     ; Base (bits 23-31)
GDT_END:

CODE_SEG: equ GDT_CODE-GDT_ENTRY
DATA_SEG: equ GDT_DATA-GDT_ENTRY

GDT_DESC:
    dw GDT_END-GDT_ENTRY-1  ; Size of GDT is always (size-1)
    dd GDT_ENTRY            ; Start address of the gdt.

;=============================================================================================

[bits 32]

BOOTSTRAP32:
    mov ax, DATA_SEG        ; Load our data segment selector.
    mov ds, ax
    mov es, ax
    mov gs, ax
    mov fs, ax
    mov ss, ax

    ; Pass boot drive and default video mode to kernel.
    mov dl, [boot_drive]      ; Pass boot drive to kernel.
    mov al, [video_mode]      ; Pass default video mode to kernel.
    mov bx,  MMAP_DESC        ; Pass memory map buffer address to kernel.
    
    ; ...
    jmp CODE_SEG:kernel_addr   ; CS:100000h

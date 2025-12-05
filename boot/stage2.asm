;   eScheelOS Bootloader
;
;   stage2.asm
;
;   Author: Jacob Scheel
;
;   This code will do the following:
;       1) Setup segments and a stack, store the boot drive number passed by boot.bin
;       2) Check and enable A20 using two of three methods. Initialize video mode and memory map with BIOS.
;       3) Load kernel code from the fat32 root directory to 40000h and bootstrap to 32bits.
;       4) Parse and relocate elf executable to 100000h and pass boot_drive before jumping to kernel.elf
;
[org 0x1000]
[bits 16]

jmp short ENTRY

video_mode: db 0    ; Default video mode passed to kernel via al register.
boot_drive: db 0    ; Boot drive passed to kernel via dl register.

;=============================================================================================

ENTRY:
    cli
    xor  ax, ax      
    mov  ds, ax             ; Initialize data segment register.
    mov  es, ax             ; Initialize extra data segment register.
    mov  gs, ax
    mov  fs, ax
    mov  ss, ax             
    mov  ax, 0x3000         ; Place stack 4096 bytes above stage2 address.
    mov  sp, ax             ; sp = 0x3000
    sti
.INIT:
    mov [boot_drive], dl      ; Save the boot_drive number.
    call BIOS_ENABLE_A20      ; 
    mov  dl, 3                ; Select video mode. 3 = 80*25
    call BIOS_VIDEO_MODE      ; Set video mode.
    call BIOS_MEMORY_MAP      ; Retrieve memory map from BIOS.
    jc   MEMORY_MAP_FAILED    ; If carry is set, the function failed.
    call FAT32_INIT
    mov  eax, [root_cluster]  ; Find the Kernel in the Root Directory
    call FAT32_FIND_FILE
    cmp  ax, 0              ; If AX=0, file not found
    je   KERNEL_LOAD_FAILED
    call FAT32_LOAD_FILE
.BOOTSTRAP:
    cli
    lgdt[GDT_DESC]      ; Load the GDTR register with the base address of the GDT.
    mov eax, cr0        ; Set the PE flag in cr0.
    or  eax, 1          ; We only need to change the bottom bit.
    mov cr0, eax
    mov ax, DATA_SEG    ; Load our data segment selector.
    mov ds, ax
    mov es, ax
    mov gs, ax
    mov fs, ax
    mov ss, ax
    jmp CODE_SEG:BITS32

;=============================================================================================

; FAT32 Driver Variables & Constants
kernel_addr_tmp equ 0x4000          ; Temporary segment in low memory to hold the kernel while we parse elf.
kernel_filename db "KERNEL  ELF"    ; 8.3 Filename format (11 bytes, space padded)
bpb_addr        equ 0x7c00          ; Boot sector is still at 0x7c00

; Variables we will calculate from the BPB
data_start_lba      dd 0
sectors_per_cluster dd 0            ; Storing as 32-bit for easier math
fat_start_lba       dd 0
root_cluster        dd 0

;=============================================================================================

FAT32_INIT:
    ; Load Sectors Per Cluster.
    xor  eax, eax
    mov  al, byte [bpb_addr + 0x0d]
    mov [sectors_per_cluster], eax

    ; Load Root Cluster.
    mov  eax, [bpb_addr + 0x2c]
    mov [root_cluster], eax

    ; Calculate FAT Start LBA = HiddenSec + ReservedSec
    mov   eax, [bpb_addr + 0x1c]      ; Hidden Sectors
    movzx ebx, word [bpb_addr + 0x0e] ; Reserved Sectors
    add   eax, ebx
    mov [fat_start_lba], eax

    ; Calculate Data Start LBA = FAT_Start + (NumFATs * FATSz32)
    movzx ebx, byte [bpb_addr + 0x10]   ; Num FATs
    mov   ecx, [bpb_addr + 0x24]        ; Sectors Per FAT (32-bit)
    imul  ebx, ecx                      ; EBX = Total FAT Sectors
    add   eax, ebx                      ; EAX = Data Start LBA
    mov [data_start_lba], eax

    ret

;=============================================================================================

;
; FAT32_FIND_FILE
; Input: EAX = Starting Cluster of Directory (usually Root)
; Output: AX:DX = Start Cluster of File (0 if not found), ECX = File Size
;
FAT32_FIND_FILE:
    push es     ; push es to the stack to preserve its value, as it will be used for memory addressing during the operation.
    
.READ_DIR_CLUSTER:
    call CLUSTER_TO_LBA     ; Convert EAX (Cluster) to LBA, the actual sector number on the disk.
    
    ; Read 1 cluster to buffer using 0x8000 as scratch space.
    mov bx, 0x8000
    mov es, bx
    xor bx, bx
    mov cx, [sectors_per_cluster]
    call DISK_READ

    ; Search the entire loaded cluster.
    mov di, 0       ; Sets DI to 0, pointing to the start of the loaded buffer.

    ; Calculate total entries in the cluster:
    ; Entries = Sectors_Per_Cluster * 16 (entries per sector)
    mov ax, [sectors_per_cluster] ; Load sector count (e.g. 64)
    shl ax, 4                     ; Multiply by 16 (Shift Left 4 times)
    mov cx, ax                    ; Set loop counter (e.g., 64 * 16 = 1024)

.SEARCH_LOOP:
    ; Push di and cx to the stack because the string comparison instruction will modify them.
    push di
    push cx
    mov  si, kernel_filename     ; DS:SI = Filename
    mov  cx, 11                  ; Length of "KERNEL  ELF"

    ; Compares bytes at ES:DI (directory entry name) and DS:SI (your target filename) one by one. 
    ; It repeats as long as they are equal (repe) and CX > 0.
    repe cmpsb                   ; Compare ES:DI with DS:SI
    pop  cx
    pop  di
    je .FOUND

    add   di, 32        ; Move to next directory entry.
    loop .SEARCH_LOOP   ; Decrements CX and jumps back to the start of the loop if CX is not zero.

    ; TODO: If not found in this cluster, we should follow the FAT chain.
    ; For "Learning" purposes, we assume Root Dir fits in 1 cluster.
    jmp .NOT_FOUND

.FOUND:
    mov dx,  [es:di + 0x14] ; Extract High Cluster
    mov ax,  [es:di + 0x1a] ; Extract Low Cluster
    ;mov ecx, [es:di + 0x1c] ; Extract File Size
    pop es
    ret

.NOT_FOUND:
    pop es
    xor ax, ax  ; Clear ax to indicate failure.
    ret

;=============================================================================================

;
; FAT32_LOAD_FILE
; Input: AX:DX = Start Cluster
;        kernel_buffer (0x4000) = Destination
;
FAT32_LOAD_FILE:
    ; Reconstruct Cluster ID into EAX
    push dx     ; puts the high 16 bits on the stack.
    push ax     ; puts the low 16 bits "below" it in memory.
    pop eax     ; reads 32 bits from the stack at once.
    ; EAX now holds the 32-bit Cluster ID. 
    
    ; Setup Destination Segment 0x40000
    mov bx, kernel_addr_tmp ; 0x4000
    mov es, bx
    xor bx, bx

.LOAD_LOOP:
    push eax    ; Save current cluster

    ; Uses the cluster number in EAX to calculate the actual sector number on the disk (LBA) where this data lives.
    call CLUSTER_TO_LBA
    mov  cx, [sectors_per_cluster]  ; Tells the disk reader how many sectors to read at once
    call DISK_READ

    ; Advance Buffer Pointer
    ; BX += (SecPerClust * 512). Watch for segment overflow!
    ; Since we are in Real Mode, we must manipulate ES manually if we cross 64KB.
    ; (Ideally, add logic: if BX overflows, add 0x1000 to ES)
    mov ax, [sectors_per_cluster]
    mov cx, 512     ; Load the multiplier, bytes_per_sector.
    mul cx          ; Multiplies Sectors (64) * 512 to get the total bytes loaded (32,768)
    add bx, ax      ; Adds that number to BX.
    
    ; Get Next Cluster from FAT
    pop  eax                ; Restore current cluster
    call GET_NEXT_CLUSTER   ; Returns next cluster in EAX.
    cmp  eax, 0x0FFFFFF8    ; Check for End of Chain.
    jae .DONE               ; Jump if Above or Equal.
    jmp .LOAD_LOOP

.DONE:
    ret

;=============================================================================================

;
; CLUSTER_TO_LBA
; Input: EAX = Cluster Number
; Output: EAX = LBA
; Formula: Data_Start + ((Cluster - 2) * Sectors_Per_Cluster)
;
CLUSTER_TO_LBA:
    sub eax, 2                          ; FAT32 cluster numbers start at 2. Subtract from cluster number.
    mov ecx, [sectors_per_cluster]      ; We need to know how big each cluster is to know how far to jump.
    mul ecx                             ; Calculate the offset in sectors from the beginning of the data area.
    add eax, [data_start_lba]           ; We need to add the absolute starting position of the data area.
    ret

;=============================================================================================

;
; GET_NEXT_CLUSTER
; Input: EAX = Current Cluster
; Output: EAX = Next Cluster
;
GET_NEXT_CLUSTER:
    push es
    push bx
    push dx

    ; The File Allocation Table is just a giant array of 32-bit integers.
    shl eax, 2  ; FAT Offset = Cluster * 4

    ; Sector Offset = FAT Offset / 512
    xor edx, edx
    mov ebx, 512
    div ebx               ; EAX = Sector Offset, EDX = Byte Offset within sector

    ; FAT Sector LBA = FAT_Start_LBA + Sector Offset
    add eax, [fat_start_lba]

    ; Reads that single 512-byte chunk of the FAT table into memory at segment 0x8000.
    push dx               ; Save Byte Offset
    mov  bx, 0x8000
    mov  es, bx
    xor  bx, bx
    mov  cx, 1             ; Read 1 sector.
    call DISK_READ
    pop  di                ; Restore Byte Offset(DX) into DI

    ; Read the next cluster value
    mov eax, [es:di]      ; Read 32-bits from the FAT entry. ES points to 0x8000. DI holds the remainder offset.
    and eax, 0x0FFFFFFF   ; Mask out high 4 bits (FAT32 specific)

    pop dx
    pop bx
    pop es
    ret

;=============================================================================================

; Disk Address Packet (DAP)
dap:
    db 0x10
    db 0
dap_count: dw 0
dap_off:   dw 0
dap_seg:   dw 0
dap_lba:   dq 0

DISK_READ:
    pushad
    mov [dap_lba],   eax
    mov [dap_count], cx
    mov [dap_seg],   es
    mov [dap_off],   bx
    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, dap
    int 0x13
    jc KERNEL_LOAD_FAILED
    popad
    ret

;=============================================================================================

msg_mmap_fail:   db 'error: Failed to get valid memory map form BIOS.',0
msg_kernel_fail: db 'error: Failed to load the kernel.',0

MEMORY_MAP_FAILED:
    lea  si, [msg_mmap_fail]
    call BIOS_PRINTS
    jmp  HALT

KERNEL_LOAD_FAILED:
    lea  si, [msg_kernel_fail]
    call BIOS_PRINTS

HALT:
    cli
.LOOP:    
    hlt
    jmp  .LOOP      ; Just incase a nmi hits.

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
BIOS_ENABLE_A20:
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
    or   al, 0x02                   ; Set bit 1 (the A20 gate enable bit)
    out  0x60, al                   ; Write the new value back
    call KB_CONTROLLER_WAIT
    mov  al, 0xae                   ; Command to enable the keyboard
    out  0x64, al
    call KB_CONTROLLER_WAIT
    sti
.A20_ENABLED:
    ret

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
    mov di, mmap_desc    ; Point DI to the start of the entries array. ES is 0.
    add di, 4            ; I guess if we don't do this then int 15 gets stuck? Need to pass count anyway.
.LOOP:
    mov eax, 0xE820                         ; E820 function number.
    mov edx, 0x534D4150                     ; Magic number 'SMAP'
    mov ecx, SMAP_ENTRY_size                ; Request 24 bytes for ACPI 3.0 compatibility.
    mov dword [es:di + SMAP_ENTRY.acpi], 1  ; ACPI 3.0: ask for extended attributes.
    int 0x15                                ; Call BIOS interrupt.
    jc .ERROR                               ; If carry is set, there's an error.
    ; BIOS may trash EDX, so we restore it for the signature check.
    mov  edx, 0x534D4150
    cmp  eax, edx           ; On success, EAX should return 'SMAP'
    jne .ERROR
    ; If EBX is 0 after the first successful call, it means the list might be empty or just one entry.
    ; The loop condition `test ebx, ebx` will handle this.
    ; Now Validate the returned entry and skip entries with a length of 0.
    mov ecx, [es:di + SMAP_ENTRY.length]
    or  ecx, [es:di + SMAP_ENTRY.length + 4] ; Check if the 64-bit length is zero
    jz .SKIPENT
    ; Check ACPI 3.0 "ignore this entry" bit if we got a 24-byte response.
    cmp  cl, 20
    jbe .NOTACPI3   
    test byte [es:di + SMAP_ENTRY.acpi], 1
    je  .SKIPENT
.NOTACPI3:
    inc bp                  ; Increment valid entry count
    add di, SMAP_ENTRY_size ; Move to the next storage spot
.SKIPENT:
    test ebx, ebx           ; If EBX is 0, we are at the end of the list.
    jnz .LOOP               ; If not zero, continue to get the next entry.
    mov [mmap_desc], bp     ; Store the final count of valid entries.
    clc                     ; Clear carry flag to indicate success.
    ret
.ERROR:
    stc                     ; Set carry flag to indicate failure
    ret

;=============================================================================================

; A structure for a single E820 memory map entry (24 bytes).
struc SMAP_ENTRY
    .base_addr: resq 1  ; Base Address (64-bit)
    .length:    resq 1  ; Length (64-bit)
    .type:      resd 1  ; Type of memory region (32-bit)
    .acpi:      resd 1  ; ACPI 3.0 Extended Attributes
endstruc
; We'll allocate space for up to 32 entries for now.
SMAP_ENTRY_max equ 32

; A structure to hold the entire memory map, which will be passed to the kernel.
mmap_desc:
    dd 0                                               ; Number of valid entries we found
    times (SMAP_ENTRY_max * SMAP_ENTRY_size)  db 0     ; Array of entries

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

BITS32:
    mov  ebp, 0x4000    ; Setup temporary stack for 32bit stub.
    call PARSE_ELF_AND_RELOCATE

    ; Pass boot drive and default video mode to kernel.
    xor edx, edx
    xor ecx, ecx
    xor ebx, ebx
    mov dl, [boot_drive]      ; Pass boot drive to kernel.
    mov cl, [video_mode]      ; Pass default video mode to kernel.
    mov bx,  mmap_desc        ; Pass memory map buffer address to kernel.

    ; ...
    mov eax, [kernel_entry_point]
    jmp EAX

;=============================================================================================

kernel_entry_point:   dd 0          ; Entry point address defined in the elf header.
program_header_count: dw 0          ; ...
file_size: dd 0
mem_size:  dd 0
bss_size:  dd 0
physical_address: dd 0
section_offset:   dd 0
;
PARSE_ELF_AND_RELOCATE:

    ; This will be used to parse the headers.
    xor esi, esi
    mov esi, 0x40000 ; 4000h is where the LOAD_KERNEL routine loaded the kernel.

    ; Check the magic to see if valid elf file.
    mov al, byte [esi]
    cmp al, 0x7f
    jne ELF_PARSE_FAILED
    mov al, byte [esi + 1]
    cmp al, 'E'
    jne ELF_PARSE_FAILED 
    mov al, byte [esi + 2]
    cmp al, 'L'
    jne ELF_PARSE_FAILED
    mov al, byte [esi + 3]
    cmp al, 'F'
    jne ELF_PARSE_FAILED

    ; Get the kernel offset address address from the header.
    mov  eax, [esi + ELF32_HDR.e_entry]
    mov [kernel_entry_point], eax

    ; Get the program header count.
    mov dx, [esi + ELF32_HDR.e_phnum]
    mov [program_header_count], dx

    ; Let's skip past the header now and start reading program headers.
    add esi, ELF32_HDR_size

    ; Loop through each program header.
    xor ecx, ecx
PHDR_LOOP:
    ; Check if PT_LOAD == 1
    mov eax, [esi + ELF32_PHDR.p_type]
    cmp eax, 1
    jne ELF_SKIP_PH

    ; Get the memory size and file size from the program header.
    mov eax, [esi + ELF32_PHDR.p_memsz]
    mov [mem_size], eax
    mov eax, [esi + ELF32_PHDR.p_filesz]
    mov [file_size], eax

    ; Get the physical address of where we need to load this section.
    mov eax, [esi + ELF32_PHDR.p_paddr]
    mov [physical_address], eax

    ; ...
    mov eax, [esi + ELF32_PHDR.p_offset]
    mov [section_offset], eax

    ; Set source(ebx) to where BIOS loaded the kernel into lower memory.
    ; Then add the offset to ebx to get the start of the section.
    mov ebx, 0x40000
    add ebx, [section_offset]

    ; Set destination(edi) to the physical address where we need to move the kernel.
    mov edi, [physical_address]

    ; Write the bytes to the destination address.
    push ecx                 ; Save ecx since being used for program_header_count.
    xor  ecx, ecx
.WRITE_LOOP:
    mov al, byte [ebx]
    mov byte [edi], al    
    inc edi
    inc ebx                  ; TODO: Change this to use the rep instruction.
    inc ecx
    cmp ecx, [file_size]
    jl .WRITE_LOOP
    pop ecx

    ; Take away what the previous loop incremented for easier calculation.
    sub ebx, [file_size]
    sub edi, [file_size]

    ; If filesz == memsz , we probably are not padded with zeros.
    mov eax, [mem_size]
    cmp eax, [file_size]
    je  ELF_SKIP_PH

    ; Let's get the difference and store it.
    sub  eax, [file_size]
    mov  [bss_size], eax

    ; Let's skip past the actual data size to zero .bss
    add edi, [file_size]

    ; Zero BSS ...
    push ecx
    xor  ecx, ecx
.BSS_LOOP:
    mov byte [edi], 0
    inc edi
    inc ecx
    cmp ecx, [bss_size]
    jl .BSS_LOOP
    pop ecx

ELF_SKIP_PH:

    ; Skip to the next phdr.
    add esi, ELF32_PHDR_size

    ; Check if we are out of program headers.
    inc ecx
    cmp cx, [program_header_count]
    jl  PHDR_LOOP  

    ; Looks like we are done with everything.
    ret

;=============================================================================================

struc ELF32_HDR
	.e_ident:     resb 16     ;	/* File identification. */
	.e_type:      resw 1      ;		/* File type. */
	.e_machine:   resw 1      ;	/* Machine architecture. */
	.e_version:   resd 1      ;	/* ELF format version. */
	.e_entry:     resd 1      ;	/* Entry point. */
	.e_phoff:     resd 1      ;	/* Program header offset. */
	.e_shoff:     resd 1      ;	/* Section header file offset. */
	.e_flags:     resd 1      ;	/* Architecture-specific flags. */
	.e_ehsize:    resw 1      ;	/* Size of ELF header in bytes. */
	.e_phentsize: resw 1      ;	/* Size of program header entry. */
	.e_phnum:     resw 1      ;	/* Number of program header entries. */
	.e_shentsize: resw 1      ;	/* Size of section header entry. */
	.e_shnum:     resw 1      ;	/* Number of section header entries. */
	.e_shstrndx:  resw 1      ;	/* Section name strings section. */
endstruc

struc ELF32_PHDR
    .p_type:      resd 1    ; Specifies the type of segment (e.g., PT_LOAD for loadable segments, PT_DYNAMIC for dynamic linking information).
    .p_offset:    resd 1    ; The offset from the beginning of the ELF file to the start of the segment's data.
    .p_vaddr:     resd 1    ; The virtual address where the segment should be loaded in memory.
    .p_paddr:     resd 1    ; The physical address (relevant for some systems, often the same as p_vaddr for typical applications).
    .p_filesz:    resd 1    ; The size of the segment in the ELF file.
    .p_memsz:     resd 1    ; The size of the segment in memory. This can be larger than p_filesz if the segment contains uninitialized data (e.g., the .bss section), which is zero-filled in memory.
    .p_flags:     resd 1    ; Flags indicating permissions and other attributes of the segment (e.g., PF_R for readable, PF_W for writable, PF_X for executable).
    .p_align:     resd 1    ; The required alignment for the segment in memory.
endstruc

;============================================================================================

vga_off_addr  equ 0xb8000
vga_top_addr  equ 0xb8000 + (80 * 25)
vga_curr_addr: dd 0xb8000

grey_on_black   equ 0x07
vga_curr_color: db  grey_on_black

;   Print a character to the screen.
;   Caller must put character in al register.
;
VGA_PRINTC:
    push ebx
    push ecx
    mov  ebx, [vga_curr_addr]
    mov  ah,  [vga_curr_color]
    mov word [ebx], ax
    add  ebx, 2
    mov [vga_curr_addr], ebx
    pop  ecx
    pop  ebx
    ret

;   Prints a string to the screen.
;   Caller must put string address in esi.
;
VGA_PRINTS:
    push eax
.LOOP:
    mov  al, byte [esi]
    or   al, al
    jz  .DONE
    call VGA_PRINTC
    inc  esi
    jmp .LOOP
.DONE:
    pop eax
    ret

;=============================================================================================

msg_invalid_elf: db 'error: Failed to locate a valid elf file.',0

ELF_PARSE_FAILED:
    lea  esi, [msg_invalid_elf]
    call VGA_PRINTS 

HALT32:
    cli
.LOOP:    
    hlt
    jmp  .LOOP      ; Just incase a nmi hits.

times 4096-($-$$) db 0
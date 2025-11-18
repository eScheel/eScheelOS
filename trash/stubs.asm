;
;
;
;
    mov ah, 0x0f                ; AH = 0x0F (BIOS function “Get Video Mode”)
    int 0x10    
    mov [default_video_mode], al
    cmp al, 3                   ; We want to set to 3 for now.
    je .SKIPSETVID              ; If already 3, let's skip.
    mov ax, 0x0003              ; AH = 0x00 (BIOS function “Set Video Mode”), AL = 0xXX (mode number)
    int 0x10                    ; Call BIOS video interrupt.
    jc  VIDEO_MODE_FAILED       ; For now we will halt, eventually we will add fallback logic or something ...
.SKIPSETVID:









;   Prints a string of characters to the screen.
;   Caller must put string in si register.
;
BIOS_PRINTS:
    push ax
    push bx
.LOOP:
    lodsb                   ; Loads a byte from ds:si into al.
    or   al, al             ; Test for null character or if al is zero.
    jz   BIOS_PRINTS_DONE
    call BIOS_PRINTC        ; Print it out.
    jmp .LOOP               ; Do it again.
BIOS_PRINTS_DONE:
    pop bx
    pop ax
    ret

;   Prints a decimal value to the screen.
;   Caller must put data in AX register.
;
BIOS_PRINTD:
    pusha			    ; Save the stack.
    mov bx, 10		    ; Digits are extracted dividing by ten.
    xor cx, cx		    ; Start the counter off with zero.
.CONV_LOOP:
    mov  dx, 0		    ; Necessary to divide by BX.
    div  bx		        ; DX:AX / 10 = AX(quotient):DX(remainder)
    push dx		        ; Save DX for later use.
    inc  cx		        ; Increment the counter.
    cmp  ax, 0		    ; If number is not zero,
    jne .CONV_LOOP      ; then do it all again.
.DISP_LOOP:
    pop  dx		        ; Restore DX to get our number in reverse now.
    add  dl, 48		    ; Convert digit to character.
    mov  al, dl		    ; Now move our character in AL to be printed.
    call BIOS_PRINTC	; Print it out.
    dec  cx		        ; Decrement our counter.
    cmp  cx, 0		    ; If counter is zero then,
    je  .DONE	        ;  we are done.
    jmp .DISP_LOOP      ; Else, do it again.
.DONE:
    popa		 ; Restore the stack.
    ret			 ; Return.

;   Prints a hex value to the screen.
;   Caller must put data in DX register.
;
BIOS_PRINTH:
    pusha			        ; Save the stack.
    xor  cx, cx		        ; Start our counter off with zero.
    mov  si, bph_hexout     ; Move the addr of our template string into SI.
.NEXT_CHAR:
    mov  bx, dx		        ; Copy the next char into BX to be converted.
    shr  bx, 4		        ; Shift the current char right four times.
    add  bh, 0x30	        ; ASCII numbers start at a value of 0x30 || 48
    cmp  bh, 0x39	        ; ASCII numbers end at a value of   0x39 || 57
    jg  .ADD_SEVEN          ; ASCII (A-F):((57+1)+7):(0x41||65)-(0x46|| 70)
.ADD_CHAR:		
    mov byte [si], bh	    ; Move our current character to the addr of SI.
    inc  si		            ; Increment SI.
    inc  cx		            ; Increment our counter.
    shl  dx, 4		        ; Shift the next character left four times.
    or   dx, dx		        ; Logical OR DX with itself.
    jnz .NEXT_CHAR          ; If DX came back zero then do the next char.
    cmp  cx, 4	 	        ; If counter is four or higher, we are done. 
    jl  .NEXT_CHAR          ; Else, then do the next character.
    mov  si, bph_hexout      ; Move the addr of our formatted templated into SI. 
    call BIOS_PRINTS	    ; And print it out.
    popa		            ; Restore the stack.
    ret			            ; Return.
.ADD_SEVEN:
    add  bh, 0x07	        ; Add seven to BH so we are at (A-F)
    jmp .ADD_CHAR           ; Now add the next character.
bph_hexout: db '0000',0

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

;
;   Resets a disk.
;   Caller must put drive in dl register.
;
BIOS_DISK_RESET:
    pusha
    mov  ah, 0x00	; Disk reset function.
    int  0x13
    popa
    ret









;
; Caller must put value in EDX register.
;
TTY_PRINTH:
    pushad                  ; Use the 32-bit PUSHAD instruction.
    mov  esi, bph_hexout
    mov  ecx, 8             ; Use ECX for the 32-bit LOOP instruction.
.CONVERT_NIBBLE:
    mov  eax, edx
    shr  eax, 28            ; FIX: Shift by 28 for a 32-bit value.
    ; Convert nibble in AL to ASCII character.
    add  al, '0'
    cmp  al, '9'
    jle  .STORE_CHAR
    add  al, 7
.STORE_CHAR:
    mov  [esi], al
    inc  esi
    shl  edx, 4             ; FIX: Shift by 4 to get the next nibble.
    loop .CONVERT_NIBBLE
    ; Print the resulting string.
    mov  esi, bph_hexout
    call TTY_PRINTS
    popad                   ; Use the 32-bit POPAD instruction.
    ret
bph_hexout: db '00000000',0

;
;   Prints a decimal number to the screen.
;   Call must put data in eax register.
;
TTY_PRINTD:
    pushad			    ; Save the stack.
    mov ebx, 10		    ; Digits are extracted dividing by ten.
    xor cx, cx		    ; Start the counter off with zero.
.CONV_LOOP:
    mov  edx, 0		    ; Necessary to divide by BX.
    div  ebx		    ; DX:AX / 10 = AX(quotient):DX(remainder)
    push edx		    ; Save DX for later use.
    inc  cx		        ; Increment the counter.
    cmp  eax, 0		    ; If number is not zero,
    jne .CONV_LOOP      ; then do it all again.
.DISP_LOOP:
    pop  edx		    ; Restore DX to get our number in reverse now.
    add  dl, 48		    ; Convert digit to character.
    mov  al, dl		    ; Now move our character in AL to be printed.
    call TTY_PRINTC 	; Print it out.
    dec  cx		        ; Decrement our counter.
    cmp  cx, 0		    ; If counter is zero then,
    je  .DONE	        ;  we are done.
    jmp .DISP_LOOP      ; Else, do it again.
.DONE:
    popad		 ; Restore the stack.
    ret			 ; Return.








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

;
; CHS
;
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










;
;   kernel.elf
;
;   Program Headers:
;       Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
;       LOAD           0x001000 0x00100000 0x00100000 0x020f9 0x020f9 R E 0x1000
;       LOAD           0x004000 0x00103000 0x00103000 0x008fc 0x05878 RW  0x1000
;
;   Eventually we should maybe change this to actually parse the header in the boot loader rather than using i686-elf-readelf.
;   But I'm not sure we need to do that since we know our kernel and this is our bootloader. And this seems to work. So far ..
;
;   EDIT: I am finding out it is becoming very annoying to manually change the code when the kernel changes. I will need to parse elf hdr.
;
kernel_entry_point: dd 0                           ; Entry point address defined in the elf header.
text_rodata_size   equ 0x10f9
data_section_size  equ 0x8fc                       ; If the FileSiz above changes, change this to it.
bss_zero_size      equ 0x5678 - data_section_size  ; .data(MemSiz - FileSiz) = .bss
;
PARSE_ELF_AND_RELOCATE:
    xor si, si              ; Set up destination segment:offset.
    mov gs, si
    mov si, kernel_addr_tmp ; 4000h is where the LOAD_KERNEL routine loaded the kernel.

    call ENSURE_ELF         ; Let's make sure it is an ELF file.
    call GET_ELF_ENTRY      ; Let's parse the entry point address.
    add si, 0x1000          ; Skip past the elf header.

    mov di, 0xfA00          ; Set up destination segment:offset.
    mov fs, di
    mov di, 0x6000          ; We are putting our kernel at 0x100000 or FA00:6000

    ; Initialize first program header.
    xor cx, cx
.LOOP1:
    mov al, byte [gs:si]
    mov byte [fs:di], al    ; Move whats at section .text into 0x100000
    inc di
    inc si                  ; TODO: Change this to use the rep instruction.
    inc cx
    cmp cx, text_rodata_size
    jl .LOOP1

    mov si, 0x7000          ; This should be where our section .data starts after .text and .rodata
    mov di, 0x8000          ; This should be where we load it into memory. fA00h:8000h = 0x102000

    ; Initialize second program header.
    xor cx, cx
.LOOP2:
    mov al, byte [gs:si]
    mov byte [fs:di], al    ; Move whats at section .data into 0x102000
    inc di
    inc si                  ; TODO: Change this to use the rep instruction.
    inc cx
    cmp cx, data_section_size
    jl .LOOP2       

    mov di, 0x8000              ; Let's reset di to be 0x8000 where we loaded .data into upper mem.
    add di, data_section_size   ; Let's skip past the actual data size to zero .bss

    ; Zero BSS after .data section in second program header.
    xor cx, cx
.LOOP3:
    mov byte [fs:di], 0
    inc di
    inc cx
    cmp cx, bss_zero_size
    jl .LOOP3

    ret




    
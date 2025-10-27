
 






DISPLAY_MMAP:
    push eax
    push edx
    push ecx
    push esi

    xor  esi, esi

    xor  eax, eax
    mov  si, word [mmap_desc_addr]  ; Set ax to the address of the stage2 mmap_desc.
    mov  ax, [si]                   ; Move the entry count into ax register.
    call TTY_PRINTD
    call TTY_PRINTNL

    add  si, 4
    xor  edx, edx
    xor  ecx, ecx
    xor  edi, edi
.LOOP:
    add  si, 4              ; We want to display base high first.
    mov  edx, dword [si]    ; BASE HIGH
    call TTY_PRINTH
    sub  si, 4
    mov  edx, dword [si]    ; BASE LOW
    call TTY_PRINTH

    add  si, 8
    mov  al, '|'
    call TTY_PRINTC

    add  si, 4
    mov  edx, dword [si]    ; LENGTH HIGH
    call TTY_PRINTH
    sub  si, 4
    mov  edx, dword [si]    ; LENGTH LOW
    call TTY_PRINTH

    add  si, 8
    mov  al, '|'
    call TTY_PRINTC

    mov  edx, dword [si]    ; TYPE
    call TTY_PRINTH
    add  si, 4

    add  si, 4              ; ACPI

    call TTY_PRINTNL


    inc  cx
    mov  di, word [mmap_desc_addr]
    mov  bx, [di]
    cmp  cx, bx
    jl  .LOOP

    pop  esi
    pop  ecx
    pop  edx
    pop  eax
    ret


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










    mov al, byte [fs:di]
    call BIOS_PRINTC    
    inc di
    mov al, byte [fs:di]
    call BIOS_PRINTC 
    inc di
    mov al, byte [fs:di]
    call BIOS_PRINTC
    call BIOS_PRINTNL












RELOCATE_KERNEL:
    xor si, si              ; Set up source segment:offset.
    mov gs, si
    mov si, kernel_addr_tmp ; A000h
    mov di, 0xf800          ; Set up destination segment:offset.
    mov fs, di
    mov di, 0x8000          ; We are putting our kernel at 0x100000
    xor cx, cx
.LOOP:
    mov al, byte [gs:si]
    mov byte [fs:di], al    ; Move whats at 0xA000 into 0x100000
    inc di
    inc si                  ; Change this to use the rep instruction.
    inc cx
    cmp cx, kernel_size
    jl .LOOP
    ret


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








    xor  ebx, ebx               ; Zero out to be sure top bits are uninitialized.
    xor  eax, eax                   
    xor  edx, edx                   
    mov  bx, word [mmap_desc_addr]
    mov  al, byte [video_mode]
    mov  dl, byte [boot_drive]
    push edx                    ; Pass boot drive to kernel main.
    push eax                    ; Pass video mode to kernel main.
    push ebx                    ; Pass mmap desc addr to kernel main.
    call kernel_main











    call gdt_init               ; Initialize the Global Descriptor table.         
    lgdt[GDT_DESC]
    mov ax, 0x10                ; Load our data segment selector.
    mov ds, ax
    mov es, ax
    mov gs, ax
    mov fs, ax
    mov ss, ax
    jmp 0x08:FLUSH             
FLUSH:





















    push dword str_total_mem            ; Display total available memory in MB.
    call vga_prints                     ; TODO: Maybe eventually test to make sure that at least 2MB are available.
    xor  edx, edx
    mov  eax, dword [available_memory_size]
    mov  ecx, 1048576   ; Divide by 1024*1024 to get MB value.
    div  ecx                
    push dword eax
    call vga_printd
    push dword str_megabytes
    call vga_prints

    push dword [mmap_avail_entry_count]
    call vga_printd
    push byte 0xa
    call vga_printc


    xor ecx, ecx
    lea edi, [available_memory_map]
.LOOP:
    push ecx

    add  edi, 4
    push dword [es:edi]
    call vga_printh

    sub  edi, 4
    push dword [es:edi]
    call vga_printh

    push byte ':'
    call vga_printc

    add  edi, 12
    push dword [es:edi]
    call vga_printh

    sub  edi, 4
    push dword [es:edi]
    call vga_printh

    add edi, 8
    push byte 0xa
    call vga_printc

    add  esp, 24   ; CDECL: Clean up all 24 bytes from C calls at once.

    pop  ecx
    inc  ecx
    cmp  ecx, dword [mmap_avail_entry_count]
    jl  .LOOP
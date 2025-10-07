
 






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
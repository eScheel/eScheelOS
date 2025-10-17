tty_off_addr  equ 0xb8000
tty_top_addr  equ 0xb8000 + (80 * 25)
tty_curr_addr: dd 0xb8000

grey_on_black   equ 0x07
black_on_blue   equ 0x10
white_on_blue   equ 0x1F
tty_curr_color: db  white_on_blue

;   Print a character to the screen.
;   Caller must put character in al register.
;
TTY_PRINTC:
    push ebx
    push ecx
    mov  ebx, [tty_curr_addr]
    mov  ah, [tty_curr_color]
    mov word [ebx], ax
    add  ebx, 2
    mov [tty_curr_addr], ebx
    pop  ecx
    pop  ebx
    ret

;   Prints a string to the screen.
;   Caller must put string address in esi.
;
TTY_PRINTS:
    push eax
.LOOP:
    mov  al, byte [esi]
    or   al, al
    jz  .DONE
    call TTY_PRINTC
    inc  esi
    jmp .LOOP
.DONE:
    pop eax
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
;
;
TTY_PRINTNL:
    pushad                      ; Save all general purpose registers.  
    ; Step 1: Get the current cursor position's OFFSET from the start of video memory.
    mov  eax, [tty_curr_addr]   ; EAX = current absolute address (e.g., 0xB80A4)
    sub  eax, tty_off_addr      ; EAX = current offset (e.g., 0xA4)
    ; Step 2: Calculate how many bytes are in a single line.
    mov  ebx, 160               ; EBX = 80 columns * 2 bytes per character
    ; Step 3: Find the start of the CURRENT line.
    xor  edx, edx               ; Clear EDX for the division.
    div  ebx                    ; EAX = EAX / 160. EAX is now the row number, EDX is the remainder.
    mul  ebx                    ; EAX = row number * 160. EAX is now the offset of the current line's start.
    ; Step 4: Calculate the start of the NEXT line.
    add  eax, 160               ; EAX = offset of current line + 160 bytes
    ; Step 5: Convert the offset back to an absolute address and save it.
    add  eax, tty_off_addr      ; Add the video memory base address back.
    mov  [tty_curr_addr], eax   ; Store the new cursor position.
    popad                       ; Restore registers.
    ret

;
;   Clears the screen.
;   Gemini completely wrote this ...
;
TTY_CLEAR:
    pushad                      ; Save all general purpose registers.
    mov  ecx, 2000              ; Set ECX to the total number of character cells on the screen (80 columns * 25 rows).
    ; Set EDI to the starting address of video memory.
    mov  edi, tty_off_addr      ; EDI = 0xb8000 
    ; Set AX to the value we will write to each cell:
    mov  ah, [tty_curr_color]
    mov  al, ' '                ; AL = 0x20 (space character)
                                ; AX is now 0x0720
    ; This instruction repeats "store word" (STOSW) ECX times.
    ; It writes the value in AX to the memory location [EDI],
    ; then automatically increments EDI by 2.
    rep  stosw
    ; Reset the current cursor address back to the start of the screen.
    mov  dword [tty_curr_addr], tty_off_addr ; 
    popad                       ; Restore registers.
    ret
;
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

;
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

; 
;   Retrieves the system memory map using INT 0x15, EAX=0xE820.
;   On success: Stores map in mmap_buffer, clears carry flag.
;   On failure: Sets carry flag.
;   Clobbers: EAX, EBX, ECX, EDX, DI, BP
;
BIOS_MEMORY_MAP:
    xor ebx, ebx            ; EBX must be 0 for the first call [11, 13]
    xor bp, bp              ; BP will count the number of valid entries
    mov di, mmap_buffer + 4 ; Point DI to the start of the entries array. ES is 0.
.LOOP:
    mov eax, 0xE820                         ; E820 function number [11, 13]
    mov edx, 0x534D4150                     ; Magic number 'SMAP' [11, 13]
    mov ecx, SMAP_entry_size                ; Request 24 bytes for ACPI 3.0 compatibility [7, 11]
    mov dword [es:di + SMAP_entry.acpi], 1  ; ACPI 3.0: ask for extended attributes [7]
    int 0x15                                ; Call BIOS interrupt.
    jc .ERROR               ; If carry is set, there's an error or we're done [12, 14]
    ; BIOS may trash EDX, so we restore it for the signature check [7]
    mov  edx, 0x534D4150
    cmp  eax, edx           ; On success, EAX should return 'SMAP' [7, 11]
    jne .ERROR
    ; If EBX is 0 after the first successful call, it means the list might be empty or just one entry.
    ; The loop condition `test ebx, ebx` will handle this.
    ; Now Validate the returned entry and skip entries with a length of 0.
    mov ecx, [es:di + SMAP_entry.length]
    or  ecx, [es:di + SMAP_entry.length + 4] ; Check if the 64-bit length is zero
    jz .SKIPENT
    ; Check ACPI 3.0 "ignore this entry" bit if we got a 24-byte response [7, 8]
    cmp  cl, 20
    jbe .NOTACPI3
    test byte [es:di + SMAP_entry.acpi], 1
    je  .SKIPENT
.NOTACPI3:
    inc bp                  ; Increment valid entry count
    add di, SMAP_entry_size ; Move to the next storage spot
.SKIPENT:
    test ebx, ebx           ; If EBX is 0, we are at the end of the list [12, 14]
    jnz .LOOP               ; If not zero, continue to get the next entry
    mov [mmap_buffer], bp   ; Store the final count of valid entries
    clc                     ; Clear carry flag to indicate success
    ret
.ERROR:
    stc                     ; Set carry flag to indicate failure
    ret
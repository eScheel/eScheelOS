
 






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













.LOOP:
    dec  ecx                ; This value (255, 254, ... 0) will be our interrupt number.
    
    ; Prepare to call IDT_SET_GATE(interrupt_number, handler_address)
    ; The cdecl calling convention pushes arguments onto the stack from right to left.
    push ecx                ; Push the first argument (interrupt_number), which is our counter (ECX).
    push eax                ; Push the second argument (handler_address), which is in EAX.
    call IDT_SET_GATE
    
    ; --- Clean up the stack after the call ---
    ; We pushed EAX and ECX (8 bytes total), but IDT_SET_GATE
    ; doesn't clean up its own stack arguments (per cdecl).
    ; We can't just use `add esp, 8` here because we need the values
    ; back in their registers for the loop.
    pop  eax                ; Restore the handler address to EAX for the next loop iteration.
    pop  ecx                ; Restore the counter to ECX.
    test ecx, ecx           ; Check if ECX is zero.
    jnz .LOOP










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














kernel_entry_point:   dd 0          ; Entry point address defined in the elf header.
program_header_count: dw 0          ; ...
filesz: dw 0
memsz:  dw 0
bsssz:  dw 0
physical_address: dd 0
;
PARSE_ELF_AND_RELOCATE:

    ; This will be used to parse the headers.
    xor si, si
    mov gs, si
    mov si, kernel_addr_tmp ; 4000h is where the LOAD_KERNEL routine loaded the kernel.

    ; This will be used as the source address in lower mem.
    xor bx, bx
    mov es, bx
    mov bx, kernel_addr_tmp + 0x1000    ; Skip past headers as well.

    ; This will be used as the destination address in upper mem.
    mov di, 0xfA00          ; Set up destination segment:offset.
    mov fs, di
    mov di, 0x6000          ; We are putting our kernel at 0x100000 or FA00:6000   

    ; Check the magic to see if valid elf file.
    mov al, byte [gs:si]
    cmp al, 0x7f
    jne ELF_PARSE_FAILED
    mov al, byte [gs:si + 1]
    cmp al, 'E'
    jne ELF_PARSE_FAILED 
    mov al, byte [gs:si + 2]
    cmp al, 'L'
    jne ELF_PARSE_FAILED
    mov al, byte [gs:si + 3]
    cmp al, 'F'
    jne ELF_PARSE_FAILED

    ; Get the kernel offset address address from the header.
    mov  eax, [gs:si + ELF32_HDR.e_entry]
    mov [kernel_entry_point], eax
;    nop
;    mov  dx, [kernel_entry_point + 2]
;    call BIOS_PRINTH
;    mov  dx, [kernel_entry_point]
;    call BIOS_PRINTH
;    mov  al, ' '
;    call BIOS_PRINTC

    ; Get the program header count.
    mov dx, [gs:si + ELF32_HDR.e_phnum]
    mov [program_header_count], dx
;    nop
;    call BIOS_PRINTH
;    call BIOS_PRINTNL

    ; Let's skip past the header now and start reading program headers.
    add si, ELF32_HDR_size

    ; Loop through each program header.
    xor cx, cx
PE_LOOP:
    ; Check if PT_LOAD == 1
    mov eax, [gs:si + ELF32_PHDR.p_type]
    cmp eax, 1
    jne SKIP_PH
;    nop
;    mov  dx, [gs:si + ELF32_PHDR.p_type]
;    call BIOS_PRINTH
;    mov  al, ' '
;    call BIOS_PRINTC

    ; For now we will just get lower 16bits of the memsz and filesz to fill in.
    mov dx, word [gs:si + ELF32_PHDR.p_memsz]
    mov [memsz], dx
;    nop
;    call BIOS_PRINTH
;    mov  al, ' '
;    call BIOS_PRINTC
    ;
    mov dx, word [gs:si + ELF32_PHDR.p_filesz]
    mov [filesz], dx  
;    nop
;    call BIOS_PRINTH
;    mov  al, ' '
;    call BIOS_PRINTC

    ; ...
    mov eax, [gs:si + ELF32_PHDR.p_paddr]
    mov [physical_address], eax

    ; Write the bytes to the destination address.
    push cx     ; Save cx since being used for program_header_count.
    xor  cx, cx
.LOOP:
    mov al, byte [es:bx]
    mov byte [fs:di], al    
    inc di
    inc bx                  ; TODO: Change this to use the rep instruction.
    inc cx
    cmp cx, word [memsz]
    jl .LOOP
    pop cx

    ; Take away what the previous loop incremented for easier calculation.
    sub bx, word [memsz]
    sub di, word [memsz]
;    nop
;    mov  dx, bx
;    call BIOS_PRINTH
;    mov  al, ' '
;    call BIOS_PRINTC
;    mov  dx, di
;    call BIOS_PRINTH
;    mov  al, ' '
;    call BIOS_PRINTC     

    ; If filesz == memsz , we probably are not padded with zeros.
    mov ax, [memsz]
    cmp ax, [filesz]
    je  SKIP_BSS
    ; Let's get the difference and store it.
    sub  ax, [filesz]
    mov  [bsssz], ax
;    nop
;    mov  dx, [bsssz]
;    call BIOS_PRINTH
;    call BIOS_PRINTNL

    ; Zero BSS ...
    push di
    push cx
    xor  cx, cx
    add  di, [filesz]   ; Let's skip past the actual data size to zero .bss
.LOOP3:
    mov byte [fs:di], 0
    inc di
    inc cx
    cmp cx, [bsssz]
    jl .LOOP3
    pop cx
    pop di

SKIP_BSS:
;    nop
;    call BIOS_PRINTNL

    ; For now we will just skip 0x2000 ahead as it seems the linker adds sections together in 2's.
    ; Padded at 0x1000
    ; Maybe I can use the offset and add that to bx and dx and subtract 0x1000?
    add bx, 0x2000
    add di, 0x2000

    ; Skip to the next phdr.
    add si, ELF32_PHDR_size

    ; Check if we are out of phdrs.
    inc cx
    cmp cx, [program_header_count]
    jl  PE_LOOP

    ret

SKIP_PH:
    ; Skip to the next phdr.
    add si, ELF32_PHDR_size

    ; ...
    inc cx
    cmp cx, [program_header_count]
    jl  PE_LOOP  

    ret








    mov  ecx, 256               ; Set up a loop to initialize all 256 IDT entries with a common stub.
    mov  eax, ISR_STUB          ; EAX will hold the address of the default "catch-all" handler.
.LOOP:
    dec  ecx                ; Decrement our interrupt number.
    
    ; Prepare to call IDT_SET_GATE(interrupt_number, handler_address)
    ; The cdecl calling convention pushes arguments onto the stack from right to left.
    push ecx                ; Push the first argument (interrupt_number), which is our counter (ECX).
    push eax                ; Push the second argument (handler_address), which is in EAX.
    call IDT_SET_GATE
    
    ; Clean up the stack after the call.
    ; We pushed EAX and ECX (8 bytes total), but IDT_SET_GATE
    ; doesn't clean up its own stack arguments (per cdecl).
    ; We can't just use `add esp, 8` here because we need the values
    ; back in their registers for the loop.
    pop  eax                ; Restore the handler address to EAX for the next loop iteration.
    pop  ecx                ; Restore the counter to ECX.
    test ecx, ecx           ; Check if ECX is zero.
    jnz .LOOP

    ; Loop is finished, all 256 entries now point to isr_stub.





ISR_STUB:
    pusha                   ; Save all general-purpose registers (eax, ecx, etc.)

    push dword str_unhandled
    call vga_prints         ; Print "Unhandled Interrupt!"
    add  esp, 4             ; Clean up stack

    ; This is a stub, so we still need to send an EOI (End of Interrupt) just in case this was a hardware interrupt.
    ; For now we will just send the ACK to both PICs.
    mov al, 0x20
    out 0x20, al            ; EOI to PIC1
    out 0xA0, al            ; EOI to PIC2

    popa                    ; Restore all registers
    iret                    ; Return from interrupt














    mov  ecx, 0
    mov  eax, ISR_0
    push ecx
    push eax
    call IDT_SET_GATE
    mov  ecx, 1
    mov  eax, ISR_1
    push ecx
    push eax
    call IDT_SET_GATE
    mov  ecx, 2
    mov  eax, ISR_2
    push ecx
    push eax
    call IDT_SET_GATE
    mov  ecx, 3
    mov  eax, ISR_3
    push ecx
    push eax
    call IDT_SET_GATE
    mov  ecx, 4
    mov  eax, ISR_4
    push ecx
    push eax
    call IDT_SET_GATE
    mov  ecx, 5
    mov  eax, ISR_5
    push ecx
    push eax
    call IDT_SET_GATE
    mov  ecx, 6
    mov  eax, ISR_6
    push ecx
    push eax
    call IDT_SET_GATE
    mov  ecx, 7
    mov  eax, ISR_7
    push ecx
    push eax
    call IDT_SET_GATE
    mov  ecx, 8
    mov  eax, ISR_8
    push ecx
    push eax
    call IDT_SET_GATE
    mov  ecx, 9
    mov  eax, ISR_9
    push ecx
    push eax
    call IDT_SET_GATE
    mov  ecx, 10
    mov  eax, ISR_10
    push ecx
    push eax
    call IDT_SET_GATE
    mov  ecx, 11
    mov  eax, ISR_11
    push ecx
    push eax
    call IDT_SET_GATE
    mov  ecx, 12
    mov  eax, ISR_12
    push ecx
    push eax
    call IDT_SET_GATE
    mov  ecx, 0
    mov  eax, ISR_0
    push ecx
    push eax
    call IDT_SET_GATE
    mov  ecx, 0
    mov  eax, ISR_0
    push ecx
    push eax
    call IDT_SET_GATE
    mov  ecx, 0
    mov  eax, ISR_0
    push ecx
    push eax
    call IDT_SET_GATE
    mov  ecx, 0
    mov  eax, ISR_0
    push ecx
    push eax
    call IDT_SET_GATE





    
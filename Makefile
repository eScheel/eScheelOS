.PHONY: all boot kernel

all: boot clean-boot kernel clean-kernel

boot:
	nasm boot/boot.asm -f bin -o boot.bin
	nasm boot/stage2.asm -f bin -o stage2.bin
	
	dd if=boot.bin   of=/mnt/c/Users/jscheel/VirtualBox\ VMs/eScheelOS\ 32-bit/eScheelOS\ 32-bit.vhd bs=512 conv=notrunc
	dd if=stage2.bin of=/mnt/c/Users/jscheel/VirtualBox\ VMs/eScheelOS\ 32-bit/eScheelOS\ 32-bit.vhd bs=512 conv=notrunc seek=1

kernel:
	nasm kernel/kernel.asm   -f elf32 -o kinit.o
	nasm kernel/arch/gdt.asm -f elf32 -o gdt.o
	nasm kernel/arch/idt.asm -f elf32 -o idt.o
	nasm kernel/arch/isr.asm -f elf32 -o isr.o
	nasm kernel/arch/irq.asm -f elf32 -o irq.o
	nasm kernel/sys/io.asm   -f elf32 -o io.o

	i686-elf-gcc -c kernel/kernel.c           -o kmain.o    -I kernel/include/ -std=gnu99 -ffreestanding -Wall -Wextra
	i686-elf-gcc -c kernel/drivers/vga.c      -o vga.o      -I kernel/include/ -std=gnu99 -ffreestanding -Wall -Wextra
	i686-elf-gcc -c kernel/drivers/pit.c      -o pit.o      -I kernel/include/ -std=gnu99 -ffreestanding -Wall -Wextra
	i686-elf-gcc -c kernel/drivers/keyboard.c -o keyboard.o -I kernel/include/ -std=gnu99 -ffreestanding -Wall -Wextra
	i686-elf-gcc -c kernel/lib/string.c       -o string.o   -I kernel/include/ -std=gnu99 -ffreestanding -Wall -Wextra
	i686-elf-gcc -c kernel/sys/mmap.c         -o mem.o      -I kernel/include/ -std=gnu99 -ffreestanding -Wall -Wextra
	i686-elf-gcc -c kernel/sys/heap.c         -o heap.o     -I kernel/include/ -std=gnu99 -ffreestanding -Wall -Wextra

	i686-elf-ld *.o -T link.ld -o kernel.elf

	dd if=kernel.elf of=/mnt/c/Users/jscheel/VirtualBox\ VMs/eScheelOS\ 32-bit/eScheelOS\ 32-bit.vhd bs=512 conv=notrunc seek=9

clean-boot:
	rm -rv boot.bin stage2.bin 
	
clean-kernel:
	rm -rv *.o
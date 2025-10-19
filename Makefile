.PHONY: all boot kernel

all: boot clean-boot kernel clean-kernel

boot:
	nasm boot/boot.asm -f bin -o boot.bin
	nasm boot/stage2.asm -f bin -o stage2.bin
	dd if=boot.bin   of=/mnt/c/Users/jacob/VirtualBox\ VMs/eScheelOS\ 32-bit/eScheelOS\ 32-bit.vhd bs=512 conv=notrunc
	dd if=stage2.bin of=/mnt/c/Users/jacob/VirtualBox\ VMs/eScheelOS\ 32-bit/eScheelOS\ 32-bit.vhd bs=512 conv=notrunc seek=1

kernel:
	nasm kernel/src/kentry.asm -f elf32  -o kentry.o
	i686-elf-gcc -c kernel/src/kernel.c  -o kernel.o -ffreestanding -Wall -Wextra
	i686-elf-gcc -c kernel/drivers/vga.c -o vga.o    -ffreestanding -Wall -Wextra
	i686-elf-gcc -c kernel/lib/string.c  -o string.o -ffreestanding -Wall -Wextra
	i686-elf-gcc -c kernel/sys/mmap.c	 -o mem.o    -ffreestanding -Wall -Wextra
	i686-elf-ld *.o -T link.ld -o kernel.elf
	dd if=kernel.elf of=/mnt/c/Users/jacob/VirtualBox\ VMs/eScheelOS\ 32-bit/eScheelOS\ 32-bit.vhd bs=512 conv=notrunc seek=9

clean-boot:
	rm -rv boot.bin stage2.bin 
	
clean-kernel:
	rm -rv kernel.elf *.o
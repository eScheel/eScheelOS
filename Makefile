.PHONY: all boot kernel

all: boot clean-boot kernel clean-kernel

boot:
	nasm boot/boot.asm -f bin -o boot.bin
	nasm boot/stage2.asm -f bin -o stage2.bin
	dd if=boot.bin   of=/mnt/c/Users/jacob/VirtualBox\ VMs/eScheelOS\ 32-bit/eScheelOS\ 32-bit.vhd bs=512 conv=notrunc
	dd if=stage2.bin of=/mnt/c/Users/jacob/VirtualBox\ VMs/eScheelOS\ 32-bit/eScheelOS\ 32-bit.vhd bs=512 conv=notrunc seek=1

kernel:
	nasm kernel/kentry.asm -f bin -o kentry.bin
	dd if=kentry.bin of=/mnt/c/Users/jacob/VirtualBox\ VMs/eScheelOS\ 32-bit/eScheelOS\ 32-bit.vhd bs=512 conv=notrunc seek=9

clean-boot:
	rm -rv boot.bin stage2.bin 
	
clean-kernel:
	rm -rv kentry.bin
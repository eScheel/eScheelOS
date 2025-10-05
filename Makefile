build:
	nasm boot/boot.asm -f bin -o boot.bin
	nasm boot/stage2.asm -f bin -o stage2.bin
	nasm kernel/kentry.asm -f bin -o kernel.bin

qemu:
	dd if=/dev/zero  of=scheelnix.vhd bs=1M  count=100
	dd if=boot.bin   of=scheelnix.vhd bs=512 conv=notrunc
	dd if=stage2.bin of=scheelnix.vhd bs=512 conv=notrunc seek=1
	dd if=kernel.bin of=scheelnix.vhd bs=512 conv=notrunc seek=9

virtual:
	dd if=boot.bin   of=/mnt/c/Users/jacob/VirtualBox\ VMs/ScheelNix86/ScheelNix86.vhd bs=512 conv=notrunc
	dd if=stage2.bin of=/mnt/c/Users/jacob/VirtualBox\ VMs/ScheelNix86/ScheelNix86.vhd bs=512 conv=notrunc seek=1
	dd if=kernel.bin of=/mnt/c/Users/jacob/VirtualBox\ VMs/ScheelNix86/ScheelNix86.vhd bs=512 conv=notrunc seek=9

physical:
	sudo dd if=boot.bin   of=/dev/sda bs=512 conv=notrunc
	sudo dd if=stage2.bin of=/dev/sda bs=512 conv=notrunc seek=1
	sudo dd if=kernel.bin of=/dev/sda bs=512 conv=notrunc seek=9

clean:
	rm -rv boot.bin stage2.bin kernel.bin
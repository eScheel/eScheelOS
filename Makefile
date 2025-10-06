build:
	nasm boot/boot.asm -f bin -o boot.bin
	nasm boot/stage2.asm -f bin -o stage2.bin
	nasm kernel/kentry.asm -f bin -o kentry.bin


qemu:
	dd if=/dev/zero  of=escheelos.vhd bs=1M  count=100
	dd if=boot.bin   of=escheelos.vhd bs=512 conv=notrunc
	dd if=stage2.bin of=escheelos.vhd bs=512 conv=notrunc seek=1
	dd if=kentry.bin of=escheelos.vhd bs=512 conv=notrunc seek=9

virtual:
	dd if=boot.bin   of=/mnt/c/Users/jacob/VirtualBox\ VMs/eScheelOS\ 32-bit/eScheelOS\ 32-bit.vhd bs=512 conv=notrunc
	dd if=stage2.bin of=/mnt/c/Users/jacob/VirtualBox\ VMs/eScheelOS\ 32-bit/eScheelOS\ 32-bit.vhd bs=512 conv=notrunc seek=1
	dd if=kentry.bin of=/mnt/c/Users/jacob/VirtualBox\ VMs/eScheelOS\ 32-bit/eScheelOS\ 32-bit.vhd bs=512 conv=notrunc seek=9

physical:
	sudo dd if=boot.bin   of=/dev/sda bs=512 conv=notrunc
	sudo dd if=stage2.bin of=/dev/sda bs=512 conv=notrunc seek=1
	sudo dd if=kentry.bin of=/dev/sda bs=512 conv=notrunc seek=9

clean:
	rm -rv boot.bin stage2.bin kentry.bin
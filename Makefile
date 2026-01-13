# Use for FreeBSD.
CC=i386-unknown-freebsd14.3-gcc14
LINKER=i386-unknown-freebsd14.3-ld
BUILD_DIR="/home/jscheel/Github/eScheelOS/build"

# Use for Linux.
#CC=i686-elf-gcc
#LINKER=i686-elf-ld
#BUILD_DIR="/mnt/c/Users/jscheel/Github/eScheelOS/build"

# ...
CFLAGS=-I kernel/include/ -std=gnu99 -ffreestanding -Wall -Wextra -Wa,--noexecstack

.PHONY: all boot kernel clean

all: boot kernel

boot:
	nasm boot/mbr.asm    -f bin -o $(BUILD_DIR)/mbr.bin
	nasm boot/vbr.asm    -f bin -o $(BUILD_DIR)/vbr.bin
	nasm boot/stage2.asm -f bin -o $(BUILD_DIR)/stage2.bin

kernel:
	nasm kernel/kernel.asm    -f elf32 -o kernel.o
	nasm kernel/arch/gdt.asm  -f elf32 -o gdt.o
	nasm kernel/arch/idt.asm  -f elf32 -o idt.o
	nasm kernel/arch/isr.asm  -f elf32 -o isr.o
	nasm kernel/arch/irq.asm  -f elf32 -o irq.o
	nasm kernel/sys/io.asm    -f elf32 -o io.o
	$(CC) -c kernel/kernel.c           -o kernelc.o  $(CFLAGS)
	$(CC) -c kernel/kshell.c           -o kshell.o   $(CFLAGS)
	$(CC) -c kernel/arch/isr.c         -o isrc.o     $(CFLAGS)
	$(CC) -c kernel/drivers/vga.c      -o vga.o      $(CFLAGS)
	$(CC) -c kernel/drivers/pit.c      -o pit.o      $(CFLAGS)
	$(CC) -c kernel/drivers/keyboard.c -o keyboard.o $(CFLAGS)
	$(CC) -c kernel/drivers/pci.c      -o pci.o      $(CFLAGS)
	$(CC) -c kernel/drivers/ide.c      -o ide.o      $(CFLAGS)
	$(CC) -c kernel/drivers/fat32.c    -o fat32.o    $(CFLAGS)
	$(CC) -c kernel/drivers/elf32.c    -o elf32.o    $(CFLAGS)
	$(CC) -c kernel/drivers/serial.c   -o serial.o   $(CFLAGS)
	$(CC) -c kernel/lib/io.c           -o ioc.o      $(CFLAGS)
	$(CC) -c kernel/lib/string.c       -o string.o   $(CFLAGS)
	$(CC) -c kernel/lib/convert.c      -o convert.o  $(CFLAGS)
	$(CC) -c kernel/sys/logo.c         -o logo.o     $(CFLAGS)
	$(CC) -c kernel/sys/mmap.c         -o mem.o      $(CFLAGS)
	$(CC) -c kernel/sys/heap.c         -o heap.o     $(CFLAGS)
	$(CC) -c kernel/sys/paging.c       -o paging.o   $(CFLAGS)
	$(CC) -c kernel/sys/tasking.c      -o task.o     $(CFLAGS)
	$(LINKER) *.o -T link.ld -o $(BUILD_DIR)/kernel.elf
	rm -r *.o

clean:
	rm -rv $(BUILD_DIR)/* 
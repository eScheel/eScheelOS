#include <kernel.h>
#include <vga.h>
#include <pit.h>
#include <heap.h>
#include <string.h>

void kernel_main(uint8_t boot_drive)
{
    // ...
    vga_prints("BOOT_DRIVE: ");
    vga_printd(boot_drive);
    vga_printc('\n');

    // ...
    asm volatile("sti");
    KERNEL_IDLE();
}

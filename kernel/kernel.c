#include <kernel.h>

void kernel_main(uint8_t boot_drive)
{
    asm volatile("sti");
    
    vga_prints("BOOT_DRIVE: ");
    vga_printd(boot_drive);
    vga_printc('\n');

    for(;;){ continue; }
}
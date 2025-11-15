#include <kernel.h>
#include <vga.h>
#include <pit.h>
#include <ide.h>
#include <string.h>

void kernel_main(void)
{
    vga_prints("Hello, World!");

    while(1)
    {
        // Let's stop the cpu as opposed to endless spinning.
        asm volatile("hlt");
    }
}

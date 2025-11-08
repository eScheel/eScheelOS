#include <kernel.h>
#include <ide.h>
#include <vga.h>

void ide_init()
{

}

void ide_interrupt_handler()
{
    vga_printc('*');
}
#include <kernel.h>
#include <serial.h>
#include <vga.h>

void serial_init()
{
    
}

void com1_interrupt_handler()
{
    vga_printc('*');
}

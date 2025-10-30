#include <kernel.h>

#define keyboard_status 0x64
#define keyboard_data   0x60

static char scancode_to_ascii[] = {                                               \
    0x00, 0x00, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b', \
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',       \
    0x00, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`', 0x00,      \
    '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0x00, '*', 0x00,      \
    ' '
};

void keyboard_interrupt_handler()
{
    // Lowest bit of status will be set if buffer is not empty
    uint8_t status = INB(keyboard_status);
    if(status & 1)
    {
        char scancode = (char)INB(keyboard_data);
        if(scancode < 0) { return; }    // Is this really necessary?

        vga_printc(scancode_to_ascii[(uint8_t)scancode]);

        //vga_printh(scancode)
        //vga_printc('\n');
    }
}
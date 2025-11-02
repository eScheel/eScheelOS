#include <kernel.h>
#include <vga.h>
#include <keyboard.h>

void keyboard_init()
{
    return;
}

void keyboard_interrupt_handler()
{
    // Lowest bit of status will be set if buffer is not empty
    uint8_t status = INB(keyboard_status);

    // ...
    if(status & 1)
    {
        uint8_t scancode = INB(keyboard_data);

        // Was a key released?
        if(scancode & 0x80)
        {
            // The shift key?
            if(scancode == left_shift_released \
            || scancode == right_shift_released)
            {
                shift_key_pressed = 0;
            }
            return;
        }

        // Was a control key pressed?
        if(scancode == left_shift_pressed \
        || scancode == right_shift_pressed)
        {
            shift_key_pressed = 1;
            return;
        }

        // TODO: I guess create some kind of input buffer to store the characters,
        //  as opposed to printing directly on screen.
        if(!shift_key_pressed)
        {
            vga_printc(scancode_to_ascii[scancode]);
        }
        else 
        {
            vga_printc(scancode_to_ascii_shifted[scancode]);
        }

    }
}
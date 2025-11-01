#include <kernel.h>

#define keyboard_status 0x64
#define keyboard_data   0x60

#define escape_pressed      0x01 
#define left_shift_pressed  0x2a
#define right_shift_pressed 0x36
#define caps_lock_pressed   0x3a
#define left_arrow_pressed  0x4b
#define right_arrow_pressed 0x4d
#define up_arrow_pressed    0x48
#define down_arrow_pressed  0x50

#define left_shift_released     0xaa
#define right_shift_released    0xb6
#define caps_lock_released      0xba

static uint8_t shift_key_pressed = 0; 
//static uint8_t caps_key_pressed  = 0;

static char scancode_to_ascii[] = {                                               \
    0x00, 0x00, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b', \
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',       \
    0x00, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`', 0x00,      \
    '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0x00, '*', 0x00,      \
    ' ', 0x00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x00, 0x00, '7', '8', '9', '-',      \
    '4', '5', '6', '+', '1', '2', '3', '0', '.',
};

static char scancode_to_ascii_shifted[] = {                                            
    0x00, 0x00, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', '\b', 
    '\t', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n',       
    0x00, 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0x00,      
    '|', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0x00, '*', 0x00,      
    ' ', 0x00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x00, 0x00, '7', '8', '9', '-',      
    '4', '5', '6', '+', '1', '2', '3', '0', '.',
};

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
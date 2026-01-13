#include <kernel.h>
#include <keyboard.h>
#include <string.h>
#include <io.h>

static char scancode_to_ascii[] = {                                               \
    0x00, 0x00, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b', \
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',       \
    0x00, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`', 0x00,      \
    '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0x00, '*', 0x00,      \
    ' ', 0x00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x00, 0x00, '7', '8', '9', '-',      \
    '4', '5', '6', '+', '1', '2', '3', '0', '.',
};

static char scancode_to_ascii_shifted[] = {                                       \
    0x00, 0x00, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', '\b', \
    '\t', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n',       \
    0x00, 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0x00,       \
    '|', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0x00, '*', 0x00,       \
    ' ', 0x00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x00, 0x00, '7', '8', '9', '-',      \
    '4', '5', '6', '+', '1', '2', '3', '0', '.',
};

static uint8_t shift_key_pressed; 
//static uint8_t caps_key_pressed;
uint8_t f12_pressed;    // Used to start the kernel shell.

volatile char keyboard_input_buffer[1024];
static size_t keyboard_buffer_index;

//========================================================================================
/* Initialize the keyboard. */
void keyboard_init()
{
    shift_key_pressed = 0;
    f12_pressed = 0;
    keyboard_reset_buffer();
    return;
}

//========================================================================================
/* Feels like only keyboard should reset the keyboard buffer for next use. */
void keyboard_reset_buffer()
{
    asm volatile("cli");
    for(int i = 0; i < 1024; i++) {
        keyboard_input_buffer[i] = 0;
    }
    keyboard_buffer_index = 0;
    asm volatile("sti");
}

//========================================================================================
/* ... */
void keyboard_interrupt_handler()
{
    // Lowest bit of status will be set if buffer is not empty
    uint8_t status = INB(keyboard_status);

    if(status & 1)
    {
        uint8_t scancode = INB(keyboard_data);
        if(scancode == 0xE0) { return; }

        if(scancode == 0x58) 
        {
            if(!f12_pressed)
            {
                f12_pressed = 1;
            }
            return;
        }

        // Handle Key Release.
        if(scancode & 0x80)
        {
            if(scancode == left_shift_released 
            || scancode == right_shift_released)
            {
                shift_key_pressed = 0;
            }
            // ...
            return;
        }

        // Handle shift key press.
        if(scancode == left_shift_pressed 
        || scancode == right_shift_pressed)
        {
            shift_key_pressed = 1;
            return;
        }

        // Handle regular key press. (Character).
        char c;
        if(!shift_key_pressed)
        {
            c = scancode_to_ascii[scancode];
        }
        else 
        {
            c = scancode_to_ascii_shifted[scancode];
        }

        // Ignore non-printable keys
        if(c == 0)
        {
            return;
        }

        // Handle Backspace
        if (c == '\b')
        {
            if (keyboard_buffer_index > 0)
            {
                keyboard_input_buffer[keyboard_buffer_index] = c;   // Add '\b' to the buffer so callers can handle.
                --keyboard_buffer_index;
            }
            return;
        }

        // Add the normal character to the buffer.
        if(keyboard_buffer_index < 1023)
        {
            keyboard_input_buffer[keyboard_buffer_index] = c;
            keyboard_buffer_index++;
            return;
        }
        
        // If buffer is full (keyboard_buffer_index is 1023), we just drop the key.
    }
}
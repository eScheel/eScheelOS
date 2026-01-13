#include <io.h>
#include <keyboard.h>
#include <vga.h>

//========================================================================================
/* A simple kernel-level printf implementation. */
void kprintf(const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);

    // ...
    for(size_t i=0; fmt[i]!='\0'; i++)
    {
        // If it's not a format specifier, just print the character.
        if(fmt[i] != '%')
        {
            vga_printc(fmt[i]);
            continue;
        }

        // We've found a '%', look at the next character for the type.
        i++;
        switch(fmt[i])
        {
            case 'c': // Character
            {
                // 'char' is promoted to 'int' when passed as a vararg.
                char c = (char)va_arg(args, int);
                vga_printc(c);
                break;
            }
            case 's': // String
            {
                const char* s = va_arg(args, const char*);
                if(!*s) {
                    s = "(null)"; // Handle null pointers gracefully
                }
                vga_prints(s);
                break;
            }
            case 'd': // Unsigned 32-bit Decimal
            {
                // Our vga_printd takes a uint32_t.
                // This will treat signed integers as large unsigned numbers.
                uint32_t d = va_arg(args, uint32_t);
                vga_printd(d);
                break;
            }
            case 'x': // Unsigned 32-bit Hex
            {
                uint32_t h = va_arg(args, uint32_t);
                vga_printh(h);
                break;
            }
            case '%': // Literal percent sign
            {
                vga_printc('%');
                break;
            }
            default: // Unknown specifier
            {
                // Print it as-is to indicate an error
                vga_printc('%');
                vga_printc(fmt[i]);
                break;
            }
        }
    }

    va_end(args);
}

//========================================================================================
/* ... */
void kgets(char *s)
{
    // Reset the actual keyboard buffer, where we get our new string from.
    keyboard_reset_buffer();

    // ...
    int i = 0;
    while(1)
    {
        // Wait for a character to be pressed.
        while(!keyboard_input_buffer[i]) {
            asm volatile("hlt"); 
        }

        // If return is pressed, we are done.
        if(keyboard_input_buffer[i] == '\n') { break; }

        // Handle Backspace
        else if(keyboard_input_buffer[i] == '\b')
        {
            // Only backspace if the buffer isn't empty
            if(i > 0)
            {
                keyboard_input_buffer[i] = 0; // Erase the '\b' char
                --i;
                keyboard_input_buffer[i] = 0; // Erase the last char
                s[i] = 0;   // Also erase the last char from our input sring.

                // ECHO the character and update cursor position.
                vga_printc('\b');
                vga_update_cursor();
            }
            continue;
        }

        // Add the key to the buffer.
        s[i] = keyboard_input_buffer[i];

        // kbd_in_buf has a max of 1024.
        // I believe we need to match that.
        if(i < 1023) 
        {
            // ECHO the character and update cursor position.
            vga_printc(s[i]);
            vga_update_cursor();

            // Get rdy for next char.
            i++;
        }
    }
}

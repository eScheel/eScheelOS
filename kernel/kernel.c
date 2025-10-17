#include <stddef.h>
#include <stdint.h>

#define VGA_WIDTH   80
#define VGA_HEIGHT  25
#define VGA_MEMORY  0xB8000

size_t terminal_row;
size_t terminal_column;

uint8_t  terminal_color;
uint8_t* terminal_buffer = (uint8_t*)VGA_MEMORY;

const char* magic = "Scheel'Nix";

void kernel_main() 
{
    size_t i = 0;
    size_t n = 0;
    while(n < 10)
    {
        terminal_buffer[i] = magic[n];
        i += 1;

        terminal_buffer[i] = 0x1f;
        i += 1;

        n += 1;
    }

    return;
}
#include <kernel.h>

extern void OUTB(uint16_t addr, uint8_t byte);

extern size_t strlen(const char* str);
extern void memset(void* data, uint8_t c, size_t n);

#define VGA_WIDTH  80
#define VGA_HEIGHT 25
#define VGA_MEMORY 0xB8000 

size_t row;
size_t column;
uint8_t color;

uint16_t* terminal_buffer = (uint16_t*)VGA_MEMORY;

/* ... */
void vga_init() 
{
	color = 0x1f;
	
	// Clear the screen.
	for(column = 0; column < VGA_HEIGHT; column++) 
    {
		for(row = 0; row < VGA_WIDTH; row++) 
        {
			const size_t index = column * VGA_WIDTH + row;
			terminal_buffer[index] = (uint16_t)' ' | (uint16_t)(color << 8);
		}
	}

    column = 0;
    row = 0;
    return;
}

/* ... */
static void vga_update_cursor()
{
	/* 
	 * The equation for finding the index in a linear chunk of memory.
	 * 	Index = [(y * width) + x]
	 */
	uint16_t index = column * VGA_WIDTH + row;
	/* 
	 *  This sends a command to indicies 14 and 15 in the
	 *  CRT Control Register of the VGA controller. These
	 *  are the high and low bytes of the index that show
	 *  where the hardware cursor is to be 'blinking'.
	 */
	OUTB(0x3D4, 14);
	OUTB(0x3D5, (index >> 8));
	OUTB(0x3D4, 15);
	OUTB(0x3D5, index);
	return;
}

/* ... */
void vga_putc(char c, size_t x, size_t y)
{
	uint16_t index = y * VGA_WIDTH + x;
	terminal_buffer[index] = (uint16_t)c | (uint16_t)(color << 8);
	return;
}

/* ... */
void vga_printc(char c) 
{
	const size_t index = column * VGA_WIDTH + row;

	if(c == '\n')
	{
		column += 1;
		if(column == VGA_HEIGHT)
        {
			column = 0;
        }

		row = 0;

		goto end_vga_printc;
	}

	terminal_buffer[index] = ((uint16_t)c | (uint16_t)(color << 8));
	row += 1;

	if (row == VGA_WIDTH) 
    {
		row = 0;
		column += 1;
		if(column == VGA_HEIGHT)
        {
			column = 0;		// TODO: Handle scrolling.
        }
	}

end_vga_printc:
	vga_update_cursor();
    return;
}

/* ... */
void vga_prints(const char* data) 
{
	for(size_t i = 0; data[i]!='\0'; i++)
    {
        vga_printc(data[i]);
    }
}

/* ... */
void vga_printh(uint32_t h)
{
	int i;
	int n = 0;
	char hexstr[9];

	for(i=28; i>=0; i-=4) 
	{
		uint8_t x = (h >> i) & 0x0f;
		hexstr[n] = "0123456789ABCDEF"[x];
		n += 1;
	}
	hexstr[n] = '\0';

	vga_prints(hexstr);
	return;
}

/* ... */
void vga_printd(uint32_t d)
{
    char buffer[11];
    int index = 0;

    // The main loop won't run if d is 0, so we handle it here.
    if (d == 0) {
        vga_printc('0');
        return;
    }

    // Main Logic: Convert number to ASCII in reverse order
    // We use a temporary variable `num` so the original `d` isn't modified.
    uint32_t num = d;

    // This works by repeatedly taking the number modulo 10 (to get the last digit) 
	// and then dividing by 10 (to remove the last digit).
    while(num > 0) 
	{
        // num % 10` gives the rightmost digit (0-9).
        // Adding '0' (ASCII value 48) converts it to the character '0'-'9'.
        buffer[index] = (num % 10) + '0';
        index++; 		// Move to the next spot in the buffer
        num /= 10; 		// Remove the last digit
    }

    // We now print the buffer in reverse to get the correct order.
    // The last valid character is at index `i - 1`.
    while(index > 0) 
	{
        index--;
        vga_printc(buffer[index]);
    }

	return;
}


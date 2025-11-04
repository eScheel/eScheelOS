#include <kernel.h>
#include <vga.h>

static struct video_graphics_array {
	size_t cursor_x;
	size_t cursor_y;
	uint8_t color;
}vga;

static uint16_t* terminal_buffer = (uint16_t*)VGA_MEMORY;

size_t vga_get_x()
{
	//size_t ret = vga.cursor_x;
	return(vga.cursor_x);
}

size_t vga_get_y()
{
	//size_t ret = vga.cursor_y;
	return(vga.cursor_y);
}

/* Initialize the vga memory. */
void vga_init() 
{
	vga.color = 0x1f;
	
	// Clear the screen.
	for(vga.cursor_y = 0; vga.cursor_y < VGA_HEIGHT; vga.cursor_y++) 
    {
		for(vga.cursor_x = 0; vga.cursor_x < VGA_WIDTH; vga.cursor_x++) 
        {
			const size_t index = vga.cursor_y * VGA_WIDTH + vga.cursor_x;
			terminal_buffer[index] = (uint16_t)' ' | (uint16_t)(vga.color << 8);
		}
	}

    vga.cursor_y = 0;
    vga.cursor_x = 0;
    return;
}

/* ... */
static void vga_update_cursor()
{
	/* 
	 * The equation for finding the index in a linear chunk of memory.
	 * 	Index = [(y * width) + x]
	 */
	uint16_t index = vga.cursor_y * VGA_WIDTH + vga.cursor_x;
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
static void vga_scroll()
{
	if(vga.cursor_y == VGA_HEIGHT)
	{
		size_t i;
		uint16_t blank = (uint16_t)' ' | (uint16_t)(vga.color << 8);

		// Move all rows up by one.
		// We loop 24 times (VGA_HEIGHT - 1).
		for (i = 0; i < (VGA_HEIGHT - 1) * VGA_WIDTH; i++)
		{
			// terminal_buffer[i] = the cell on the current row
			// terminal_buffer[i + VGA_WIDTH] = the cell on the *next* row
			terminal_buffer[i] = terminal_buffer[i + VGA_WIDTH];
		}

		// Clear the last row.
		// 'i' is already at the start of the last row: (VGA_HEIGHT - 1) * VGA_WIDTH
		for ( ; i < VGA_HEIGHT * VGA_WIDTH; i++)
		{
			terminal_buffer[i] = blank;
		}

		// Reset the vga cursor state to the beginning of the last line.
		vga.cursor_y = VGA_HEIGHT - 1;
		vga.cursor_x = 0;
	}
}

/* ... */
void vga_putc(char c, size_t x, size_t y)
{
	uint16_t index = y * VGA_WIDTH + x;
	terminal_buffer[index] = (uint16_t)c | (uint16_t)(vga.color << 8);
	return;
}

/* ... */
void vga_puts(const char *s, size_t x, size_t y)
{
	for(size_t i=0; s[i]!=0; i++)
	{
		vga_putc(s[i], x, y);
		
		x++;
		if(x == VGA_WIDTH)
		{
			x  = 0;
			y += 1;		// TODO: Handle scrolling.
		}
	}
}

/* ... */
void vga_printc(char c) 
{
	// Obtain the current cursor location and index.
	size_t index = vga.cursor_y * VGA_WIDTH + vga.cursor_x;

	// Handle NULL.
	if(c == '\0')
	{
		return;
	}

	// Handle LF.
	else if(c == '\n')
	{
		vga.cursor_y += 1;
		vga.cursor_x = 0;
		goto end_vga_printc;
	}

	// Handle TAB.
	else if(c == '\t')
	{
		vga_prints("    ");
		return;
	}

	// Handle BS.
	else if(c == '\b')
	{
		if(vga.cursor_x <= 0)
		{ 
			return;
		}
		vga.cursor_x -= 1;
		terminal_buffer[index-1] = ((uint16_t)' ' | (uint16_t)(vga.color << 8));
		goto end_vga_printc;
	}

	terminal_buffer[index] = ((uint16_t)c | (uint16_t)(vga.color << 8));
	vga.cursor_x += 1;

	// Check if we are at the the right edge of the screen.
	if (vga.cursor_x == VGA_WIDTH) 
    {
		vga.cursor_x = 0;
		vga.cursor_y += 1;
	}

end_vga_printc:
	vga_scroll();
	vga_update_cursor();
    return;
}

/* ... */
void vga_prints(const char* data) 
{
	// ...
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

	// Loop through the 32-bit integer, 4 bits (one nibble) at a time.
    // Start at bit 28 (the most significant nibble) and go down to bit 0.
	for(i=28; i>=0; i-=4) 
	{
		// Isolate the current nibble.
        // (h >> i): Right-shift the integer to move the desired nibble to the least significant position.
        //  & 0x0f:   Use a bitwise AND with a mask (binary 00001111) to isolate the 4 bits.
		uint8_t x = (h >> i) & 0x0f;

		// Convert the numeric value (0-15) of the nibble to its ASCII hex character ('0'-'9', 'A'-'F').
        // This is done by using the value 'x' as an index into a string literal containing all hex characters.
		hexstr[n] = "0123456789ABCDEF"[x];
		n += 1;
	}
	// Let's NULL termiate the string now before we try to print it.
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

    // Main Logic is to Convert number to ASCII in reverse order
    // We use a temporary variable num so the original d isn't modified.
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
    // The last valid character is at index i - 1
    while(index > 0) 
	{
        index--;
        vga_printc(buffer[index]);
    }

	return;
}

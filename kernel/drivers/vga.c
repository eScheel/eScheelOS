#include <kernel.h>
#include <vga.h>

struct video_graphics_array {
	uint16_t* terminal_buffer;
	uint8_t   color;
	uint16_t  cursor_x;
	uint16_t  cursor_y;
}/*__attribute__((packed))*/;

// Main VGA? The idea is to have multiple of these in the future.
static struct video_graphics_array vga;

//========================================================================================
/* Get the current position of cursor_x */
uint16_t vga_get_x()
{
	return(vga.cursor_x);
}

//========================================================================================
/* Get the current position of cursor_y */
uint16_t vga_get_y()
{
	return(vga.cursor_y);
}

//========================================================================================
/* Set the current position of cursor_x */
void vga_set_x(uint16_t x)
{
	vga.cursor_x = x;
}

//========================================================================================
/* Set the current position of cursor_y */
void vga_set_y(uint16_t y)
{
	vga.cursor_y = y;
}

//========================================================================================
/* Set the current screen color. */
void vga_set_color(uint8_t c)
{
	vga.color = c;
	// TODO: Save current screen, clear with new color, load current screen again.
}

//========================================================================================
/* Initialize the vga memory. */
void vga_init() 
{
	vga_disable_cursor();
	vga.terminal_buffer = (uint16_t*)VGA_MEMORY;
	vga.color = 0x1f;
	
	// Clear the screen.
	for(vga.cursor_y = 0; vga.cursor_y < VGA_HEIGHT; vga.cursor_y++) 
    {
		for(vga.cursor_x = 0; vga.cursor_x < VGA_WIDTH; vga.cursor_x++) 
        {
			const size_t index = vga.cursor_y * VGA_WIDTH + vga.cursor_x;
			vga.terminal_buffer[index] = (uint16_t)' ' | (uint16_t)(vga.color << 8);
		}
	}

	// Reset position.
    vga.cursor_y = 0;
    vga.cursor_x = 0;
}

//========================================================================================
/* ... */
void vga_update_cursor()
{
	// The equation for finding the index in a linear chunk of memory.
	// Index = [(y * width) + x]
	uint16_t index = vga.cursor_y * VGA_WIDTH + vga.cursor_x;

	// This sends a command to indicies 14 and 15 in the
	// CRT Control Register of the VGA controller. These
	// are the high and low bytes of the index that show
	// where the hardware cursor is to be 'blinking'.
	OUTB(0x3D4, 14);
	OUTB(0x3D5, (index >> 8));
	OUTB(0x3D4, 15);
	OUTB(0x3D5, index);
}

//========================================================================================
/* Enables the blinky cursor. */
void vga_enable_cursor()
{
	OUTB(0x3D4, 0x0A);
	OUTB(0x3D5, (INB(0x3D5) & 0xC0) | 14);
	OUTB(0x3D4, 0x0B);
	OUTB(0x3D5, (INB(0x3D5) & 0xE0) | 15);
}

//========================================================================================
/* Disabled the blinky cursor. */
void vga_disable_cursor()
{
	OUTB(0x3D4, 0x0A);
	OUTB(0x3D5, 0x20);
}

//========================================================================================
/* Scroll the screen when reaching the bottom. */
static void vga_scroll()
{
	if(vga.cursor_y == VGA_HEIGHT)
	{
		size_t i;

		// Move all rows up by one.
		// We loop 24 times (VGA_HEIGHT - 1).
		for(i=0; i<(VGA_HEIGHT-1)*VGA_WIDTH; i++)
		{
			// terminal_buffer[i] = the cell on the current row.
			// terminal_buffer[i + VGA_WIDTH] = the cell on the next row.
			vga.terminal_buffer[i] = vga.terminal_buffer[i + VGA_WIDTH];
		}

		// Clear the last row.
		// 'i' is already at the start of the last row: (VGA_HEIGHT - 1) * VGA_WIDTH
		for(; i<(VGA_HEIGHT*VGA_WIDTH); i++)
		{
			// Fill in entire screen with blanks.
			vga.terminal_buffer[i] = ((uint16_t)' ' | (uint16_t)(vga.color << 8));;
		}

		// Reset the vga cursor state to the beginning of the last line.
		vga.cursor_y = VGA_HEIGHT - 1;
		vga.cursor_x = 0;
	}
}

//========================================================================================
/* Clear the screen on demand. */
void vga_clear()
{
	// Clear the screen.
	for(vga.cursor_y = 0; vga.cursor_y < VGA_HEIGHT; vga.cursor_y++) 
    {
		for(vga.cursor_x = 0; vga.cursor_x < VGA_WIDTH; vga.cursor_x++) 
        {
			const size_t index = vga.cursor_y * VGA_WIDTH + vga.cursor_x;
			vga.terminal_buffer[index] = ((uint16_t)' ' | (uint16_t)(vga.color << 8));
		}
	}

	// Reset cursor position.
    vga.cursor_y = 0;
    vga.cursor_x = 0;
}

//========================================================================================
/* Put a character on the screen at a specific location. */
void vga_putc(char c, size_t x, size_t y)
{
	uint16_t index = y * VGA_WIDTH + x;
	vga.terminal_buffer[index] = ((uint16_t)c | (uint16_t)(vga.color << 8));
	return;
}

//========================================================================================
/* Prints the next sequential character to the screen. */
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
		// Handle left most side of screen.
		if(vga.cursor_x <= 0)
		{
			if(vga.cursor_y <= 0)
			{
				return;
			}
			vga.cursor_y -= 1;
			vga.cursor_x = VGA_WIDTH - 1;
		}
		else 
		{
			vga.cursor_x -= 1;
		}

		// Print the backspace character.
		vga.terminal_buffer[index-1] = ((uint16_t)' ' | (uint16_t)(vga.color << 8));
		goto end_vga_printc;
	}

	// Nothing to handle, just print the character.
	vga.terminal_buffer[index] = ((uint16_t)c | (uint16_t)(vga.color << 8));
	vga.cursor_x += 1;	// Increment the x position.

	// Check if we are at the the right edge of the screen.
	if(vga.cursor_x == VGA_WIDTH) 
    {
		vga.cursor_x = 0;
		vga.cursor_y += 1;
	}

end_vga_printc:
	vga_scroll();
}

//========================================================================================
/* Prints a sequential string of characters to the screen. */
void vga_prints(const char* data) 
{
	// We print until a null value is reached.
	for(size_t i = 0; data[i]!='\0'; i++)
    {
        vga_printc(data[i]);
    }
}

//========================================================================================
/* Converts a string to 32bit hex value and then prints it out (without leading zeros). */
void vga_printh(uint32_t h)
{
	int i;
	int n = 0;
	char hexstr[9];
    
    // Handle the special case of 0
    if(h == 0) 
	{
        vga_printc('0');
        return;
    }

    // Flag to track if we've encountered a non-zero nibble yet
	int leading_zero = 1;

	// Loop through the 32-bit integer, 4 bits (one nibble) at a time.
    // Start at bit 28 (the most significant nibble) and go down to bit 0.
	for(i=28; i>=0; i-=4) 
	{
		// Isolate the current nibble.
		uint8_t x = (h >> i) & 0x0f;
        
        // Check if this is the first non-zero nibble
        if(x != 0) 
		{
            leading_zero = 0; // Found the first significant digit
        }
        
        // Only start recording characters once the leading zeros are skipped
        if(!leading_zero) 
        {
		    // Convert the numeric value (0-15) to its ASCII hex character.
		    hexstr[n] = "0123456789ABCDEF"[x];
		    n += 1;
        }
	}
    
	// NULL terminate the string before printing.
	hexstr[n] = '\0';
	vga_prints(hexstr);
}

//========================================================================================
/* Converts a string to 32bit decimal value and then prints it out. */
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
}

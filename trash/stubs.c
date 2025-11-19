/* ... */
void display_memory_map(uint16_t* mmap_desc_addr)
{
    vga_prints("MMAP_ENTRIES: \0");
    size_t num_entries = (uint16_t)mmap_desc_addr[0];
    vga_printh(num_entries);
    vga_printc('\n');

    // ...
    struct SMAP_entry* entry_array = (struct SMAP_entry*)(mmap_desc_addr + 2);
    for(size_t i=0; i<num_entries; i++)
    {
        struct SMAP_entry* entry = &entry_array[i];
        if(entry->type != 0x01) { continue; }

        vga_printh(entry->base_addr_high);
        vga_printh(entry->base_addr_low);
        vga_printc('|');

        vga_printh(entry->length_high);
        vga_printh(entry->length_low);
        vga_printc('|');

        vga_printh(entry->type);
        vga_printc('\n');
    }
}








    uint64_t base   = ((uint64_t)entry->base_addr_high << 32) | entry->base_addr_low;
    uint64_t length = ((uint64_t)entry->length_high << 32)    | entry->length_low;













extern struct HEAP_info system_heap;
extern uint32_t uptime_seconds;
extern uint32_t uptime_minutes;
extern uint32_t uptime_hours;
void vga_update_hud()
{
	hud_active = 1;

	size_t rx = vga.row;
	size_t ry = vga.column;
	uint8_t rc = vga.color;

	vga.row = 0;
	vga.column = 24;
	vga.color = 0x0f;

	for(size_t x=0;x<VGA_WIDTH-1; x++)
	{
		vga_printc(' ');
	}
	vga.row = 10;

	vga_prints("uptime(\0");
	vga_printd(uptime_hours);
	vga_printc(':');
	vga_printd(uptime_minutes);
	vga_printc(':');
	vga_printd(uptime_seconds);
	vga_printc(')');

	vga.row = 40;
	vga_prints("heap: available(\0");
	vga_printd(system_heap.available/(1024*1024));
	vga_prints("MB)  used(\0");
	vga_printd(system_heap.used/(1024*1024));
	vga_prints("MB)\0");

	vga.row = rx;
	vga.column = ry;
	vga.color = rc;

	hud_active = 0;
}






volatile uint32_t system_uptime_seconds;
volatile uint32_t system_uptime_minutes;
volatile uint32_t system_uptime_hours;
volatile uint32_t system_uptime_days;


    // Has a second passed?
    if(timer_ticks % 100 == 0)
    {
        system_uptime_seconds++;

        // Has a minute passed?
        if(system_uptime_seconds >= 60)
        {
            system_uptime_minutes++;

            // Has an hour passed?
            if(system_uptime_minutes >= 60)
            {
                system_uptime_hours++;

                // Has a day passed?
                if(system_uptime_hours >= 24)
                {
                    system_uptime_days++;

                    // TODO: Years.

                    system_uptime_hours = 0;
                }
                system_uptime_minutes = 0;
            }
            system_uptime_seconds = 0;
        }
    }





/* Converts a string to 32bit hex value and then prints it out. */
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
}



    


    // Subtract what we added to get past the kernel from the full length.
    // Then divide that by 8. This seems to give about 64MB on a 512MB system.
    //size_t length = ((available_memory_map[main_memory_index].length_low - 0x100000) / HEAP_ALIGNMENT);
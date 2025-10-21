#include <kernel.h>

extern void vga_init();
extern void vga_putc(char, size_t, size_t);
extern void vga_printc(char);
extern void vga_prints(const char*);
extern void vga_printh(uint32_t);
extern void vga_printd(uint32_t);

extern size_t strlen(const char* str);
extern void memset(void* data, uint8_t c, size_t n);

extern void memory_map_init(uint16_t* mmap_desc_addr);

extern size_t mmap_avail_entry_count;
extern memory_region_t memory_map[SMAP_entry_max];
uint32_t available_memory = 0;

const char *osname = "eScheel OS\n\0";

/* ... */
void kernel_main(uint16_t* mmap_desc_addr, uint8_t video_mode, uint8_t boot_drive) 
{
    // Initialize graphics and print something.
    vga_init();
    vga_prints(osname);

    // Initialize available memory map and display total. 
    memory_map_init(mmap_desc_addr);
    for(size_t i=0; i<mmap_avail_entry_count; i++)
    {
        memory_region_t mmap_region = memory_map[i];
        available_memory += mmap_region.length;
    }
    vga_prints("Total Memory: \0");
    vga_printd(available_memory/1048576);
    vga_prints("MB\n\0");


    // ...
    vga_putc(LOADING_SYMBOL, 0, 24);
    return;
}
#include <kernel.h>

extern void vga_init();
extern void vga_putc(char c, size_t x, size_t y);
extern void vga_printc(char c);
extern void vga_prints(const char* data);
extern void vga_printh(uint32_t h);
extern void vga_printd(uint32_t d);

extern size_t strlen(const char* str);
extern void memset(void* data, uint8_t c, size_t n);

extern void memory_map_init(uint16_t* mmap_desc_addr);

const char *osname = "eScheel OS\n\0";

/* ... */
void kernel_main(uint16_t* mmap_desc_addr/*, uint8_t video_mode, uint8_t boot_drive*/) 
{
    vga_init();
    vga_prints(osname);

    memory_map_init(mmap_desc_addr);

    return;
}
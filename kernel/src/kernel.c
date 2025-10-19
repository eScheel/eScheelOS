#include <stddef.h>
#include <stdint.h>

extern void vga_init();
extern void vga_printc(char c);
extern void vga_prints(const char* data);
extern void vga_printh(uint32_t h);

extern size_t strlen(const char* str);

extern void display_memory_map(uint16_t* mmap_desc_addr);
extern void memset(void* data, uint8_t c, size_t n);

const char *osname = "eScheel OS\n\0";

/* ... */
void kernel_main(uint16_t* mmap_desc_addr) 
{
    vga_init();
    vga_prints(osname);

    display_memory_map(mmap_desc_addr);

    return;
}
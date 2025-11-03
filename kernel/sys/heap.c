#include <kernel.h>
#include <vga.h>

struct HEAP_info {
    uint32_t base_addr;
    uint32_t length;
    uint32_t available;
    uint32_t used;
}__attribute__((packed));
struct HEAP_info system_heap;

void heap_init(uint32_t base_addr, uint32_t length)
{
    // Are we less than 2MB
    if(length < 2097152)
    {
        vga_prints("Not enough memory for a heap.\n");
        SYSTEM_HALT();
    }

    // For now we just allocate 1MB after the kernel offset for the kernel.
    // And then we divide the length by 2 to save half memory for other stuff.
    base_addr += (1024 * 1024);
    length /= 2;

    // ...
    system_heap.base_addr = base_addr;
    system_heap.length = length;
    system_heap.available = length;
    system_heap.used = 0;
}
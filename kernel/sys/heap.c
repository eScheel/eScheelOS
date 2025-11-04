#include <kernel.h>
#include <heap.h>
#include <vga.h>

struct HEAP_info system_heap;

void heap_init(uint32_t base_addr, uint32_t length)
{
    // For now we just allocate 1MB after the kernel offset for the kernel.
    // And then just attempt to allocate 0x800000 bytes for the heap.
    base_addr += (1024 * 1024);
    size_t len = 0x800000;
    if(len > length)
    {
        vga_prints("Not enough memory for a heap.\n");
        SYSTEM_HALT();        
    }

    // ...
    system_heap.base      = base_addr;
    system_heap.length    = len;
    system_heap.available = len;
    system_heap.used      = 0;
    system_heap.end       = base_addr + len;
}

/* ... */
void print_heap_info()
{
    vga_prints("offset     size   avail   used    top\n");
    vga_printh(system_heap.base);
    vga_prints("h  ");
    vga_printd(system_heap.length/(1024*1024));
    vga_prints("MB    ");
    vga_printd(system_heap.available/(1024*1024));
    vga_prints("MB     ");
    vga_printd(system_heap.used);
    vga_prints("B      ");
    vga_printh(system_heap.end);
    vga_prints("h\n");
}

/* ... */
void* malloc(size_t sz)
{
    if(sz == 0) 
    {
        return((void*)0); 
    }

    return((void*)0);
}
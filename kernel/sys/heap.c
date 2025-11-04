#include <kernel.h>
#include <heap.h>
#include <vga.h>
#include <string.h>

struct HEAP_info system_heap;

void heap_init(uint32_t base_addr, uint32_t length)
{
    // For now we just allocate starting 1MB after the kernel offset.
    base_addr += (1024 * 1024);
    size_t len = (length/2);

    // ...
    system_heap.base      = base_addr;
    system_heap.size      = len;
    system_heap.used      = 0;
    system_heap.end       = base_addr + len;

    // ...
    memset((uint32_t*)system_heap.base, 0, system_heap.size);
}

/* ... */
void print_heap_info()
{
    vga_prints("offset     size     avail     used    top\n");
    vga_printh(system_heap.base);
    vga_prints("h  ");
    vga_printd(system_heap.size/(1024*1024));
    vga_prints("MB    ");
    vga_printd(((system_heap.size-system_heap.used)/(1024*1024)));
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
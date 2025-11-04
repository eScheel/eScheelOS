#include <kernel.h>
#include <heap.h>
#include <vga.h>
#include <string.h>

struct HEAP_info system_heap;
static uint32_t current_block_address;

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
    current_block_address = system_heap.base;
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
    vga_printd(system_heap.used/(1024*1024));
    vga_prints("MB     ");
    vga_printh(system_heap.end);
    vga_prints("h\n");
}

// ...
typedef struct {
    uint8_t reserved;
    uint32_t size;
}malloc_t;

/* ... */
void* malloc(size_t sz)
{
    uint32_t block = system_heap.base;
    
    if(sz == 0) 
    {
        return((void*)0); 
    }

    // Let's find some free memory.
    while(block < current_block_address)
    {
        malloc_t* alloc = (malloc_t*)block;

        if(alloc->reserved == 0)
        {
            // Do we have enough left to allocate.
            if((block + (sz + sizeof(malloc_t))) > system_heap.end)
            {
                // TODO: Check freed up memory.
                return((void*)0);
            }
            break;
        }
        else {
            // Skip past the allocated size plus the struct.
            block += (alloc->size + sizeof(malloc_t));
        }
    }

    // ...
    malloc_t* alloc = (malloc_t*)block;
    alloc->reserved = 1;
    alloc->size = sz;
    system_heap.used += (alloc->size + sizeof(malloc_t));
    current_block_address = block + (alloc->size + sizeof(malloc_t));
    return((void*)block + sizeof(malloc_t));
}

/* ... */
void free(void* b)
{
    malloc_t *alloc = (b - sizeof(malloc_t));

    alloc->reserved = 0;
    system_heap.used -= (alloc->size + sizeof(malloc_t));
    memset(b, 0, alloc->size);
    alloc->size = 0;

    return;
}
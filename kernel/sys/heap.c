#include <kernel.h>
#include <heap.h>
#include <vga.h>
#include <string.h>

struct HEAP_info system_heap;
static uint32_t current_block_address; // This is our "high-water mark"

// Define our alignment boundary
#define HEAP_ALIGNMENT 8

void heap_init(uint32_t base_addr, uint32_t length)
{
    // For now we just allocate starting 1MB after the kernel offset.
    base_addr += (1024 * 1024);

    // Ensure the heap base itself is aligned to our 8-byte boundary
    if (base_addr % HEAP_ALIGNMENT != 0) 
    {
        base_addr = (base_addr + (HEAP_ALIGNMENT - 1)) & ~(HEAP_ALIGNMENT - 1);
    }

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
    uint32_t size;    // Size of the data payload (not including this header)
    uint8_t reserved; // 1 = used, 0 = free
    uint8_t padding[3]; // Pad struct to 8 bytes.
} malloc_t; 

// Define a minimum block size. 
// (sizeof(malloc_t) [8] + 16) = 24 bytes. This is fine.
#define MIN_BLOCK_SPLIT (sizeof(malloc_t) + 16)

/* ... */
void* malloc(size_t sz)
{
    if(sz == 0) 
    {
        return((void*)0); 
    }

    // Align the requested size UP to the nearest 8 bytes.
    // This ensures that the *next* block header will also be aligned.
    if(sz % HEAP_ALIGNMENT != 0) 
    {
        sz = (sz + (HEAP_ALIGNMENT - 1)) & ~(HEAP_ALIGNMENT - 1);
    }

    // Calculate the total size needed for the new block (header + data)
    size_t total_needed = sz + sizeof(malloc_t);

    // Iterate from the base of the heap up to the high-water mark
    uint32_t block_iter = system_heap.base;
    while(block_iter < current_block_address)
    {
        // ...
        malloc_t* alloc = (malloc_t*)block_iter;
        size_t current_block_total_size = alloc->size + sizeof(malloc_t);

        // Check if this block is free AND big enough for the request
        if (alloc->reserved == 0 && alloc->size >= sz)
        {
            // Found a suitable block. Can we split it?
            size_t remaining_size = current_block_total_size - total_needed;
            if (remaining_size >= MIN_BLOCK_SPLIT)
            {
                /* Split the block */

                // Resize the block we're about to use
                alloc->reserved = 1;
                alloc->size = sz; // Set to the *new* requested size
                system_heap.used += total_needed;

                // Create a *new* free block header in the remaining space
                uint32_t new_free_block_addr = block_iter + total_needed;
                malloc_t* new_free_alloc = (malloc_t*)new_free_block_addr;
                new_free_alloc->reserved = 0;
                new_free_alloc->size = remaining_size - sizeof(malloc_t);
            }
            else
            {
                // Use the whole block (not enough space to split)
                alloc->reserved = 1;
                system_heap.used += current_block_total_size;
            }
            
            return((void*)block_iter + sizeof(malloc_t));
        }
        
        // Not a match, move to the next block header
        block_iter += current_block_total_size;
    }

    /* If we're here, no suitable free block was found. */
    
    // Out-of-Memory Check
    if((block_iter + total_needed) > system_heap.end)
    {
        return ((void*)0);
    }

    // Create the new block at the high-water mark
    malloc_t* new_alloc = (malloc_t*)block_iter;
    new_alloc->reserved = 1;
    new_alloc->size = sz;

    system_heap.used += total_needed;
    current_block_address = block_iter + total_needed; // Bump the high-water mark

    return((void*)block_iter + sizeof(malloc_t));
}

/* ... */
void free(void* b)
{
    if(!b) { return; }

    malloc_t* alloc = (malloc_t*)(b - sizeof(malloc_t));

    // Check for double-free
    if (alloc->reserved == 0) 
    {
        return; // This block is already free
    }

    // Mark as free and update heap usage
    alloc->reserved = 0;
    system_heap.used -= (alloc->size + sizeof(malloc_t));

    // Clear the memory.
    memset(b, 0, alloc->size);
    
    // Forward Coalesce. Check the block *after* this one
    uint32_t next_block_addr = (uint32_t)alloc + sizeof(malloc_t) + alloc->size;
    if (next_block_addr < current_block_address)
    {
        malloc_t* next_alloc = (malloc_t*)next_block_addr;
        if (next_alloc->reserved == 0)
        {
            // The next block is free, so merge it into the current one
            alloc->size += sizeof(malloc_t) + next_alloc->size;

            // Clear the old header
            memset(next_alloc, 0, sizeof(malloc_t));
        }
    }

    // Backward Coalesce. Find the block *before* this one
    uint32_t block_iter = system_heap.base;
    malloc_t* prev_alloc = NULL;
    
    while(block_iter < (uint32_t)alloc)
    {
        prev_alloc = (malloc_t*)block_iter;
        block_iter += prev_alloc->size + sizeof(malloc_t);
    }
    
    // 'prev_alloc' now points to the block right before 'alloc'
    if (prev_alloc != NULL && prev_alloc->reserved == 0)
    {
        // The previous block is free, so merge the current block into it
        prev_alloc->size += sizeof(malloc_t) + alloc->size;

        // Clear the old header
        memset(alloc, 0, sizeof(malloc_t));
        
        // The "current" block for the high-water-mark check is now 'prev_alloc'
        alloc = prev_alloc;
    }

    // Shrink High-Water Mark.
    // If we just freed the *last* block (or a merge created a new last block),
    // we can "shrink" the heap's high-water mark.
    if (((uint32_t)alloc + sizeof(malloc_t) + alloc->size) == current_block_address)
    {
        current_block_address = (uint32_t)alloc;
    }

    return;
}
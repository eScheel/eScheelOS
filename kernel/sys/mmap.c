#include <kernel.h>
#include <vga.h>

uint8_t main_memory_index;
memory_region_t memory_map[SMAP_entry_max];
memory_region_t available_memory_map[SMAP_entry_max];

/* ... */
void memory_map_init(uint16_t* mmap_desc_addr)
{
    main_memory_index = 0;

    // ...
    uint32_t available_memory_size = 0;
    size_t mmap_avail_entry_count = 0;

    // The first two bytes of the mmap are the size.
    size_t num_entries = (uint16_t)mmap_desc_addr[0];

    // Initialize the entry_array structure with the address of memory map form bios + size. 
    struct SMAP_entry* entry_array = (struct SMAP_entry*)(mmap_desc_addr + 2);
    for(size_t i=0; i<num_entries; i++)
    {
        struct SMAP_entry* entry = &entry_array[i];

        // If it's not available, let's just skip it.
        if(entry->type != 0x01) { continue; }

        // ...
        if(mmap_avail_entry_count < SMAP_entry_max)
        {
            // Let's fill in our global variable that kernel will use.
            memory_map[mmap_avail_entry_count].base_low = entry->base_addr_low;
            memory_map[mmap_avail_entry_count].base_high = entry->base_addr_high;
            memory_map[mmap_avail_entry_count].length_low = entry->length_low;
            memory_map[mmap_avail_entry_count].length_high = entry->length_high;
            mmap_avail_entry_count += 1;          
        }
    }

    // Loop through available memory regions.
    uint32_t largest_base_size = 0;
    for(size_t i=0; i<mmap_avail_entry_count; i++)
    {
        // Saving the index of the largest region to use for the heap or anything else that might need it.
        if(memory_map[i].length_low > largest_base_size)
        {
            largest_base_size = memory_map[i].length_low;
            main_memory_index = i;
        }

        // Let's fill in our global structure of available memory region addr and size.
        available_memory_map[i] = memory_map[i];
        available_memory_size  += (available_memory_map[i].length_low \
                               +   available_memory_map[i].length_high);

        // Now let's display available memory regions.
        memory_region_t mmap_region = available_memory_map[i];
        vga_printh(mmap_region.base_high);
        vga_printh(mmap_region.base_low);
        vga_prints(" : ");
        vga_printh(mmap_region.length_high);
        vga_printh(mmap_region.length_low);
        vga_printc('\n');
    }
    vga_prints("Total Memory: ");
    vga_printd(available_memory_size/(1024 * 1024));
    vga_prints("MB\n");

    return;
}
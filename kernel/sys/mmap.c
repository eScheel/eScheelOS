#include <kernel.h>
#include <io.h>

uint8_t main_memory_index;
memory_region_t available_memory_map[SMAP_entry_max];

static size_t mmap_avail_entry_count;
uint64_t total_memory_size;

//========================================================================================
/*
* Initializes the system memory map.
*
* This function takes the memory map provided by the BIOS.
* and parses it into the available_memory_map type structure.
*
* It also finds the largest usable memory block,
* and stores its index in main_memory_index for the heap and others to reference.
*/
void memory_map_init(mmap_descriptor_t* mmap_desc)
{
    main_memory_index = 0;
    mmap_avail_entry_count = 0;

    // Read the 32-bit entry count from the struct.
    size_t num_entries = mmap_desc->count;

    // Get the address of the first entry from the struct.
    struct SMAP_entry* entry_array = mmap_desc->entries;

    // Parse BIOS entries and fill our global available_memory_map
    for(size_t i=0; i<num_entries; i++)
    {
        struct SMAP_entry* entry = &entry_array[i];

        // If it's not available, skip it.
        if(entry->type != 0x01) { continue; }

        // Fill in the available_memory_map structure.
        if(mmap_avail_entry_count < SMAP_entry_max)
        {
            available_memory_map[mmap_avail_entry_count].base_low = entry->base_addr_low;
            available_memory_map[mmap_avail_entry_count].base_high = entry->base_addr_high;
            available_memory_map[mmap_avail_entry_count].length_low = entry->length_low;
            available_memory_map[mmap_avail_entry_count].length_high = entry->length_high;
            mmap_avail_entry_count += 1;          
        }
    }

    total_memory_size = 0;
    uint64_t largest_base_size = 0;

    // Find the largest block available.
    for(size_t i=0; i<mmap_avail_entry_count; i++)
    {
        // ...
        memory_region_t mmap_region = available_memory_map[i];

        // We deal with 64bit values from BIOS memory map.
        uint64_t region_size = ((uint64_t)mmap_region.length_high << 32) | mmap_region.length_low;

        // Is this region bigger than the biggest one so far?
        if(region_size > largest_base_size)
        {
            // Reset the biggest one so far to the bigger one.
            largest_base_size = region_size;
            main_memory_index = i;  // Save the index for others to use.
        }

        // Add it to our total memory size value.
        total_memory_size += region_size;
    }

    /** 
     * I've tried to extern kernel_offset from link.ld, but it does not seem to have the correct value.
     * Our boot loader will load the kernel at 0x100000 anyway ... So we test if main_memory_offset equals that.
     */
    if(available_memory_map[main_memory_index].base_low != KERNEL_PHYSICAL_BASE)
    {
        // We only acocunt for base_low here. I'm sure we should eventually account for base_high as well.
        kprintf("main_memory_offest(0x%x) != kernel_offset(0x100000)\n", available_memory_map[main_memory_index].base_low);
        mmap_display_available();

        // For now we just halt, eventually we will remap ...
        SYSTEM_HALT();
    }
}

//========================================================================================
/* Displays the available memory regions. */
void mmap_display_available()
{
    // Find the largest block for the heap and print all available regions.
    for(size_t i = 0; i < mmap_avail_entry_count; i++)
    {
        memory_region_t mmap_region = available_memory_map[i];

        kprintf("0x%x%x:0x%x%x\n", \
            mmap_region.base_high, mmap_region.base_low, mmap_region.length_high, mmap_region.length_low);
    }
}
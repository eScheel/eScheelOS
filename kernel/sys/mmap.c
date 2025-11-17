#include <kernel.h>
#include <vga.h>

uint8_t main_memory_index;
memory_region_t available_memory_map[SMAP_entry_max];

static size_t mmap_avail_entry_count;
uint64_t total_memory_size; // Use uint64_t for total memory calculation.

/*
* Initializes the system memory map.
*
* This function takes the memory map provided by the BIOS (via stage2.asm)
* and parses it into a clean, kernel-usable array ('available_memory_map').
*
* It also finds the largest usable memory block in the first 4GB
* and stores its index in 'main_memory_index' for the heap.
*/
void memory_map_init(mmap_descriptor_t* mmap_desc)
{
    main_memory_index = 0;
    mmap_avail_entry_count = 0;

    // Read the 32-bit entry count from the struct.
    size_t num_entries = mmap_desc->count;

    // Get the address of the first entry from the struct.
    struct SMAP_entry* entry_array = mmap_desc->entries;

    // Parse BIOS entries and fill our global 'available_memory_map'
    for(size_t i=0; i < num_entries; i++)
    {
        struct SMAP_entry* entry = &entry_array[i];

        // If it's not available (Type 1), skip it.
        if(entry->type != 0x01) { continue; }

        // ...
        if(mmap_avail_entry_count < SMAP_entry_max)
        {
            // Write directly into the 'available_memory_map'
            available_memory_map[mmap_avail_entry_count].base_low = entry->base_addr_low;
            available_memory_map[mmap_avail_entry_count].base_high = entry->base_addr_high;
            available_memory_map[mmap_avail_entry_count].length_low = entry->length_low;
            available_memory_map[mmap_avail_entry_count].length_high = entry->length_high;
            mmap_avail_entry_count += 1;          
        }
    }

    total_memory_size = 0;
    uint32_t largest_base_size = 0;

    // Find the largest block for the heap and print all available regions.
    for(size_t i = 0; i < mmap_avail_entry_count; i++)
    {
        memory_region_t mmap_region = available_memory_map[i];

        // Finds the largest memory block that is *entirely within the first 4GB* (base_high == 0 and length_high == 0), 
        if(mmap_region.base_high == 0 && mmap_region.length_high == 0)
        {
            if(mmap_region.length_low > largest_base_size)
            {
                largest_base_size = mmap_region.length_low;
                main_memory_index = i;
            }
        }

        // 64-bit arithmetic to calculate region size. (high_bits << 32) | low_bits
        uint64_t region_size = ((uint64_t)mmap_region.length_high << 32) | mmap_region.length_low;
        total_memory_size += region_size;
    }

    /* 
     * I've tried to extern kernel_offset from link.ld, but it does not seem to have the correct value.
     * Our boot loader will load the kernel at 0x100000 anyway ... So we test if main_memory_offset equals.
     */
    if(available_memory_map[main_memory_index].base_low != KERNEL_PHYSICAL_BASE)
    {
        vga_prints("\nmain_memory_offest(0x");
        vga_printh(available_memory_map[main_memory_index].base_low);
        vga_prints(") != kernel_offset(0x100000)\n");

        // For now we just halt, eventually we will remap ...
        SYSTEM_HALT();
    }
}

void mmap_display_available()
{
    // Find the largest block for the heap and print all available regions.
    for(size_t i = 0; i < mmap_avail_entry_count; i++)
    {
        memory_region_t mmap_region = available_memory_map[i];

        // Now let's display available memory regions.
        vga_printh(mmap_region.base_high);
        vga_printh(mmap_region.base_low);
        vga_prints(":");
        vga_printh(mmap_region.length_high);
        vga_printh(mmap_region.length_low);
        vga_printc('\n');
    }
}
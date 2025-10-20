/* ... */
void display_memory_map(uint16_t* mmap_desc_addr)
{
    vga_prints("MMAP_ENTRIES: \0");
    size_t num_entries = (uint16_t)mmap_desc_addr[0];
    vga_printh(num_entries);
    vga_printc('\n');

    // ...
    struct SMAP_entry* entry_array = (struct SMAP_entry*)(mmap_desc_addr + 2);
    for(size_t i=0; i<num_entries; i++)
    {
        struct SMAP_entry* entry = &entry_array[i];
        if(entry->type != 0x01) { continue; }

        vga_printh(entry->base_addr_high);
        vga_printh(entry->base_addr_low);
        vga_printc('|');

        vga_printh(entry->length_high);
        vga_printh(entry->length_low);
        vga_printc('|');

        vga_printh(entry->type);
        vga_printc('\n');
    }
}





uint32_t available_memory = 0;
size_t biggest_region_index = 0;



    uint32_t biggest_region = 0;
    for(size_t i=0; i<mmap_avail_entry_count; i++)
    {
        memory_region_t mmap_region = memory_map[i];

        vga_printh(mmap_region.base);
        vga_prints("  :  ");
        vga_printd(mmap_region.length);
        vga_printc('\n');

        uint32_t region_size = mmap_region.length;
        if(region_size > biggest_region)
        {
            biggest_region = region_size;
            biggest_region_index = i+1;
        }
        available_memory += mmap_region.length;
    }

    vga_prints("Total Memory: \0");
    vga_printd(available_memory/1048576);
    vga_prints("MB between \0");
    vga_printd(mmap_avail_entry_count);
    vga_prints(" regions and the biggest region being \0");
    vga_printd(biggest_region_index);
    vga_printc('\n');
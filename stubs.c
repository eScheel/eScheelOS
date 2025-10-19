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
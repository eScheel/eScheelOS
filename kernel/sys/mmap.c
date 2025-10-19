#include <stddef.h>
#include <stdint.h>

extern void vga_printc(char c);
extern void vga_prints(const char* data);
extern void vga_printh(uint32_t h);

#define SMAP_entry_max 16
struct SMAP_entry {
    uint32_t base_addr_low;     // Base Address (64-bit)
    uint32_t base_addr_high;    // Base Address (64-bit)
    uint32_t length_low;        // Length (64-bit)
    uint32_t length_high;       // Length (64-bit)
    uint32_t type;              // Type of memory region (32-bit)
    uint32_t acpi;              // ACPI 3.0 Extended Attributes
}__attribute__((packed));

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

#include <kernel.h>

extern void memset(void* data, uint8_t c, size_t n);

#define SMAP_entry_max 32
struct SMAP_entry {
    uint32_t base_addr_low;     // Base Address (64-bit)
    uint32_t base_addr_high;    // Base Address (64-bit)
    uint32_t length_low;        // Length (64-bit)
    uint32_t length_high;       // Length (64-bit)
    uint32_t type;              // Type of memory region (32-bit)
    uint32_t acpi;              // ACPI 3.0 Extended Attributes
}__attribute__((packed));

/* ... */
void memory_map_init(uint16_t* mmap_desc_addr)
{
    size_t num_entries = (uint16_t)mmap_desc_addr[0];

    // ...
    struct SMAP_entry* entry_array = (struct SMAP_entry*)(mmap_desc_addr + 2);
    for(size_t i=0; i<num_entries; i++)
    {
        struct SMAP_entry* entry = &entry_array[i];

        if(entry->type != 0x01) { continue; }

        // TODO: Save addr and length here ...
    }

    return;
}

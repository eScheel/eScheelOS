#include <kernel.h>

#define SMAP_entry_max 32
struct SMAP_entry {
    uint32_t base_addr_low;     // Base Address (64-bit)
    uint32_t base_addr_high;    // Base Address (64-bit)
    uint32_t length_low;        // Length (64-bit)
    uint32_t length_high;       // Length (64-bit)
    uint32_t type;              // Type of memory region (32-bit)
    uint32_t acpi;              // ACPI 3.0 Extended Attributes
}__attribute__((packed));

typedef struct {
    uint64_t base;
    uint64_t length;
}memory_region_t;

size_t mmap_avail_entry_count = 0;
memory_region_t memory_map[SMAP_entry_max];
uint32_t available_memory_size = 0;
memory_region_t available_memory_map[SMAP_entry_max];

/* ... */
void memory_map_init(uint16_t* mmap_desc_addr)
{
    size_t num_entries = (uint16_t)mmap_desc_addr[0];

    // ...
    struct SMAP_entry* entry_array = (struct SMAP_entry*)(mmap_desc_addr + 2);
    for(size_t i=0; i<num_entries; i++)
    {
        struct SMAP_entry* entry = &entry_array[i];

        // If it's not available, let's just skip it.
        if(entry->type != 0x01) { continue; }

        uint64_t base   = ((uint64_t)entry->base_addr_high << 32) | entry->base_addr_low;
        uint64_t length = ((uint64_t)entry->length_high << 32)    | entry->length_low;

        if(mmap_avail_entry_count < SMAP_entry_max)
        {
            memory_map[mmap_avail_entry_count].base = base;
            memory_map[mmap_avail_entry_count].length = length;
            mmap_avail_entry_count += 1;          
        }
        
    }

    // Let's fill in our structure of available memory region addr and size.
    for(size_t i=0; i<mmap_avail_entry_count; i++)
    {
        available_memory_map[i] = memory_map[i];
        available_memory_size += available_memory_map[i].length;
    }

    return;
}
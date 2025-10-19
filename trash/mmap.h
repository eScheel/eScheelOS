#ifndef __MMAP_H

#define SMAP_entry_max 32
struct SMAP_entry {
    uint32_t base_addr_low;     // Base Address (64-bit)
    uint32_t base_addr_high;    // Base Address (64-bit)
    uint32_t length_low;        // Length (64-bit)
    uint32_t length_high;       // Length (64-bit)
    uint32_t type;              // Type of memory region (32-bit)
    uint32_t acpi;              // ACPI 3.0 Extended Attributes
}__attribute__((packed));

uint32_t usable_offsets[SMAP_entry_max];
size_t usable_offset_lengths[SMAP_entry_max];

#endif // __MMAP_H
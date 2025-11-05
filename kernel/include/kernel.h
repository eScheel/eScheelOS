#ifndef __KERNEL_H
#define __KERNEL_H

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

// MMAP.C
#define SMAP_entry_max 32
struct SMAP_entry {
    uint32_t base_addr_low;
    uint32_t base_addr_high;
    uint32_t length_low;
    uint32_t length_high;
    uint32_t type;
    uint32_t acpi;              // ACPI 3.0 Extended Attributes
}__attribute__((packed));

typedef struct {
    uint32_t base_low;
    uint32_t base_high;
    uint32_t length_low;
    uint32_t length_high;
}memory_region_t;

extern uint8_t main_memory_index;
extern memory_region_t available_memory_map[];

typedef struct {
    uint32_t count;
    struct SMAP_entry entries[SMAP_entry_max];
}__attribute__((packed)) mmap_descriptor_t;

// KERNEL.ASM
extern void KERNEL_IDLE();
extern void SYSTEM_HALT();

// IO.ASM
extern uint8_t INB(uint8_t);
extern void   OUTB(uint16_t, uint8_t);

#endif // __KERNEL_H
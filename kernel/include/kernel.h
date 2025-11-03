#ifndef __KERNEL_H
#define __KERNEL_H

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

// MMAP.C
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
    uint32_t base_low;
    uint32_t base_high;
    uint32_t length_low;
    uint32_t length_high;
}memory_region_t;

// HEAP.C
void heap_init(uint32_t base_addr, uint32_t length);

// KERNEL.ASM
extern void SYSTEM_HALT();

// IO.ASM
extern uint8_t INB(uint8_t);
extern void   OUTB(uint16_t, uint8_t);

#endif // __KERNEL_H
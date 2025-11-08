#ifndef __KERNEL_H
#define __KERNEL_H

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

// MMAP.C ==============================================================
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

// HEAP.C ==============================================================
struct HEAP_info {
    uint32_t base;
    uint32_t size;
    uint32_t used;
    uint32_t end;
}__attribute__((packed));

void print_heap_info();

void* malloc(size_t sz);
void  free(void* b);

// PAGING.C ============================================================
#define PAGE_SIZE 4096

// Page Directory Entry (PDE) Flags.
#define PDE_PRESENT     0x01    // 1 = Page table is present
#define PDE_READ_WRITE  0x02    // 1 = Read/Write, 0 = Read-only
#define PDE_USER        0x04    // 1 = User-mode, 0 = Supervisor-mode
#define PDE_4MB_PAGE    0x80    // 1 = Page is 4MB, 0 = Page is 4KB

// Page Table Entry (PTE) Flags.
#define PTE_PRESENT     0x01    // 1 = Page is present
#define PTE_READ_WRITE  0x02    // 1 = Read/Write, 0 = Read-only
#define PTE_USER        0x04    // 1 = User-mode, 0 = Supervisor-mode

/*
 * The reason we use 0xC0000000 by convention is to create a "Higher-Half Kernel." 
 * This reserves the entire "lower half" of the virtual address space (from 0x0 to 0xBFFFFFFF) for future user-mode programs,
 * preventing their addresses from ever colliding with the kernel's.
 */
#define KERNEL_VIRTUAL_BASE  0x00100000
#define KERNEL_PHYSICAL_BASE 0x00100000     // As defined in link.ld

// KERNEL.ASM =========================================================
extern void KERNEL_IDLE();
extern void SYSTEM_HALT();

// IO.ASM =============================================================
extern uint8_t INB(uint8_t);
extern void   OUTB(uint16_t, uint8_t);

#endif // __KERNEL_H
#include <kernel.h>

#define ENTRY_COUNT	3

// 64-bit GDT Entry Structure.
struct gdt_entry
{
    uint16_t limit_low;	
    uint16_t base_low;	
    uint8_t  base_middle;		
    uint8_t  access;	    // Access flags, what DPL this segment uses.
    uint8_t  granularity;	// Granularity Byte. ( 0 = 1B | 1 = 4KB )
    uint8_t  base_high;     // This must come last in this structure.
}__attribute__((packed));

// 48-bit GDT Pointer Structure.
struct gdt_ptr
{
    uint16_t limit;
    uint32_t base;
}__attribute__((packed));

extern struct gdt_ptr GDT_DESC;
struct gdt_entry gentry[ENTRY_COUNT];

/* Setup a descriptor in the GDT. */
static void gdt_set_gate(int index, uint32_t base, uint32_t limit, uint8_t access, uint8_t granularity)
{
    gentry[index].limit_low    = (limit & 0xffff);
    gentry[index].base_low     = (base & 0xffff);
    gentry[index].base_middle  = (base >> 16) & 0xff;
    gentry[index].base_high    = (base >> 24) & 0xff;
    gentry[index].access       = (access);
    gentry[index].granularity  = (limit >> 16) & 0x0f;
    gentry[index].granularity |= (granularity & 0xf0);
}

/* Initialize the global descriptor table. */
void gdt_init()
{
    GDT_DESC.limit = (sizeof(struct gdt_entry) * ENTRY_COUNT) - 1;
    GDT_DESC.base  = (uint32_t)&gentry;

    gdt_set_gate(0, 0x00000000, 0x00000000, 0x00, 0x00); // Null Segment.
    gdt_set_gate(1, 0x00000000, 0xffffffff, 0x9a, 0xcf); // Kernel Code.
    gdt_set_gate(2, 0x00000000, 0xffffffff, 0x92, 0xcf); // Kernel Data.
}
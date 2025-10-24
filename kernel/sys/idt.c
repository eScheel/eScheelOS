#include <kernel.h>

extern void memset(void*, uint8_t, size_t);

// IDT only has a max of 256 entries.
#define MAX_ENTRIES 256

// IDT entry structure
struct idt_entry
{
    uint16_t base_low;
    uint16_t selector;	// Kernel segment selector.
    uint8_t  zero;	    // Always zero
    uint8_t  flags;	    // Access flags.
    uint16_t base_high;  	
}__attribute__((packed));

struct idt_ptr
{
    uint16_t limit;	// The upper 16 bits of the segment selector
    uint32_t base;	// Address of the ISR the CPU should call
}__attribute__((packed));

extern struct idt_ptr IDT_DESC;
struct idt_entry ientry[MAX_ENTRIES];

/* Used to set an entry in the IDT. */
void idt_set_gate(uint8_t index, uint32_t base, uint16_t selector, uint8_t flags)
{
    ientry[index].base_low  = (base & 0xffff);
    ientry[index].selector  = (selector);
    ientry[index].zero      = (0x00);
    ientry[index].flags     = (flags);
    ientry[index].base_high = ((base >> 16) & 0xffff);
}

/* ... */
void idt_init()
{
    IDT_DESC.limit = (((sizeof(struct idt_entry) * MAX_ENTRIES)) - 1);
    IDT_DESC.base  = (uint32_t)ientry;

//    memset(ientry, 0, (sizeof(struct idt_entry) * MAX_ENTRIES));

//    isr_init();
//    irq_init();

//    load_interrupts((uint32_t)&IDT_DESC);
    return; 
}
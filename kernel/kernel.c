#include <kernel.h>
#include <vga.h>

extern uint8_t main_memory_index;
extern memory_region_t available_memory_map[SMAP_entry_max];
extern void heap_init(uint32_t base_addr, uint32_t length);

void kernel_main(uint8_t boot_drive)
{
    // Initialize the heap with the largest block of available memory.
    const size_t i = main_memory_index;
    heap_init(available_memory_map[i].base_low, \
              available_memory_map[i].length_low);

    // ...
    vga_prints("BOOT_DRIVE: ");
    vga_printd(boot_drive);
    vga_printc('\n');

    // ...
    asm volatile("sti");
    for(;;){ continue; }
}

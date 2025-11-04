#include <kernel.h>
#include <vga.h>
#include <pit.h>
#include <heap.h>
#include <string.h>

extern uint8_t main_memory_index;
extern memory_region_t available_memory_map[SMAP_entry_max];

extern volatile uint32_t uptime_seconds;

void kernel_main(uint8_t boot_drive)
{
    // Initialize the heap with the largest block of available memory.
    // For now we only use lower values assuming 32 bit system.
    const size_t i = main_memory_index;
    heap_init(available_memory_map[i].base_low, \
              available_memory_map[i].length_low);
    print_heap_info();

    // ...
    vga_prints("BOOT_DRIVE: ");
    vga_printd(boot_drive);
    vga_printc('\n');

    // ...
    asm volatile("sti");
    for(;;)
    {
        //vga_printd(uptime_seconds);
        //timer_wait(1);
        continue; 
    }
}

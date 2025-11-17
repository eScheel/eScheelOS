#include <kernel.h>
#include <vga.h>
#include <pit.h>
#include <ide.h>
#include <task.h>
#include <string.h>
#include <convert.h>

extern void kshell();

/* ... */
void kernel_main()
{
    kprintf("Initialization complete! Main task started.\n");

    // Invoke the shell to begin with for now.
    kprintf("Attempting to start the kernel shell ... ");
    if(create_task(kshell) != 0)
    {
        kprintf("Failed to start the kernel shell.\n");
    }
    kprintf("[OK]");

    // ...
    while(1) 
    { 
        for(int x=0; x<VGA_WIDTH; x++)
        {
            vga_putc(255, x, 0);
            timer_wait(10);
        }
        asm volatile("hlt"); 
    }
}

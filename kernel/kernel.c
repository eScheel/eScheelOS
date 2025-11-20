#include <kernel.h>
#include <vga.h>
#include <keyboard.h>
#include <pit.h>
#include <ide.h>
#include <string.h>
#include <convert.h>

extern void kshell();

/* ... */
void kernel_main()
{
    kprintf("Initialization complete! Main task started.\n");

    // Invoke the shell to begin with for now.
    kprintf("Attempting to start the kernel shell task ... ");
    if(task_exec(kshell) != 0)
    {
        kprintf("Failed to start the kernel shell.\n");
    }
    kprintf("[OK]");

    // ...
    while(1) 
    { 

        asm volatile("hlt"); 
    }
}

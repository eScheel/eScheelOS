#include <kernel.h>
#include <vga.h>
#include <keyboard.h>
#include <pit.h>
#include <ide.h>
#include <fat32.h>
#include <string.h>
#include <convert.h>

extern void kshell();

/* ... */
void kernel_main()
{
    kprintf("Initialization complete! Main task started.\n"); 

    // ...
    kprintf("Attempting to start the kernel shell task ... ");
    if(task_exec(kshell, "kshell") != 0)
    {
        kprintf("Failed to start the kernel shell.\n");
        goto kernel_idle;
    }
    kprintf("[OK]");

    // ...
kernel_idle:
    while(1)
    {
        asm volatile("hlt");
    }
}

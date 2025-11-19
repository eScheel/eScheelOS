#include <kernel.h>
#include <vga.h>
#include <keyboard.h>
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
    kprintf("Attempting to start the kernel shell task ... ");
    if(task_exec(kshell) != 0)
    {
        kprintf("Failed to start the kernel shell.\n");
    }
    kprintf("[OK]");

    /*
    uint8_t *temp = (uint8_t*)malloc(51200);
    memset(temp, 0, 51200);
    ide_read_sectors(0, 0, 100, temp);
    timer_wait(1);
    ide_write_sectors(1, 0, 100, temp);
    free(temp);
    */

    // ...
    while(1) 
    { 

        asm volatile("hlt"); 
    }
}

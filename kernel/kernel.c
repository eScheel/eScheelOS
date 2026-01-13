#include <kernel.h>
#include <vga.h>
#include <keyboard.h>
#include <pit.h>
#include <ide.h>
#include <fat32.h>
#include <io.h>
#include <string.h>
#include <convert.h>

extern void kshell();
extern uint8_t kshell_activated;

//========================================================================================
/* ... */
void kernel_task()
{
    kshell_activated = 0;
    kprintf("Initialization complete!\nPress the F12 key to start the kernel shell.");
    while(1)
    {
        // Was the f12 key pressed?
        if(f12_pressed)
        {
            f12_pressed = 0;
            // Is the kernel shell already active?
            if(!kshell_activated)
            {
                task_exec(kshell, "kshell");
            }
        }

        // Do some cleaning.
        reaper();

        // Sleep for a bit.
        asm volatile("hlt");
    }
}

#include <kernel.h>
#include <vga.h>
#include <pit.h>
#include <ide.h>
#include <string.h>

/* ... */
static void kernel_shell()
{
    kprintf("\n++++ Kernel Shell Invoked. ++++\n");

    char* s = (char*)malloc(1024);
    for(;1;)
    {
        memset(s, 0, 1024);
    
        kprintf("\nksh> ");
        kgets(s);

        // If command is not empty, process it.
        if(*s)  {
            if(strncmp(s, "help", strlen(s))==0)
            {
                kprintf("\nPossible Commands:");
                kprintf("\n  clear    (Clears the console screen)");
                kprintf("\n  heapstat (Prints current heap information.)");
                kprintf("\n  uptime   (Prints system uptime as dd:hh:mm:ss)");
                kprintf("\n  exit     (Exits the kernel shell.)");
            }

            else if(strncmp(s, "clear", strlen(s))==0)
            {
                vga_clear();
            }

            else if(strncmp(s, "heapstat", strlen(s))==0)
            {
                kprintf("\n\n");
                print_heap_info();
            }

            else if(strncmp(s, "uptime", strlen(s))==0)
            {
                kprintf("\nSystem Uptime: %d:%d:%d:%d", system_uptime_days, system_uptime_hours, \
                                                        system_uptime_minutes, system_uptime_seconds);
            }

            else if(strncmp(s, "exit", strlen(s))==0)
            {
                break;
            }

            else
            {
                kprintf("\nUnknown Command [%s]", s);
            }
        }
    }

    kprintf("\nExiting ... ");
    free(s);
    kprintf("[OK]\n");
}

/* ... */
void kernel_main(void)
{
    kernel_shell();
    while(1) { asm volatile("hlt"); }
}

#include <kernel.h>
#include <vga.h>
#include <pit.h>
#include <pci.h>
#include <ide.h>
#include <task.h>
#include <string.h>
#include <convert.h>

/* ... */
void kshell()
{
    kprintf("\n\n++++ Kernel Shell v1.0 ++++\n");

    char* s = (char*)malloc(1024);
    vga_enable_cursor();

    while(1)
    {
        memset(s, 0, 1024);
    
        kprintf("\nksh> ");
        vga_update_cursor();
        kgets(s);

        // If command is not empty, process it.
        if(*s)  {
            if(strncmp(s, "help", strlen(s))==0)
            {
                kprintf("\nPossible Commands:");
                kprintf("\n  clear    (Clears the console screen)");
                kprintf("\n  heapstat (Prints current heap information.)");
                kprintf("\n  memmap   (Displays the regions of available memory.)");
                kprintf("\n  pciconf  (...)");
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

            else if(strncmp(s, "memmap", strlen(s))==0)
            {
                kprintf("\n\n");
                mmap_display_available();
            }

            else if(strncmp(s, "pciconf", strlen(s))==0)
            {
                kprintf("\n\n");
                pci_conf_display();
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

    vga_disable_cursor();
    free(s);
    task_kill();
}
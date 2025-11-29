#include <kernel.h>
#include <vga.h>
#include <pit.h>
#include <pci.h>
#include <ide.h>
#include <fat32.h>
#include <elf32.h>
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
        if(*s) {
            if(strncmp(s, "help", strlen(s))==0)
            {
                kprintf("\nPossible Commands:");
                kprintf("\n  clear    (Clears the console screen)");
                kprintf("\n  ls       (List the contents of the root directory.)");
                kprintf("\n  heapstat (Prints current heap information.)");
                kprintf("\n  memmap   (Displays the regions of available memory.)");
                kprintf("\n  pciconf  (List devices captured on the pci bus.)");
                kprintf("\n  tasklist (Displays a list of currently running tasks.)");
                kprintf("\n  reap     (Reaps any killed tasks so they can be reused again.)");
                kprintf("\n  exit     (Exits the kernel shell.)");
            }

            else if(strncmp(s, "clear", strlen(s))==0 \
                 || strncmp(s, "cls",   strlen(s))==0)
            {
                vga_clear();
            }

            else if(strncmp(s, "dir", strlen(s))==0 \
                 || strncmp(s, "ls",  strlen(s))==0)
            {
                kprintf("\n");
                fat32_ls();
            }

            else if(strncmp(s, "heapstat", strlen(s))==0)
            {
                kprintf("\n");
                print_heap_info();
            }

            else if(strncmp(s, "memmap", strlen(s))==0)
            {
                kprintf("\n");
                mmap_display_available();
            }

            else if(strncmp(s, "pciconf", strlen(s))==0)
            {
                kprintf("\n");
                pci_conf_display();
            }

            else if(strncmp(s, "tasklist", strlen(s))==0)
            {
                kprintf("\n");
                task_list();
            }

            else if(strncmp(s, "reap", strlen(s))==0)
            {
                kprintf("\n");
                reaper();
            }

            else if(strncmp(s, "exec", strlen(s))==0)
            {
                file_t* fp = fat32_open("TEST");
                uint32_t offset = elf32_parse_and_relocate(fp->base);
                if(offset != 0xffffffff)
                {
                    task_exec((void* )offset, "test");
                }
                free(fp);
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
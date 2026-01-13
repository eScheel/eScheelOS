#include <kernel.h>
#include <vga.h>
#include <pit.h>
#include <pci.h>
#include <fat32.h>
#include <elf32.h>
#include <io.h>
#include <string.h>
#include <convert.h>

uint8_t kshell_activated;

/* ... */
void kshell()
{
    char* s = (char*)malloc(1024);
    vga_enable_cursor();

    kshell_activated = 1;
    while(1)
    {
        memset(s, 0, 1024);
        kprintf("\n/>");
        vga_update_cursor();
        kgets(s);

        // If command is not empty, process it.
        if(*s) 
        {
            if((strncmp(s, "help", strlen(s))==0 && strlen(s) == 4) \
            || (strncmp(s, "?",    strlen(s))==0 && strlen(s) == 1))
            {
                kprintf("\nPossible Commands:");
                kprintf("\n  clear    (Clears the console screen)");
                kprintf("\n  ls       (List the contents of the root directory.)");
                kprintf("\n  read     (Display the contents of a file.)");
                kprintf("\n  heapstat (Prints current heap information.)");
                kprintf("\n  memmap   (Displays the regions of available memory.)");
                kprintf("\n  pciconf  (List devices captured on the pci bus.)");
                kprintf("\n  tasklist (Displays a list of currently running tasks.)");
                kprintf("\n  exit     (Exits the kernel shell.)");
            }

            else if((strncmp(s, "clear", strlen(s))==0 && strlen(s) == 5) \
                 || (strncmp(s, "cls",   strlen(s))==0 && strlen(s) == 3))
            {
                vga_clear();
            }

            else if(strncmp(s, "ls",  strlen(s))==0 && strlen(s) == 2)
            {
                kprintf("\n");
                fat32_ls();
            }

            else if(strncmp(s, "read", strlen("read"))==0)
            {
                kprintf("\n");

                // Allocate a buffer for the file name.
                char* file_name = (char* )malloc(strlen(s));
                memset(file_name, 0, strlen(s));

                // Fill in the allocated file name.
                for(unsigned int i=0,n=5; n<strlen(s); i++,n++)
                {
                    file_name[i] = s[n];
                }

                // Read the file into memory.
                file_t* fp = fat32_read(file_name);
                if(fp)
                {
                    // Display the contents of the file to screen.
                    for(unsigned int i=0; i<fp->size; i++)
                    {
                        kprintf("%c", fp->data[i]);
                        task_sleep(1);
                    }
                    free(fp);
                }
                else 
                {
                    kprintf("No such file [%s]\n", file_name);
                }
                free(file_name);
            }

            else if(strncmp(s, "heapstat", strlen(s))==0 && strlen(s) == 8)
            {
                kprintf("\n");
                print_heap_info();
            }

            else if(strncmp(s, "memmap", strlen(s))==0 && strlen(s) == 6)
            {
                kprintf("\n");
                mmap_display_available();
            }

            else if(strncmp(s, "pciconf", strlen(s))==0 && strlen(s) == 7)
            {
                kprintf("\n");
                pci_conf_display();
            }

            else if((strncmp(s, "tasklist", strlen(s))==0 && strlen(s) == 8) \
                 || (strncmp(s, "ps",       strlen(s))==0 && strlen(s) == 2))
            {
                kprintf("\n");
                task_list();
            }

            else if(strncmp(s, "exit", strlen(s))==0 && strlen(s) == 4)
            {
                break;
            }

            else 
            {
                kprintf("\nUnknown Command [%s]", s);
            }
        }
    }
    kshell_activated = 0;

    vga_disable_cursor();
    free(s);
    task_kill();
}
#include <kernel.h>
#include <vga.h>
#include <pit.h>
#include <ide.h>
#include <task.h>
#include <string.h>
#include <convert.h>

extern void kshell();

void draw_logo()
{
    uint8_t line0[27] = { 255,255,255,255,255,' ',' ',255,255,255,255,255,' ',' ',' ',255,255,255,255,' ',' ',' ',255,255,255,255,255 };
    uint8_t line1[27] = { 255,255,' ',' ',' ',' ',' ',255,255,' ',' ',' ',' ',' ',255,255,' ',' ',255,255,' ',' ',255,255,' ',' ',' ' };
    uint8_t line2[27] = { 255,255,255,255,255,' ',' ',255,255,255,255,255,' ',' ',255,255,' ',' ',255,255,' ',' ',255,255,255,255,255 };
    uint8_t line3[27] = { 255,255,' ',' ',' ',' ',' ',' ',' ',' ',255,255,' ',' ',255,255,' ',' ',255,255,' ',' ',' ',' ',' ',255,255 };
    uint8_t line4[27] = { 255,255,255,255,255,' ',' ',255,255,255,255,255,' ',' ',' ',255,255,255,255,' ',' ',' ',255,255,255,255,255 };

    for(int x=40,y=3,i=0; x<67; x++,i++)
    {
        vga_putc(line0[i], x, y);
    }

    for(int x=40,y=4,i=0; x<67; x++,i++)
    {
        vga_putc(line1[i], x, y);
    }

    for(int x=40,y=5,i=0; x<67; x++,i++)
    {
        vga_putc(line2[i], x, y);
    }

    for(int x=40,y=6,i=0; x<67; x++,i++)
    {
        vga_putc(line3[i], x, y);
    }

    for(int x=40,y=7,i=0; x<67; x++,i++)
    {
        vga_putc(line4[i], x, y);
    }

}

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

        asm volatile("hlt"); 
    }
}

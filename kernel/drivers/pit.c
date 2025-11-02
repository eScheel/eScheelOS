#include <kernel.h>
#include <vga.h>

volatile uint32_t timer_ticks = 0;

uint32_t uptime_seconds = 0;
uint32_t uptime_minutes = 0;
uint32_t uptime_hours = 0;

extern void vga_update_hud();

void timer_init()
{
    int divisor = 1193180 / 100;   /* Calculate our divisor */
    OUTB(0x43, 0x36);              /* Set our command byte 0x36 */
    OUTB(0x40, divisor & 0xFF);    /* Set low byte of divisor */
    OUTB(0x40, divisor >> 8);      /* Set high byte of divisor */    
}

void timer_interrupt_handler()
{
    timer_ticks += 1;

    // ...
    if(timer_ticks % 60 == 0)
    {
        uptime_seconds += 1;
        if(uptime_seconds == 60)
        {
            uptime_seconds = 0;
            uptime_minutes += 1;
            if(uptime_minutes == 60)
            {
                uptime_minutes = 0;
                uptime_hours += 1;
                if(uptime_hours == 24)
                {
                    uptime_hours = 0;
                    // TODO: uptime_days.
                }
            }
        }
        vga_update_hud();
    }
}
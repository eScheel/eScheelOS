#include <kernel.h>
#include <pit.h>

extern uint32_t schedule(uint32_t);

static volatile uint32_t timer_ticks;
static volatile size_t timer_counter;

//========================================================================================
/* Initialize the pit with 100hz and square wave continous interrupts. */
void timer_init()
{
    timer_ticks = 0;
    timer_counter = 0;

    // 1,193,180 (ticks/sec) / 100 (interrupts/sec) = 11931 (ticks/interrupt)
    int divisor = 1193180 / 100;   // Calculate our divisor

    // The value 0x36 is 00110110 in binary, and each set of bits is a command:
    // 00: Select Channel 0. The PIT has three channels. Channel 0 is the one hardwired to IRQ 0, the system timer.
    // 11: Set Access Mode to "Lobyte/Hibyte". This tells the PIT that you're about to send a 16-bit divisor in two 8-bit pieces: the Low Byte first, then the High Byte.
    // 011: Set Operating Mode to "Mode 3 (Square Wave Generator)". This makes the PIT generate a continuous train of interrupts (a "square wave") at the frequency you set.
    // 0: Use 16-bit Binary mode (not BCD, which is an older format).
    OUTB(0x43, 0x36);               // Set our command byte 0x36

    // 0x40: This is the data port for Channel 0.
    OUTB(0x40, divisor & 0xFF);     // Set low byte of divisor
    OUTB(0x40, divisor >> 8);       // Set high byte of divisor
}

//========================================================================================
/* ... */
uint32_t timer_interrupt_handler(uint32_t current_esp)
{
    // Each tick is 10 milliseconds. (.01 seconds)
    // 10 ticks is 100 milliseconds. (.10 seconds)
    // 100 ticks is 1 second.
    timer_ticks++;

    // Handle timer_wait counter.
    if(timer_counter > 0) {
        timer_counter--;
    }

    // Handle the ticks for any specific sleeping task.
    task_tick();

    // Call the scheduler and return the (potentially new) stack pointer
    return(schedule(current_esp));
}

//========================================================================================
/* Returns the current system uptime in ticks (10ms resolution) */
uint32_t timer_get_ticks()
{
    return(timer_ticks);
}

//========================================================================================
/* 
 * Blocks the whole cpu.
 * Wait for specified amount of time. 
 * A value of 100 is a second. 
 */
void timer_wait(uint32_t tc)
{
    asm volatile("cli");
    timer_counter = tc;
    asm volatile("sti");
    while(timer_counter) 
    { 
        asm volatile("hlt");
    }
}
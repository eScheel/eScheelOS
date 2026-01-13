#include <kernel.h>
#include <io.h>
#include <string.h>

// The table of all tasks in the system
static struct task task_table[MAX_TASKS];

// The index of the currently running task in the task_table
static volatile uint32_t current_task;

// Flag to prevent scheduling before tasking is initialized
volatile uint8_t tasking_enabled;

//========================================================================================
/* Initializes the multi-tasking system. */
void tasking_init()
{
    // Clear the task table with all 0's.
    memset(task_table, 0, sizeof(struct task)*MAX_TASKS);

    // Initialize Task 0.
    const char* name = "kernel_main";
    current_task = 0;
    task_table[current_task].state = TASK_STATE_RUNNING;
    task_table[current_task].esp = 0;
    task_table[current_task].stack_base = 0;
    for(int i=0; i<12; i++)
    {
        task_table[current_task].name[i] = name[i];
    }

    // Enable the scheduler
    tasking_enabled = 1;
}

//========================================================================================
/* Creates a new task and adds it to the task table. */
int task_exec(void (*task_function)(void), const char* name)
{
    asm volatile("cli");
    int task_index = -1;

    for(int i=0; i<MAX_TASKS; i++)
    {
        if(strncmp(name, task_table[i].name, strlen(name))==0)
        {
            asm volatile("sti");
            return(task_index);
        }
    }

    // Find a free task slot
    for(int i=0; i<MAX_TASKS; i++)
    {
        if (task_table[i].state == TASK_STATE_FREE)
        {
            task_index = i;
            break;
        }
    }

    // No free slots
    if(task_index == -1) 
    {
        asm volatile("sti");
        return(task_index);
    }

    // Allocate a stack for the task.
    uint8_t* stack = (uint8_t*)malloc(STACK_SIZE);
    if(!stack) 
    {
        asm volatile("sti");
        return(-1); // Malloc failed
    }
    uint32_t stack_top = (uint32_t)(stack + STACK_SIZE);

    // Preload the stack.
    uint32_t* stack_ptr = (uint32_t*)stack_top;
    *--stack_ptr = 0x202;   // EFLAGS (Interrupts Enabled)
    *--stack_ptr = 0x08;    // CODE_SEG
    *--stack_ptr = (uint32_t)task_function; // EIP
    *--stack_ptr = 0; // EAX
    *--stack_ptr = 0; // ECX
    *--stack_ptr = 0; // EDX
    *--stack_ptr = 0; // EBX
    *--stack_ptr = 0; // ESP (dummy)
    *--stack_ptr = 0; // EBP
    *--stack_ptr = 0; // ESI
    *--stack_ptr = 0; // EDI

    // Save the new task's state
    task_table[task_index].esp = (uint32_t)stack_ptr;
    task_table[task_index].stack_base = (uint32_t)stack;
    task_table[task_index].state = TASK_STATE_RUNNING; // Set as running
    for(int i=0; name[i]!=0; i++)
    {
        task_table[task_index].name[i] = name[i];
    }

    asm volatile("sti");
    return(0); // Success
}

//========================================================================================
/* Called by the timer interrupt handler every tick */
void task_tick()
{
    for(int i=0; i<MAX_TASKS; i++)
    {
        if(task_table[i].state == TASK_STATE_SLEEPING)
        {
            // Decrement the timer
            if(task_table[i].sleep_ticks > 0) {
                task_table[i].sleep_ticks--;
            }

            // If timer runs out, wake the task up
            if(task_table[i].sleep_ticks == 0) {
                task_table[i].state = TASK_STATE_RUNNING;
            }
        }
    }
}

//========================================================================================
/* Puts the current task to sleep for 'ticks' amount of time */
void task_sleep(uint32_t ticks)
{
    asm volatile("cli");

    // Set the sleep duration and change state
    task_table[current_task].sleep_ticks = ticks;
    task_table[current_task].state = TASK_STATE_SLEEPING;

    asm volatile("sti");

    // Halt the TASK. This waits for the next interrupt (timer),
    // which will trigger the scheduler. Since we marked ourselves
    // as SLEEPING, the scheduler will switch to another task.
    while(task_table[current_task].state == TASK_STATE_SLEEPING)
    {
        asm volatile("hlt");
    }
}

//========================================================================================
/* Cleans up memory and task state for any zombie tasks. */
void reaper()
{
    // Since this is only called via user input in kshell, ints must be enabled.
    asm volatile("cli");

    for(int i=0; i<MAX_TASKS; i++)
    {
        if(task_table[i].state == TASK_STATE_ZOMBIE)
        {
            // Free the task's stack
            free((void*)task_table[i].stack_base);

            // Mark the slot as free
            task_table[i].state = TASK_STATE_FREE;
            task_table[i].stack_base = 0;
            task_table[i].esp = 0;
            memset(task_table[i].name, 0, 24);
        }
    }

    asm volatile("sti");
}

//========================================================================================
/* ... */
void wait_for_task(const char* s)
{
    static uint8_t is_active = 0;

    int i;
    for(i=0; i<MAX_TASKS; i++)
    {
        if(strncmp(s, task_table[i].name, strlen(s))==0 \
        && strlen(s) == strlen(task_table[i].name))
        {
            is_active = 1;
            break;
        }
    }

    if(is_active)
    {
        while(task_table[i].state == TASK_STATE_RUNNING)
        {
            asm volatile("hlt");
        }
    }
}

//========================================================================================
/* Round Robin scheduler function called by the timer IRQ handler. */
uint32_t schedule(uint32_t current_esp)
{
    // The PIT gets enabled before Tasking.
    if(!tasking_enabled) { return(current_esp); }

    // Save the current task's stack.
    if(task_table[current_task].state == TASK_STATE_RUNNING \
    || task_table[current_task].state == TASK_STATE_SLEEPING)
    {
        task_table[current_task].esp = current_esp;
    }

    // Round Robin.
    uint32_t next_task_index = current_task;
    do {
        next_task_index = (next_task_index + 1) % MAX_TASKS;
    } 
    while(task_table[next_task_index].state != TASK_STATE_RUNNING);

    // Update the current task index
    current_task = next_task_index;

    // Return the new task's stack pointer
    return(task_table[current_task].esp);
}

//========================================================================================
/*
 * Marks the current task as a ZOMBIE.
 * It then spins, waiting for the scheduler (running as another task) to reap it.
 */
void task_kill()
{
    // Mark ourselves as a zombie, ready for reaping.
    asm volatile("cli");
    task_table[current_task].state = TASK_STATE_ZOMBIE;
    asm volatile("sti");

    // We can't return, and we can't free our own stack.
    // So, we just spin here until the reaper frees our memory on the next tick.
    while(1) { asm volatile("hlt"); }
}

//========================================================================================
/* Displays a list of currently running tasks. */
void task_list()
{
    for(int i=0; i<MAX_TASKS; i++)
    {
        // The name will be empty if the task was never started or it was reaped.
        // In both cases we don't care to list it.
        if(*task_table[i].name) 
        {
            kprintf("%d 0x%x 0x%x %s\n", i, task_table[i].esp, task_table[i].stack_base, task_table[i].name);
        }
    }
}
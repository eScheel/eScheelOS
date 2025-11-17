#include <kernel.h>
#include <task.h>
#include <string.h> // for memset
#include <pit.h>    // for timer_wait

#define MAX_TASKS   16
#define STACK_SIZE  4096    // 4KB stack for new tasks

// The table of all tasks in the system
struct task task_table[MAX_TASKS];

// The index of the currently running task in the task_table
volatile uint32_t current_task_index = 0;

// Flag to prevent scheduling before tasking is initialized
volatile int tasking_enabled = 0;

/**
 * @brief   Creates a new task and adds it to the task table.
 */
int create_task(void (*task_function)(void))
{
    // Find a free task slot
    int task_index = -1;
    for (int i = 0; i < MAX_TASKS; i++)
    {
        if (task_table[i].state == TASK_STATE_FREE)
        {
            task_index = i;
            break;
        }
    }
    if (task_index == -1) {
        kprintf("\nFailed to create task: Task table full!");
        return -1; // No free slots
    }

    // Allocate a stack
    uint8_t* stack = (uint8_t*)malloc(STACK_SIZE);
    if (!stack) {
        kprintf("\nFailed to create task: Out of memory!");
        return -1; // Malloc failed
    }
    uint32_t stack_top = (uint32_t)stack + STACK_SIZE;

    // "Pre-load" the stack
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

    return 0; // Success
}

/*
 * Initializes the multi-tasking system.
 */
void tasking_init(void)
{
    // Clear the task table
    memset(task_table, 0, sizeof(task_table));

    // Initialize Task 0 (the kernel_main task)
    task_table[0].state = TASK_STATE_RUNNING;
    task_table[0].esp = 0;
    task_table[0].stack_base = 0;
    current_task_index = 0;

    // Enable the scheduler
    tasking_enabled = 1;
}

/*
 * The main scheduler function, called by the timer IRQ.
 * This function also acts as the "reaper" for zombie tasks.
 */
uint32_t schedule(uint32_t current_esp)
{
    if (!tasking_enabled) 
    {
        return current_esp;
    }

    // First, loop through and reap any zombie tasks.
    // This is safe because we are running from an interrupt,
    // and this function is not re-entrant.
    for(int i = 0; i < MAX_TASKS; i++)
    {
        if(task_table[i].state == TASK_STATE_ZOMBIE)
        {
            // Free the task's stack
            free((void*)task_table[i].stack_base);

            // Mark the slot as free
            task_table[i].state = TASK_STATE_FREE;
            task_table[i].stack_base = 0;
            task_table[i].esp = 0;
            //kprintf("\n[Task %d reaped]\n", i);
        }
    }

    // Save the current task's stack (if it's not a zombie)
    if (task_table[current_task_index].state == TASK_STATE_RUNNING)
    {
        task_table[current_task_index].esp = current_esp;
    }

    // Find the next RUNNING task
    uint32_t next_task_index = current_task_index;
    do {
        next_task_index = (next_task_index + 1) % MAX_TASKS;
    } while(task_table[next_task_index].state != TASK_STATE_RUNNING);

    // Update the current task index
    current_task_index = next_task_index;

    // Return the new task's stack pointer
    return task_table[current_task_index].esp;
}

/*
 * Marks the current task as a ZOMBIE.
 * It then spins, waiting for the scheduler (running as another task) to reap it.
 */
void task_exit(void)
{
    // Mark ourselves as a zombie, ready for reaping.
    asm volatile("cli");
    task_table[current_task_index].state = TASK_STATE_ZOMBIE;
    asm volatile("sti");

    // We can't return, and we can't free our own stack.
    // So, we just spin here until the scheduler, running as
    // Task A, frees our memory on the next tick.
    while(1) {
        asm volatile("hlt");
    }
}
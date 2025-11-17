#ifndef __TASK_H
#define __TASK_H    1

#include <stdint.h>

// Define our new task states
#define TASK_STATE_FREE     0   // Slot is free
#define TASK_STATE_RUNNING  1   // Task is active and running
#define TASK_STATE_ZOMBIE   2   // Task has exited and is waiting to be "reaped"

// Defines the state of a task.
// For our software switch, we only need to store the stack pointer.
// All other registers (eax, ebx, eip, eflags, etc.) are
// saved onto this stack by the interrupt handler.
struct task {
    uint32_t esp;           // Stack pointer for this task
    uint32_t stack_base;    // The original pointer from malloc, for freeing later
    int state;             // 0 = inactive/free, 1 = active/running
};

int create_task(void(*task_function)(void));
uint32_t schedule(uint32_t current_esp);
void task_exit(void);

#endif // __TASK_H
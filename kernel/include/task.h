#ifndef __TASK_H
#define __TASK_H    1

#include <stdint.h>

#define MAX_TASKS   16
#define STACK_SIZE  8192    // 4KB stack for new tasks

// Define our new task states
#define TASK_STATE_FREE     0   // Slot is free
#define TASK_STATE_RUNNING  1   // Task is active and running
#define TASK_STATE_ZOMBIE   2   // Task has exited and is waiting to be "reaped"

// Defines the state of a task.
// For our software switch, we only need to store the stack pointer.
// All other registers (eax, ebx, eip, eflags, etc.) are
// saved onto this stack by the interrupt handler.
struct task {
    char name[24];          // ...
    uint32_t esp;           // Stack pointer for this task
    uint32_t stack_base;    // The original pointer from malloc, for freeing later
    int32_t  state;         // 0 = inactive/free, 1 = active/running
}__attribute__((packed));

int task_exec(void(*task_function)(void));
uint32_t schedule(uint32_t current_esp);
void task_kill();

#endif // __TASK_H
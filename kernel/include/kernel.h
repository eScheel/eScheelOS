#ifndef __KERNEL_H
#define __KERNEL_H  1

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

// MMAP.C ==============================================================
#define SMAP_entry_max 32
struct SMAP_entry {
    uint32_t base_addr_low;
    uint32_t base_addr_high;
    uint32_t length_low;
    uint32_t length_high;
    uint32_t type;
    uint32_t acpi;              // ACPI 3.0 Extended Attributes
}__attribute__((packed));

typedef struct {
    uint32_t count;
    struct SMAP_entry entries[SMAP_entry_max];
}__attribute__((packed)) mmap_descriptor_t;

typedef struct {
    uint32_t base_low;
    uint32_t base_high;
    uint32_t length_low;
    uint32_t length_high;
}memory_region_t;

extern uint8_t main_memory_index;
extern memory_region_t available_memory_map[];
extern uint64_t total_memory_size;

extern void mmap_display_available();

// PAGING.C ============================================================
#define PAGE_SIZE 4096

// Page Directory Entry (PDE) Flags.
#define PDE_PRESENT     0x01    // 1 = Page table is present.
#define PDE_READ_WRITE  0x02    // 1 = Read/Write,  0 = Read-only.
#define PDE_USER        0x04    // 1 = User-mode,   0 = Supervisor-mode.
#define PDE_4MB_PAGE    0x80    // 1 = Page is 4MB, 0 = Page is 4KB.

// Page Table Entry (PTE) Flags.
#define PTE_PRESENT     0x01    // 1 = Page is present
#define PTE_READ_WRITE  0x02    // 1 = Read/Write, 0 = Read-only
#define PTE_USER        0x04    // 1 = User-mode,  0 = Supervisor-mode

// For now we are just identity mapping to keep things simple.
#define KERNEL_PHYSICAL_BASE 0x00100000 // As defined in link.ld
#define KERNEL_VIRTUAL_BASE KERNEL_PHYSICAL_BASE

// HEAP.C ==============================================================
// Define a minimum block size. (sizeof(malloc_t) [8] + 16) = 24 bytes.
#define MIN_BLOCK_SPLIT (sizeof(malloc_t) + 16)

struct HEAP_info {
    uint32_t base;
    uint32_t size;
    uint32_t used;
    uint32_t end;
}/*__attribute__((packed))*/;

typedef struct {
    uint32_t size;      // Size of the data payload (not including this header)
    uint8_t reserved;   // 1 = used, 0 = free
    uint8_t padding[3]; // Pad struct to 8 bytes.
} malloc_t; 

extern void print_heap_info();
extern void* malloc(size_t);
extern void  free(void*);

// TASK.C =============================================================
#define MAX_TASKS   16
#define STACK_SIZE  8192    // 4KB stack for new tasks

// Define our new task states
#define TASK_STATE_FREE     0   // Slot is free
#define TASK_STATE_RUNNING  1   // Task is active and running
#define TASK_STATE_ZOMBIE   2   // Task has exited and is waiting to be "reaped"
#define TASK_STATE_SLEEPING 3

// Defines the state of a task.
// For our software switch, we only need to store the stack pointer.
// All other registers (eax, ebx, eip, eflags, etc.) are
// saved onto this stack by the interrupt handler.
struct task {
    char name[24];          // ...
    uint32_t esp;           // Stack pointer for this task
    uint32_t stack_base;    // The original pointer from malloc, for freeing later
    uint8_t  state;         // 0 = inactive/free, 1 = active/running
    uint32_t sleep_ticks;
}__attribute__((packed));

extern volatile uint8_t tasking_enabled;

extern int task_exec(void(*)(void), const char* );
extern uint32_t schedule(uint32_t);
extern void task_kill();
extern void task_list();
extern void task_tick();
extern void task_sleep(uint32_t);
extern void reaper();
extern void wait_for_task(const char* );

// KERNEL.ASM =========================================================
extern void SYSTEM_HALT();
extern uint32_t EFLAGS_VALUE();

// KERNEL.C ===========================================================
extern void kernel_main();

// IO.ASM =============================================================
extern uint8_t  INB(uint16_t);
extern void     OUTB(uint16_t, uint8_t);
extern uint16_t INW(uint16_t);
extern void     OUTW(uint16_t, uint16_t);
extern uint32_t INL(uint16_t);
extern void     OUTL(uint16_t, uint32_t);

#endif // __KERNEL_H
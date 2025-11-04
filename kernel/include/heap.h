#ifndef __HEAP_H
#define __HEAP_H    1

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

struct HEAP_info {
    uint32_t base;
    uint32_t size;
    uint32_t used;
    uint32_t end;
}__attribute__((packed));

void heap_init(uint32_t base_addr, uint32_t length);
void print_heap_info();

#endif // __HEAP_H
#ifndef __KERNEL_H

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

#define LOADING_SYMBOL  0xff

#define SMAP_entry_max 32
typedef struct {
    uint64_t base;
    uint64_t length;
}memory_region_t;


#endif // __KERNEL_H
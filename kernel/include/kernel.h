#ifndef __KERNEL_H

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

#define LOADING_SYMBOL  0xff

void vga_printc(char);
void vga_prints(const char*);
void vga_printd(uint32_t);
void vga_printh(uint32_t);

size_t strlen(const char*);
int strncmp(const char*, const char*, size_t);
void memset(void*, uint8_t, size_t);
void memcpy(void*, void*, size_t);



#endif // __KERNEL_H
#ifndef __STRING_H
#define __STRING_H  1

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

extern size_t strlen(const char*);
extern int strncmp(const char*, const char*, size_t);
extern void memset(void*, uint8_t, size_t);
extern void memcpy(void*, void*, size_t);

#endif // __STRING_H
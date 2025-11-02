#ifndef __STRING_H
#define __STRING_H

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

size_t strlen(const char*);
int strncmp(const char*, const char*, size_t);
void memset(void*, uint8_t, size_t);
void memcpy(void*, void*, size_t);

#endif // __STRING_H
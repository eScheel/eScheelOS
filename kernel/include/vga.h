#ifndef __VGA_H
#define __VGA_H

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

#define VGA_WIDTH  80
#define VGA_HEIGHT 25
#define VGA_MEMORY 0xB8000

#define LOADING_SYMBOL  0xff

size_t vga_get_x();
size_t vga_get_y();

void vga_putc(char c, size_t x, size_t y);
void vga_puts(const char *s, size_t x, size_t y);

void vga_printc(char);
void vga_prints(const char*);
void vga_printd(uint32_t);
void vga_printh(uint32_t);

#endif // __VGA_H
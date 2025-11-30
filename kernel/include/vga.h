#ifndef __VGA_H
#define __VGA_H     1

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

#define VGA_WIDTH  80
#define VGA_HEIGHT 25
#define VGA_MEMORY 0xB8000

#define LOADING_SYMBOL  0xff

extern uint16_t vga_get_x();
extern uint16_t vga_get_y();
extern void vga_set_x(uint16_t x);
extern void vga_set_y(uint16_t y);
extern void vga_set_color(uint8_t);
extern void vga_clear();
extern void vga_update_cursor();
extern void vga_enable_cursor();
extern void vga_disable_cursor();
extern void vga_putc(char, size_t, size_t);
extern void vga_printc(char);
extern void vga_prints(const char*);
extern void vga_printd(uint32_t);
extern void vga_printh(uint32_t);

#endif // __VGA_H
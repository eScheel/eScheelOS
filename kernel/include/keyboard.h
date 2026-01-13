#ifndef __KEYBOARD_H
#define __KEYBOARD_H

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

#define keyboard_status 0x64
#define keyboard_data   0x60

#define escape_pressed      0x01 
#define left_shift_pressed  0x2a
#define right_shift_pressed 0x36
#define caps_lock_pressed   0x3a
#define left_arrow_pressed  0x4b
#define right_arrow_pressed 0x4d
#define up_arrow_pressed    0x48
#define down_arrow_pressed  0x50

#define left_shift_released     0xaa
#define right_shift_released    0xb6
#define caps_lock_released      0xba

extern uint8_t f12_pressed;

extern volatile char keyboard_input_buffer[];

extern void keyboard_reset_buffer();

#endif // __KEYBOARD_H
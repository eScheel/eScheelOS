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

uint8_t shift_key_pressed = 0; 
//uint8_t caps_key_pressed  = 0;

char scancode_to_ascii[] = {                                               \
    0x00, 0x00, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b', \
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',       \
    0x00, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`', 0x00,      \
    '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0x00, '*', 0x00,      \
    ' ', 0x00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x00, 0x00, '7', '8', '9', '-',      \
    '4', '5', '6', '+', '1', '2', '3', '0', '.',
};

char scancode_to_ascii_shifted[] = {                                            
    0x00, 0x00, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', '\b', 
    '\t', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n',       
    0x00, 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0x00,      
    '|', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0x00, '*', 0x00,      
    ' ', 0x00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x00, 0x00, '7', '8', '9', '-',      
    '4', '5', '6', '+', '1', '2', '3', '0', '.',
};


#endif // __KEYBOARD_H
#ifndef __PIT_H_
#define __PIT_H_    1

#include <stdint.h>
#include <stddef.h>

extern void timer_wait(uint32_t);
extern uint32_t timer_get_ticks();

#endif  // __PIT_H
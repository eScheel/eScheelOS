#ifndef __PIT_H_
#define __PIT_H_    1

#include <stdint.h>
#include <stddef.h>

extern volatile uint32_t system_uptime_seconds;

extern void timer_wait(uint32_t);

#endif  // __PIT_H
#ifndef __PIT_H_
#define __PIT_H_    1

#include <stdint.h>
#include <stddef.h>

extern volatile uint32_t system_uptime_seconds;
extern volatile uint32_t system_uptime_minutes;
extern volatile uint32_t system_uptime_hours;
extern volatile uint32_t system_uptime_days;

extern void timer_wait(uint32_t);

#endif  // __PIT_H
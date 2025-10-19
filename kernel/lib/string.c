#include <stddef.h>
#include <stdint.h>

/* ... */
size_t strlen(const char* str) 
{
	size_t len = 0;
	while(str[len] != '\0')
    {
        len++;
    }
	return(len);
}

/* ... */
void memset(void* data, uint8_t c, size_t n)
{
    uint8_t* ptr = data;
    for(size_t i=0; i<n; i++)
    {
        ptr[i] = c;
    } 
}
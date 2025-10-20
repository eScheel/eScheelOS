#include <kernel.h>

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
int strncmp(const char* str1, const char* str2, size_t n)
{
    for(size_t i = 0; i < n; i++)
    {
        unsigned char c1 = str1[i];
        unsigned char c2 = str2[i];

        if (c1 != c2 || c1 == '\0')
        {
            return c1 - c2;
        }
    }

    return 0;
}

/* ... */
void memset(void* data, uint8_t c, size_t n)
{
    uint8_t* ptr = (uint8_t*)data;

    for(size_t i=0; i<n; i++)
    {
        ptr[i] = c;
    } 
}

/* ... */
void memcpy(void* src, void* dst, size_t n)
{
    uint8_t* s = (uint8_t*)src;
    uint8_t* d = (uint8_t*)dst;

    for(size_t i=0; i<n; i++)
    {
        d[i] = s[i];
    }
}
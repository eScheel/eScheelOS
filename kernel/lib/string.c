#include <string.h>

//========================================================================================
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

//========================================================================================
/* ... */
int strncmp(const char* s1, const char* s2, size_t n)
{
    // ...
    for(size_t i=0; i<n; i++) 
    {
        // Compare the characters as unsigned char to ensure correct lexicographical ordering.
        uint8_t c1 = (uint8_t)s1[i];
        uint8_t c2 = (uint8_t)s2[i];
        if(c1 != c2) { return(1);  }

        // If we hit the end of the string, and they are equal so far, we are done.
        if(c1 == '\0') { break; }
    }

    // Everything was equal..
    return 0;
}

//========================================================================================
/* ... */
void memset(void* data, uint8_t c, size_t n)
{
    uint8_t* ptr = (uint8_t*)data;

    for(size_t i=0; i<n; i++)
    {
        ptr[i] = c;
    } 
}

//========================================================================================
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
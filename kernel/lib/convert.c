#include <convert.h>

//========================================================================================
/* Convert string to int. */
int32_t atoi(char *p)
{
    int32_t ret = 0;
    while(*p) 
    {
        ret = (ret<<3) + (ret<<1) + (*p) - '0';
        p++;
    }
    return(ret);
}
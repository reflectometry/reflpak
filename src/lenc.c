/* Function returns character length of string */

#include <lenc.h>
#undef lenc

int lenc(char *string)
{
   return (string == NULL) ? 0 : strcspn(string, " ");
}


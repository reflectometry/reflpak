/* Subroutine returns length of string preceding a period */

#include <string.h>
#include <lenpre.h>
#undef lenpre

int lenpre(char *string)
{
   return (string == NULL) ? 0 : strcspn(string, ". ");
}


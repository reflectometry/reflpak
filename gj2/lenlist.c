/* Subroutine returns length of string preceding a period */

#include <string.h>
#include <lenlist.h>
#undef lenlist

int lenlist(char *string)
{
   return (string == NULL) ? 0 : strspn(string, ".");
}


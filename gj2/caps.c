/* Subroutine changes lowercase characters in string to capitals */

/* For NULL */
#include <stddef.h>
#include <ctype.h>
#include <caps.h>

char *caps(char *String)
{
   register char *string;

   if (String != NULL) for (string = String; *string != 0; string++)
      *string = (char) toupper((int) *string);

   return String;
}


#include <stddef.h>
#include <ctype.h>
#include <caps.h>

/* Subroutine changes lowercase characters in string to capitals */
char *caps(char *String)
{
   register char *string;

   if (String != NULL) for (string = String; *string != 0; string++)
      *string = (char) toupper((int) *string);

   return String;
}


/* Subroutine copies basename portion of src to dest */
/* Basename is determined by first '.' or ' ' in src */

#include <string.h>
#include <copyBasename.h>
#include <lenpre.h>

int copyBasename(char *dest, char *src)
{
   register int l;

   l = lenpre(src);

   strncpy(dest, src, l);
   dest[l] = 0;
   return l;
}


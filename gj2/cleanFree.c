/* Deallocates dynamically allocated arrays */

#include <stdlib.h>
#include <cleanFree.h>

void cleanFree(void **ptr)
{
   if (*ptr != NULL) {
      free(*ptr);
      *ptr = NULL;
   }
}


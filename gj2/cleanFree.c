void FREE(void *);

/* Deallocates dynamically allocated arrays */

#include <stdlib.h>
#include <cleanFree.h>

void cleanFree(void **ptr)
{
   if (*ptr != NULL) {
      FREE(*ptr);
      *ptr = NULL;
   }
}


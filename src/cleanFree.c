/* Deallocates dynamically allocated arrays */

#include <stdlib.h>
#include <cleanFree.h>
#ifndef FREE
#define FREE free
#else
extern void FREE(void *);
#endif

void cleanFree(double **ptr)
{
   if (*ptr != NULL) {
      FREE(*ptr);
      *ptr = NULL;
   }
}


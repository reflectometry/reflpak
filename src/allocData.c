/* Allocates space for temporary data */

#include <stdlib.h>
#include <allocData.h>
#include <cleanFree.h>
#include <genmem.h>

#ifndef MALLOC
#define MALLOC malloc
#else
extern void* MALLOC(int n);
#endif

int allocTemp(ndata, nlow, nhigh)
{
   int retValue = 0;

   cleanFree(&qtemp);
   cleanFree(&y);
   cleanFree(&dy);

   qtemp = MALLOC(sizeof(double) * (ndata + nlow + nhigh));
       y = MALLOC(sizeof(double) * (ndata + nlow + nhigh));
      dy = MALLOC(sizeof(double) * (ndata + nlow + nhigh));
   
   if (qtemp == NULL || y == NULL || dy == NULL) {
      cleanFree(&qtemp);
      cleanFree(&y);
      cleanFree(&dy);
      retValue = 1;
   }
   return retValue;
}


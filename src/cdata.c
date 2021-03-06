/* Implements FORTRAN COMMON block CDATA */

#define COMMON
#include <cdata.h>
#include <cparms.h>
#include <stdlib.h>
#include <stdio.h>

#include "cleanFree.h"

#ifndef MALLOC
#define MALLOC malloc
#else
extern void* MALLOC(size_t);
#endif

void freeCdata(void)
{
   /* Free previously allocated data */
   cleanFree(&xdat);
   cleanFree(&ydat);
   cleanFree(&srvar);
   cleanFree(&yfit);
   cleanFree(&xtemp);
   cleanFree(&ytemp);
}

int allocCdata(int new_npnts)
{
  static int allocated = 0;
   int retValue = 1;

   npnts = new_npnts;
   if (npnts == allocated) return retValue;

   /* XXX FIXME XXX - relies on pointers initialized to NULL by compiler. */
   if (allocated > 0) freeCdata();
   /* printf("allocating %d points\n",npnts); */
   loaded = FALSE;
   xdat = MALLOC(sizeof(double) * npnts);
   ydat = MALLOC(sizeof(double) * npnts);
   srvar = MALLOC(sizeof(double) * npnts);
   yfit = MALLOC(sizeof(double) * npnts);
   xtemp = MALLOC(sizeof(double) * npnts);
   ytemp = MALLOC(sizeof(double) * npnts);
   /* printf("xdat:%8p xtemp:%8p\n",xdat,xtemp); */
    
   if (
       xdat == NULL ||
       ydat == NULL ||
      srvar == NULL ||
       yfit == NULL ||
      xtemp == NULL ||
      ytemp == NULL
   ) {
      npnts = 0;
      retValue = 0;
      freeCdata();
   }
   allocated = npnts;
   return retValue;
}


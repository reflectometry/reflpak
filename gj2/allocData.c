extern void *MALLOC(int);
extern void *REALLOC(void *, int);

/* Allocates space for temporary data */
#include <stdlib.h>
#include <stdio.h>
#include <allocData.h>
#include <cleanFree.h>

#include <genpsi.h>
#include <genpsl.h>
#include <genmem.h>

int allocTemp(int ndata, int nlow, int nhigh)
{
   int retValue = 0;

   cleanFree((void **) (&qtemp));
   cleanFree((void **) (&dy));
   cleanFree((void **) (&y));

   qtemp = (double *) MALLOC(sizeof(double) *          (ndata + nlow + nhigh));
      dy = (double *) MALLOC(sizeof(double) * ncross * (ndata + nlow + nhigh));
       y = (double *) MALLOC(sizeof(double) * ncross * (ndata + nlow + nhigh));

   if (qtemp == NULL || dy == NULL || y == NULL) {
      cleanFree((void **) (&qtemp));
      cleanFree((void **) (&dy));
      cleanFree((void **) (&y));
      retValue = 1;
   }
   return retValue;
}


int allocData(int npnts, double **xdat, double **ydat, double **srvar,
   double **yfit, double **q4x)
{
   int retValue = 1;

   /* Free previously allocated data */
   cleanFree((void **) xdat);
   cleanFree((void **) ydat);
   cleanFree((void **) srvar);
   cleanFree((void **) yfit);
   cleanFree((void **) q4x);
   
    *xdat = (double *)MALLOC(sizeof(double) * npnts);
    *ydat = (double *)MALLOC(sizeof(double) * npnts);
   *srvar = (double *)MALLOC(sizeof(double) * npnts);
    *yfit = (double *)MALLOC(sizeof(double) * npnts);
     *q4x = (double *)MALLOC(sizeof(double) * npnts);

   if (
       *xdat == NULL ||
       *ydat == NULL ||
      *srvar == NULL ||
       *yfit == NULL ||
       *q4x == NULL
   ) {
      retValue = 0;
      cleanFree((void **) xdat);
      cleanFree((void **) ydat);
      cleanFree((void **) srvar);
      cleanFree((void **) yfit);
      cleanFree((void **) q4x);
   }
   return retValue;
}


int allocMaps(int npntsx[4], int *nqx[4], int xspin[4])
{
   int retValue = 1;
   register int xsec;

   /* Free previously allocated maps */
   for (xsec = 0; xsec < 4; xsec++)
      cleanFree((void **) (nqx + xsec));

   for (xsec = 0; xsec < 4; xsec++) {
      if (xspin[xsec]) {
         nqx[xsec] = MALLOC(sizeof(int) * npntsx[xsec]);
         if (nqx[xsec] == NULL) {
            retValue = 0;
            for (xsec--; xsec >=0; xsec--)
               cleanFree((void **) (nqx + xsec));
            break;
         }
      }
   }
   return retValue;
}


int allocDatax(int n4x, double **xtemp, double **q4x, double **y4x,
   complex **yfita)
{
   int retValue = 1;

   /* Free previosly allocated data */
   cleanFree((void **) xtemp);
   cleanFree((void **) y4x);
   cleanFree((void **) yfita);

     *q4x =  (double *) REALLOC(*q4x, sizeof(double) *          n4x);
   *xtemp =  (double *)  MALLOC(      sizeof(double) *          n4x);
     *y4x =  (double *)  MALLOC(      sizeof(double) * ncross * n4x);
   *yfita = (complex *)  MALLOC(      sizeof(double) * ncross * n4x);

   if (*xtemp == NULL || *q4x == NULL || *y4x == NULL || *yfita == NULL) {
      retValue = 0;
      cleanFree((void **) q4x);
      cleanFree((void **) xtemp);
      cleanFree((void **) y4x);
      cleanFree((void **) yfita);
   }
   return retValue;
}


/* Subroutine makes a small increment in fit parameter A(NPARM) to be
   used when evaluating a numerical derivative
   John Ankner 27 February 1991 */

#include <delparm.h>
#include <dlconstrain.h>

#include <stdio.h>

void delparm(int nparm, int plus, double *delP)
{

/* Fractional change in parameter for derivative evaluation parameter */

#include <parameters.h>
#include <genpsi.h>
#include <genpsd.h>

   nparm--; /*ARRAY*/
   if (nparm >= 0) {
      A[nparm] *= (plus) ?
         (1.0 + DELA/2.0) :
         (1.0 - DELA/2.0);
      /* constrain(A); */
      (*Constrain)(1, A, nlayer);
      *delP = A[nparm] * DELA;
   }
}


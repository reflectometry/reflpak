/* Subroutine FGEN calculates the log(reflectivity) and derivatives
   to be used by fit routine MRQMIN
   John Ankner 3-July-1990 */

#include <math.h>
#include <stdio.h>
#include <fgen.h>
#include <dlconstrain.h>
#include <genshift.h>
#include <genderiv.h>


void fgen(double q[], double a[], double yfit[], double *dyda, int ndata,
   int ma)
{
#include <parameters.h>
#include <cparms.h>
#include <clista.h>
#include <genpsi.h>

   /* Set generating parameters equal to fit parameters */
   /* constrain(a); */
   (*Constrain)(FALSE, a, ntlayer, nmlayer, nrepeat, nblayer);
   genshift(a, FALSE);

   /* Calculate reflectivity and derivatives */
   if (ndata < 2)
      puts("/** Not enough data points **/");
   else {
      int j;

      /* Reflectivity */
      genderiv(q, yfit, ndata, 0);
      /* Derivatives */
      for (j = 0; j < mfit; j++) {
         genderiv(q, dyda, ndata, listA[j] + 1); /*ARRAY*/
         dyda += ndata;
      }
   }
}


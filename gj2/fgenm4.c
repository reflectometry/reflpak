/* Subroutine FGENM4 calculates the log(reflectivity) and derivatives */
/* of magnetic profiles to be used by fit routine MRQMIN */
/* John Ankner 21 September 1992 */

#include <stdio.h>
#include <fgenm4.h>
#include <dlconstrain.h>
#include <genshift.h>
#include <genderiv4.h>

#include <parameters.h>
#include <cparms.h>

#include <clista.h>
#include <genpsr.h>
#include <genpsi.h>
#include <genmem.h>
#include <cdata.h>

void fgenm4(double q[], double *a, double *yfit, double *dyda, int ndata,
   int ma)
/* double a[NA], yfit[ndata], dyda[ma * ndata] */
{
   /* Set generating parameters equal to fit parameters */
   /* constrain(a); */
   (*Constrain)(FALSE, a, nlayer);
   genshift(a, FALSE);

   /* Calculate reflectivity and derivatives */
   if (ndata < 2)
      puts("/** Not enough data points **/");
   else {
      register int n, m, xsec;
      register double *y, *Y4x;

      /* Calculate derivatives */
      y = dyda;
      for (m = 0; m < mfit; m++) {
         genderiv4(q4x, y4x, n4x, listA[m] + 1);
         /* Transfer to DYDA */
         Y4x = y4x;
         for (xsec = 0; xsec < 4; xsec ++) {
            if (npntsx[xsec] > 0) {
               for (n = 0; n < npntsx[xsec]; n++)
                  *(y++) = Y4x[nqx[xsec][n]];
               Y4x += n4x;
            }
         }
      }
      /* Calculate reflectivity */
      genderiv4(q4x, y4x, n4x, 0);
      /* Save in YFIT */
      y = yfit;
      Y4x = y4x;
      
      for (xsec = 0; xsec < 4; xsec++) {
         if (npntsx[xsec] > 0) {
            for (n = 0; n < npntsx[xsec]; n++)
               *(y++) = Y4x[nqx[xsec][n]];
            Y4x += n4x;
         }
      }
   }
}


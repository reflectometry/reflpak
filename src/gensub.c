/* Subroutine generates substrate tail of layer profile
   John Ankner 5 December 1990 */

#include <stdio.h>
#include <gensub.h>
#include <gAverage.h>

void gensub(double qcsq[], double d[], double rough[], double mu[],
            int nlayer, double zint[], double rufint[], int nrough)
{

#include <parameters.h>
#include <glayd.h>
#include <glayi.h>

   int i;

   /* Correct bogus input */
   if (rough[nlayer] < 1.e-10) rough[nlayer] = 1.e-10;

   /* Check for funny number of layers */
   if (nlayer < 1) {
      nglay = 0;
      puts("/** NLAYER must be positive **/");
   } else {
      register int midpoint = nrough / 2 + 1;

      /* Evaluate substrate gradation */
      for (i = 0; i <= nrough - midpoint; i++) {
            gd[nglay] = zint[i + midpoint] * rough[nlayer];
         gqcsq[nglay] = gAverage(qcsq, nlayer, rufint[i + midpoint]);
           gmu[nglay] = gAverage(  mu, nlayer, rufint[i + midpoint]);
         nglay++;
      }
      gqcsq[nglay] = qcsq[nlayer];
        gmu[nglay] =   mu[nlayer];
         gd[nglay] =    d[nlayer];
      nglay++;
   }
}


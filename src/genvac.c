/* Subroutine generates vacuum tail of layer profile
   John Ankner 5 December 1990 */

#include <stdio.h>
#include <genvac.h>
#include <gAverage.h>

void genvac(double qcsq[], double d[], double rough[], double mu[],
            int nlayer, double zint[], double rufint[], int nrough)
{

#include <parameters.h>
#include <glayd.h>
#include <glayi.h>

   int i;

   /* Correct bogus input */
   if (rough[1] < 1.e-10) rough[1] = 1.e-10;

   /* Check for funny number of layers */
   if (nlayer < 1) {
      nglay = 0;
      puts("/** NLAYER must be positive **/");
   } else {

      /* Evaluate vacuum gradation */
      gqcsq[nglay] = qcsq[0];
        gmu[nglay] =   mu[0];
         gd[nglay] =    d[0];
      nglay++;
      for (i = 0; i <= nrough / 2; i++) {
            gd[nglay + i] = zint[i] * rough[1]; /*ARRAY*/
         gqcsq[nglay + i] = gAverage(qcsq, 1, rufint[i]);
           gmu[nglay + i] = gAverage(  mu, 1, rufint[i]);
      }
      nglay += nrough / 2 + 1;
   }
}


double vacThick(double rough[], double zint[], int nrough)
{
   int i;
   double thick = 0.;

   for (i = 0; i <= nrough/2; i++)
     thick += zint[i];
   return rough[1] * thick;
}


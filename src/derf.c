/* ! Approximate Error Function */

#include <math.h>
#include <derf.h>

double derf(double x)
{
/*
 *    Remainder does not excede 1.5 x 10**(-7).
 *    See Handbook of Mathematical Functions by Abramowitz & Stegun,
 *    p. 299, Formula 7.1.26.  Written by N. Berk.
 *
 */
#define P .3275911
#define A1  .254829592
#define A2  -.284496736
#define A3  1.421413741
#define A4  -1.453152027
#define A5  1.061405429

   double s,t,f;
   double retValue;

   retValue = 0.;

   if (x != 0.) {

      t = 1./(1. + P * fabs(x));

      s = A5;
      s = A4 + t * s;
      s = A3 + t * s;
      s = A2 + t * s;
      s = A1 + t * s;
      s *= t;

      if (fabs(x) < 0.0001)
         f = 1.;
      else if (fabs(x) > 5.)
         f = 0.;
      else {
         f = exp(x * x);
         f = 1./f;
      }
      retValue = copysign(1. - s * f, x);
   }
   return retValue;
}


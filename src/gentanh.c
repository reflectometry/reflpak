/* Generate hyperbolic tangent profile of equal abscissa steps given the
   number of points in said profile
   John Ankner 26 October 1990 */

#include <math.h>
#include <stdio.h>
#include <gentanh.h>
#include <calcStep.h>

#include <parameters.h>

/* Local function prototypes */
#include <static.h>

STATIC void doTanh(double *zint, double *rufint, double dist);


void gentanh(int nrough, double zint[], double rufint[])
{
   double *Zint, *Rufint;
   double dist, step;

   if (nrough < 3)
      puts("/** Too few points in NROUGH **/");
   else {
      register int midpoint = nrough / 2;

      /* Inverse tanh varies between -1 and 1 */
      step = 2. / (double) (nrough + 1);

      /* Evaluate lower half of interface */
      /* For odd number of steps, start at half-step */
      /* For even number of steps, start at 0 */
      dist = (nrough & 1) ? -step / 2. : 0.;
      /* Use inverse tanh to calculate step widths in units of fwhm */
      Zint = &(zint[midpoint]);
      Rufint = &(rufint[midpoint]);
      do {
         doTanh(Zint, Rufint, dist);
         Zint--;
         Rufint--;
         dist -= step;
      } while (Zint >= &(zint[0]));

      /* Evaluate upper half of interface */
      /* For odd number of steps, start at half-step */
      /* For even number of steps, start at full-step */
      dist = (nrough & 1) ? step / 2. : step;
      Zint = &(zint[midpoint + 1]);
      Rufint = &(rufint[midpoint + 1]);

      do {
         doTanh(Zint, Rufint, dist);
         Zint++;
         Rufint++;
         dist += step;
      } while (Zint <= &(zint[nrough]));
      /* Calculate step widths (derivative of zint) */
      calcStep(zint, nrough);
   }
}


STATIC void doTanh(double *zint, double *rufint, double dist)
{
   /* Constant CT that ensures that d(tanh CT * Z / ZF) / dZ  =  .5
      when Z = .5 * ZF, where ZF is fwhm */

   *rufint = dist;
   *zint = log((1. + dist) / (1. - dist)) / CT;
}


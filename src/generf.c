/* Generate error function of ordinate steps based on those of the hyperbolic
   tangent (since cannot find inverse erf) given the
   number of points in said profile
   John Ankner 8 November 1990 */

#include <math.h>
#include <stdio.h>
#include <generf.h>
#include <derf.h>
#include <calcStep.h>

/* Local function prototypes */
#include <static.h>

STATIC void doErf(register double *zint, register double *rufint, double dist);


void generf(int nrough, double zint[], double rufint[])
{
#include <parameters.h>

   double dist, step;
   int midpoint = nrough / 2;

   if (nrough < 3)
      puts("/** Too few points in NROUGH **/");
   else {
      register double *Zint, *Rufint;

      /* Error function varies between -1 and 1 */
      step = 2./(double) (nrough + 1);

      /* Evaluate lower half of interface */
      /* For odd number of steps, start at half-step */
      /* For even number of steps, start at 0 */
      dist = (nrough & 1) ? -step / 2. : 0.;
      Zint = &(zint[midpoint]);
      Rufint = &(rufint[midpoint]);

      /* Steps calculated from inverse tanh */
      do {
         doErf(Zint, Rufint, dist);
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
         doErf(Zint, Rufint,  dist);
         Zint++;
         Rufint++;
         dist += step;
      } while (Zint <= &(zint[nrough]));

      /* Calculate step widths (derivative of zint) */
      calcStep(zint, nrough);
   }
}


STATIC void doErf(register double *zint, register double *rufint, double dist)
{
   /*  Constant CE that ensures that d(erf CE*Z/ZF)/dZ = .5 when Z=.5*ZF, */
   /*  where ZF is fwhm */

   *zint = log((1. + (dist)) / (1. - (dist))) / CE;
   *rufint = derf(CE * (*zint));
}


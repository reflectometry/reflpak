/* Subroutine calculates length of low- and high-Q extensions of data to
   be convoluted with delta-Q Gaussian resolution function
   John Ankner 11-May-1989 */

#include <math.h>
#include <stdio.h>
#include <extres.h>
#include <allocData.h>

#include <genmem.h>

/* Local function prototypes */
#include <static.h>

#ifndef M_PI
#define M_PI   3.14159265358979323846
#endif
#ifndef M_LN2
#define M_LN2  0.69314718055994530942
#endif
#ifndef M_LN10
#define M_LN10 2.30258509299404568402
#endif

STATIC int doExtend(double q, double qstep, double lambda, double lamdel,
   double thedel);


void extres(double q[], double lambda, double lamdel, double thedel,
   int npnts)
{
   /* Check for LAMBDA=0 */
   if (lambda < 1.e-10) {
      puts("/** Wavelength must be greater than zero **/");
   } else {
      npnts--; /*ARRAY*/

      /* Determine low-Q extension */
      nlow = doExtend(q[0], q[1] - q[0], lambda, lamdel, thedel);

      /* Determine high-Q extension */
      nhigh = doExtend(q[npnts], q[npnts] - q[npnts - 1], lambda, lamdel, thedel);

   }
}


STATIC int doExtend(double q, double qstep, double lambda, double lamdel,
   double thedel)
{
   double twsgsq, qdel;
   register double qr;
   register int extension;

   /* Calculate resolution width */
   /* Note:  |q| (dL/L + dtheta/theta) == (|q| dL + 4 pi dtheta)/L  */
   qdel = (fabs(q) * lamdel + 4. * M_PI * thedel) / lambda;
   twsgsq = 2. * qdel * qdel / (8. * M_LN2);

   /* Loop until exponential becomes less than .001 */
   extension = 0;
   for (qr = qstep; qr * qr <= twsgsq * 3. * M_LN10; qr += qstep)
      extension++;

   return extension;
}


double *extend(double q[], int ndata, double lambda, double lamdel,
   double thedel)
{
   /* Deallocate previously allocated memory */

   extres(q, lambda, lamdel, thedel, ndata);

   /* Check if required extension is too large */

   if (allocTemp(ndata, nlow, nhigh))
      puts("/** Too many points in resolution extension **/");
   else {
      register int j;
      register double qstep, *newq = qtemp;

      /* Extend Q array in QTEMP */
      qstep = q[1] - q[0];
      for (j = 0; j < nlow; j++)
         *(newq++) = q[0] - (double) (nlow - j) * qstep;
      for (j = 0; j < ndata; j++)
         *(newq++) = q[j];
      qstep = q[ndata - 1] - q[ndata - 2];
      for (j = 1; j <= nhigh; j++)
         *(newq++) = q[ndata - 1] + (double) j * qstep;
   }
   return qtemp;
}


/* Subroutine performs convolution of data in array YFIT with Gaussian
   resolution function in Q, calculated from LAMBDA, LAMDEL, and THEDEL
   John Ankner 19 June 1989 */

#include <math.h>
#ifdef SGI
#include <ieeefp.h>
#endif
#include <mancon.h>

#ifndef M_PI
#define M_PI   3.14159265358979323846
#endif
#ifndef M_LN2
#define M_LN2  0.69314718055994530942
#endif
#ifndef M_LN10
#define M_LN10 2.30258509299404568402
#endif

#include <parameters.h>
#include <cparms.h>

/* Local function prototypes */
#include <static.h>

STATIC int convolve(double *qj, double *qjprime, double *yjprime,
   double *yfit, double *rnorm, double twsgsq, int deldelq);


void mancon(double *q, double lambda, double lamdel, double thedel,
   double *y, double *yfit, int npnts, int nlow, int nhigh, int deldelq)
{
   double qdel, theta, twsgsq, rnorm;
   double qeff;
   register double *qj, *yj;
   int lfinish, hfinish;
   register int j, nstep;

   /* Perform convolution over NPNTS between NLOW and NHIGH extensions */
   for (
      qj = q + nlow, yj = y + nlow, j = nlow;
      j < nlow + npnts;
      qj++, yj++, j++
   ) {

      /* Calculate resolution width and initialize resolution loop */
      theta = lambda * (*qj) / (4. * M_PI);
      if (theta < 1.e-10) theta = 1.e-10;
      qeff = (*qj < 1.e-10) ? 1.e-10 : *qj;
      qdel = qeff * (lamdel / lambda + thedel / theta);
      twsgsq = 2. * qdel * qdel / (8. * M_LN2);
      if (twsgsq < 1.e-10) twsgsq = 1.e-10;
      rnorm = 1.;
      *yfit = *yj;

      /* Check if exponent term becomes smaller than .001 and loop
         until it does so */

      lfinish = FALSE;
      hfinish = FALSE;

      for (nstep = 1; !(lfinish || hfinish); nstep++) {
      /* Evaluate low-Q side */
	 if (j-nstep < 0) lfinish = TRUE;
	 if (!lfinish) 
           lfinish = convolve(qj, qj - nstep, yj - nstep, yfit, &rnorm,
                              twsgsq, deldelq);

      /* Evaluate high-Q side */
         if (j+nstep >= npnts+nlow+nhigh) hfinish = TRUE;
         if (!hfinish)
           hfinish = convolve(qj, qj + nstep, yj + nstep, yfit, &rnorm,
                              twsgsq, deldelq);

      }

      /* Normalize convoluted value to integrated intensity of
         resolution function */
      *(yfit++) /= rnorm;
   }
}


STATIC int convolve(double *qj, double *qjprime, double *yjprime,
   double *yfit, double *rnorm, double twsgsq, int deldelq)
{
   double qres, rexp, exparg;

   qres = *qjprime - *qj;
   exparg = qres * qres / twsgsq;
   if (exparg <= 3. * M_LN10) {
      if (!isnan(*yjprime)) {
         /* Evaluate convolution */
         rexp = exp(-exparg);
         *rnorm += rexp;
         /* Evaluate derivative w.r.t. Q */
         if (deldelq) rexp *= 2. * qres / twsgsq;
         *yfit += rexp * (*yjprime);
      }
      return FALSE;
   } else {
      return TRUE;
   }
}


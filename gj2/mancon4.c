/* Subroutine performs convolution of data in array YFIT with Gaussian resolution */
/* function in Q, calculated from LAMBDA, LAMDEL, and THEDEL */
/* John Ankner 14 September 1992 */

#include <math.h>
#ifdef SGI
#include <ieeefp.h>
#endif
#include <mancon4.h>

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

STATIC int convolve(double qres, double yjprime,
   double *yfit, double *rnorm, double twsgsq, int deldelq);


void mancon4(double *q, double lambda, double lamdel, double thedel,
   double *y, double *yfit, int ndata, int nlow, int nhigh, int ncross,
    int deldelq)
/* double q[MAXPTS], yfit[4 * MAXPTS]; */
{
   const int npnts = nlow + nhigh + ndata;
   int j, k, n;

   /* Perform convolution over NDATA between NLOW and NHIGH extensions */
   /* for the needed cross sections */
   for (j = nlow; j < nlow+ndata; j++) {
      double qdel, twsgsq, rnorm;

      /* Calculate resolution width */
      /* Note:  |q| (dL/L + dtheta/theta) == (|q| dL + 4 pi dtheta)/L  */
      qdel = (fabs(q[j]) * lamdel + 4. * M_PI * thedel) / lambda;
      twsgsq = 2. * qdel * qdel / (8. * M_LN2);

      for (n = 0; n < ncross; n++) {
	 int yxsec, fitxsec;

         yxsec = n * npnts;
         fitxsec = n * ndata;

	 /* Loop until exponential becomes smaller than .001 */
         rnorm = 1.;
         *(yfit+fitxsec) = y[yxsec+j];

	 /* Evaluate low-Q side */
	 for (k=1; j-k >= 0; k++) {
	   if (!convolve(q[j]-q[j-k], y[yxsec+j-k], yfit+fitxsec, &rnorm, twsgsq, deldelq))
	     break;
	 }
	 
	 /* Evaluate high-Q side */
	 for (k=1; j+k < npnts; k++) {
	   if (!convolve(q[j]-q[j+k], y[yxsec+j+k], yfit+fitxsec, &rnorm, twsgsq, deldelq))
	     break;
	 }
	 
         /* Normalize convoluted value to integrated intensity of resolution */
         /* function */
         *(yfit+fitxsec) /= rnorm;
      }
      yfit++;
   }
}


STATIC int convolve(double qres, double yj,
   double *yfit, double *rnorm, double twsgsq, int deldelq)
{
   double rexp;

   /* Be sure the following condition matches that in extend.c(doExtend) */
   if (qres * qres > twsgsq * 3. * M_LN10) return FALSE;

   if (!isnan(yj)) {
      /* Evaluate convolution */
      rexp = exp(-qres*qres/twsgsq);
      *rnorm += rexp;
      /* Evaluate derivative w.r.t. Q */
      if (deldelq) rexp *= 2. * qres / twsgsq;
      *yfit += rexp * yj;
   }
   return TRUE;
}


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

STATIC int convolve(int finish, double *qj, double *qjprime, double *yjprime,
   double *yfit, double *rnorm, double twsgsq, int deldelq);


void mancon4(double *q, double lambda, double lamdel, double thedel,
   double *y, double *yfit, int ndata, int nlow, int nhigh, int ncross,
    int deldelq)
/* double q[MAXPTS], yfit[4 * MAXPTS]; */
{
   double qdel, theta, twsgsq, rnorm;
   int lfinish, hfinish;
   int npnts;
   register int j, n;
   register double *qj, *yj, *yfitj;

   npnts = nlow + nhigh + ndata;

   /* Perform convolution over NDATA between NLOW and NHIGH extensions */
   /* for the needed cross sections */
   qj = q + nlow;
   yj = y + nlow;
   yfitj = yfit;
   for (j = 0; j < ndata; j++) {
      int nstep, yxsec, fitxsec;
      double qeff;

      /* Calculate resolution width and initialize resolution loop */
#ifdef MINUSQ
      theta = lambda * fabs(*qj) / (4. * M_PI);
      if (theta < 1.e-10) theta = 1.e-10;
      qeff = *qj;
#else
      theta = lambda * (*qj) / (4. * M_PI);
      if (theta < 1.e-10) theta = 1.e-10;
      if (theta < 1.e-10) theta = 1.e-10;
      qeff = (*qj < 1.e-10) ? 1.e-10 : *qj;
#endif
      qdel = qeff * (lamdel / lambda + thedel / theta);
      twsgsq = 2. * qdel * qdel / (8. * M_LN2);
      if (twsgsq < 1.e-10) twsgsq = 1.e-10;
      for (n = 0; n < ncross; n++) {
         yxsec = n * npnts;
         fitxsec = n * ndata;
         rnorm = 1.;
         yfitj[fitxsec] = yj[yxsec];
         /* Check if exponent term becomes smaller than .001 and loop */
         /* until it does so */
         lfinish = FALSE;
         hfinish = FALSE;
         for (nstep = 1; !lfinish || !hfinish; nstep++) {
            /* Evaluate low-Q side */
            lfinish = convolve(lfinish, qj, qj - nstep,
                               yj + yxsec - nstep, yfitj + fitxsec, &rnorm, twsgsq, deldelq);
            /* Evaluate high-Q side */
            hfinish = convolve(hfinish, qj, qj + nstep,
                               yj + yxsec + nstep, yfitj + fitxsec, &rnorm, twsgsq, deldelq);
         }

         /* Normalize convoluted value to integrated intensity of resolution */
         /* function */
         yfitj[fitxsec] /= rnorm;
      }
      qj++;
      yj++;
      yfitj++;
   }
}


STATIC int convolve(int finish, double *qj, double *qjprime, double *yjprime,
   double *yfit, double *rnorm, double twsgsq, int deldelq)
{
   double qres, rexp, exparg;

   qres = (finish) ? 1.e20 : *qjprime - *qj;
   exparg = qres * qres / twsgsq;
   if (exparg <= 3. * M_LN10) {
      if (!isnan(*yjprime)) {
         /* Evaluate straight convolution */
         rexp = exp(-exparg);
         *rnorm += rexp;
         /* Evaluate derivative w.r.t. Q */
         if (deldelq) rexp *= 2. * qres / twsgsq;
         *yfit += rexp * (*yjprime);
      }
   } else
       finish = TRUE;
   return finish;
}


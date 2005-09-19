/* Calculates reflectivity */
#include <calcReflec.h>
#include <ngenlayers.h>
#include <mgenlayers.h>
#include <gmagpro4.h>
#include <r4x.h>
#include <r4xa.h>

#include <glayi.h>
#include <glayd.h>
#include <genpsl.h>
#include <genpsc.h>
#include <genpsr.h>
#include <genpsi.h>
#include <genpsd.h>

/* gfortran doesn't define loc(), so provide fortran with
 * the function isnull to test if the pointer is null.
 */

#define isnull isnull_
int isnull(double q[]) { return q == NULL; }

#ifdef MINUSQ
/* Local function prototypes */

#include <static.h>
STATIC void greverse(double dqcsq, double dmu);

#endif

#if DOTIME
#include <sys/time.h>
double tic(void)
{
  static double base = 0.0;
  struct timeval tv;
  double now, delta;
  gettimeofday(&tv, NULL);
  now = (double) tv.tv_sec + 1.e-6*(double)tv.tv_usec;
  delta = now-base;
  base = now;
  return delta;
}
#endif


void calcReflec(double qtemp[], void *y, int npnts, int intens)
{
   register int j;
   register double qccorr, mucorr;
   double time;

   /* Make sure qtemp is positive */
/* Not necessary and causes problems with mancon4 at low Q */
/*   for (j = 0; j < npnts; j++) {                         */
/*      if (qtemp[j] < 1.e-10)                             */
/*         qtemp[j] = 1.e-10;                              */
/*      else                                               */
/*         break;                                          */
/*   }                                                     */

   /* Correct refractive indices for incident medium */
   qccorr = qcsq[0];
   mucorr = mu[0];
   for (j = 0; j <= nlayer; j++) {
      qcsq[j] -= qccorr;
      mu[j] -= mucorr;
   }
   ngenlayers(qcsq, d, rough, mu, nlayer, zint, rufint, nrough, proftyp);
   mgenlayers(qcmsq, dm, mrough, the, nlayer, zint, rufint, nrough, proftyp);
   gmagpro4();
#ifdef MINUSQ
   greverse(qcsq[nlayer], mu[nlayer]);
#endif
   /* Un-correct */
   for (j = 0; j <= nlayer; j++) {
      qcsq[j] += qccorr;
      mu[j] += mucorr;
   }
   /* Calculate reflectivity */
   if (intens) {
      double *yptrs[4];
      double *Y = (double *)y;
      register int xsec;

      for (xsec = 0; xsec < 4; xsec++) {
         if (xspin[xsec]) {
            yptrs[xsec] = Y;
            Y += npnts;
         } else
            yptrs[xsec] = NULL;
      }
      r4x(qtemp, yptrs[0], yptrs[1], yptrs[2], yptrs[3], &npnts, &lambda, 
          gqcsq, gmu, gd, gqmsq, gthe, &nglay); 
   } else {
      complex *yptrsa[4];
      complex *Y = (complex *)y;
      register int xsec;

      for (xsec = 0; xsec < 4; xsec++) {
         if (xspin[xsec]) {
            yptrsa[xsec] = Y;
            Y += npnts;
         } else
            yptrsa[xsec] = NULL;
      }
      r4xa(qtemp, yptrsa[0], yptrsa[1], yptrsa[2], yptrsa[3], &npnts, &lambda,
          gqcsq, gmu, gd, gqmsq, gthe, &nglay); 
   }
}

#ifdef MINUSQ

STATIC void greverse(double dqcsq, double dmu)
{
   register int i, j;

   for (i = 0, j = 2 * nglay + 1; j > nglay; i++, j--) {
      gqcsq[j] = gqcsq[i] - dqcsq;
        gmu[j] = gmu[i] - dmu;
         gd[j] = gd[i];
      gqmsq[j] = gqmsq[i];
       gthe[j] = gthe[i];
   }
}
#endif


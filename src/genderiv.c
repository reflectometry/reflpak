/* Subroutine evaluates function or derivative for reflectivity fit
   to log(data) and spin asymmetry
   John Ankner 3-July-1990 */

#include <math.h>
#include <stdio.h>
#include <genderiv.h>
#include <extres.h>
#include <genmulti.h>
#include <grefint.h>
#include <grefamp.h>
#include <cdata.h>
#include <delparm.h>
#include <mancon.h>


/* Internal function prototypes */
#ifndef STATIC
   #include <static.h>
#else /* ! defined(STATIC) */
   #define correct genCorrect
   #define uncorrect genUncorrect
   #define calcReflec genCalcReflec
   #define dressReflec genDressReflec
#endif /* STATIC */

STATIC double correct(void);
STATIC void uncorrect(register double qccorr);
STATIC void calcReflec(double qtemp[], double y[], int npnts);
STATIC void dressReflec(int nparm, double *y, double *dy, int ndata);


/* For grefint */
#include <glayd.h>
#include <glayi.h>

#include <parameters.h>
#include <cparms.h>
#include <genmem.h>
#include <genpsc.h>
#include <genpsl.h>
#include <genpsi.h>
#include <genpsd.h>

void genderiv(double q[], double yfit[], int ndata, int nparm)
{
   double delP;

   /* Generate extended function and derivative values to convolute with
      instrumental resolution */

   if (nparm <= NA) {
      /* Calculate extended reflectivity and derivative */

      /* Calculate reflectivity */
      calcReflec(qtemp, y, ndata + nlow + nhigh);

      /* Perform convolution with instrumental resolution */
      /* Calculate function convolution */
      mancon(qtemp, lambda, lamdel, thedel, y, yfit, ndata, nlow, nhigh, FALSE);
      /* yfit now contains convolved reflectivity */

      if (nparm > 0) {
         register int j;
         static double orig[NA];

         /* Save current parameters */
         for (j = 0; j < NA; j++)
            orig[j] = A[j];

         /* Take derivative of valid fit parameter */
         /* Evaluate reflectivity at slight positive parameter increment */
         delparm(nparm, TRUE, &delP);
         calcReflec(qtemp, y, ndata + nlow + nhigh);
         /* delparm(nparm, FALSE, &delP); */
         for (j = 0; j < NA; j++)
            A[j] = orig[j];

         /* Evaluate reflectivity at slight negative parameter increment */
         delparm(nparm, FALSE, &delP);
         calcReflec(qtemp, dy, ndata + nlow + nhigh);
         /* delparm(nparm, TRUE, &delP); */
         for (j = 0; j < NA; j++)
            A[j] = orig[j];

         /* Calculate numerical derivative */
         if (fabs(delP) < 1.e-20)
            for (j = 0; j < ndata + nlow + nhigh; j++)
               y[j] = 0.;
         else
            for (j = 0; j < ndata + nlow + nhigh; j++)
               y[j] = (y[j] - dy[j]) / delP;

         /* Calculate derivative convolution */
         mancon(qtemp, lambda, lamdel, thedel, y, dy, ndata, nlow, nhigh, FALSE);
         /* dy now contains convolved average increment */
      }

      /* Dress with intensity factors */
      dressReflec(nparm, yfit, dy, ndata);
   } else
      puts("/** Invalid NPARM **/");
}


STATIC double correct(void)
{
   register int j;
   register double qccorr;

   /* Correct refractive indices for incident medium */
   qccorr = tqcsq[0];
   for (j = 0; j <= ntlayer; j++)
      tqcsq[j] -= qccorr;
   for (j = 1; j <= nmlayer; j++)
      mqcsq[j] -= qccorr;
   for (j = 1; j <= nblayer; j++)
      bqcsq[j] -= qccorr;

   return qccorr;
}


STATIC void uncorrect(register double qccorr)
{
   register int j;

   /* Un-correct */
   for (j = 0; j <= ntlayer; j++)
      tqcsq[j] += qccorr;
   for (j = 1; j <= nmlayer; j++)
      mqcsq[j] += qccorr;
   for (j = 1; j <= nblayer; j++)
      bqcsq[j] += qccorr;
}

#define DOTIME 0
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



STATIC void calcReflec(double *qtemp, double *y, int npnts)
{
   register int j;
   double qccorr;
   double qeff;

   qccorr = correct();
   genmulti(tqcsq, mqcsq, bqcsq, tqcmsq, mqcmsq, bqcmsq,
            td, md, bd, trough, mrough, brough, tmu, mmu,
            bmu, nrough,
            ntlayer, nmlayer, nblayer, nrepeat, proftyp);
   uncorrect(qccorr);

#if DOTIME
   tic();
   newgrefint(qtemp,y,&npnts,&lambda,gqcsq,gmu,gd,&nglay);
   printf("newgrefint time=%g\n",tic());
#endif

   for (j = 0; j < npnts; j++) {
     if (realR) {
       double c;
       grefamp(qtemp, &lambda, gqcsq, gmu, gd, &nglay, y, &c);
     } else {
       *y = grefint(qtemp, &lambda, gqcsq, gmu, gd, &nglay);
     }
     y++, qtemp++;
   }

#if DOTIME
   printf("grefint time=%g\n",tic());
#endif

}


STATIC void dressReflec(int nparm, double *y, double *dy, int ndata)
{
   register int j;

   /* PAK: Converted to linear according to the changes done to gj2 by KOD */
   switch (nparm) {
      case 0:
         /* log(reflectivity) */
         for (j = 0; j < ndata; j++)
            y[j] = bki + bmintns * y[j];
         break;
      case NA - 1:
         /* Derivative of constant background BKI */
         for (j = 0; j < ndata; j++)
            y[j] = 1.;
         break;
      case NA:
         /* Derivative of intensity scale factor BMINTNS */
	 /* for (j = 0; j < ndata; j++)
            y[j] /= fabs(bki + bmintns * y[j]);
	    */
         break;
      default:
         /* Derivative of internal parameters */
         for (j = 0; j < ndata; j++)
            y[j] = (fabs(dy[j]) <= 1.1e-10) ? 0. : bmintns * dy[j];

   }
}


/* Reflectivity fit to log(data) and spin asymmetry
   John Ankner 2-May-1991 */

#include <math.h>
#include <stdio.h>
#include <gensderiv.h>
#include <extres.h>
#include <genmulti.h>
#include <grefint.h>
#include <delparm.h>
#include <mancon.h>


/* Local function prototypes */
#ifndef STATIC
   #include <static.h>
#else /* ! defined(STATIC) */
   #define correct gensCorrect
   #define minusState gensMinusState
   #define uncorrect gensUncorrect
   #define dressReflec gensDressReflec
   #define calcReflec gensCalcReflec
#endif /* STATIC */

STATIC void calcReflec(double qtemp[], double y[], int npnts);
STATIC double correct(void);
STATIC void minusState(void);
STATIC void uncorrect(double qccorr);
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

void gensderiv(double q[], double yfit[], int ndata, int nparm)
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

         /* Save current values */
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
         /*  if (nparm >= 3) */ /* Inconsistent with genderiv() KOD 3/3/2000 */
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
   double qccorr = tqcsq[0];

   for (j = 0; j <= ntlayer; j++)
      tqcsq[j] += -qccorr + tqcmsq[j];
   for (j = 1; j <= nmlayer; j++)
      mqcsq[j] += -qccorr + mqcmsq[j];
   for (j = 1; j <= nblayer; j++)
      bqcsq[j] += -qccorr + bqcmsq[j];
   return qccorr;
}


STATIC void minusState(void)
{
   register int j;

   for (j = 0; j <= ntlayer; j++)
      tqcsq[j] -= 2. * tqcmsq[j];
   for (j = 0; j <= nmlayer; j++)
      mqcsq[j] -= 2. * mqcmsq[j];
   for (j = 0; j <= nblayer; j++)
      bqcsq[j] -= 2. * bqcmsq[j];
}


STATIC void uncorrect(double qccorr)
{
   register int j;

   for (j = 0; j <= ntlayer; j++)
      tqcsq[j] += qccorr + tqcmsq[j];
   for (j = 1; j <= nmlayer; j++)
      mqcsq[j] += qccorr + mqcmsq[j];
   for (j = 0; j <= nblayer; j++)
      bqcsq[j] += qccorr + bqcmsq[j];
}


STATIC void calcReflec(double *q, double *y, int npnts)
{
   double qccorr, qeff;
   register int j;
   register double *qtemp, *ytemp;

   /* Correct refractive indices for incident medium and shift for
      calculation of plus spin state */
   qccorr = correct();

   genmulti(tqcsq, mqcsq, bqcsq, tqcmsq, mqcmsq, bqcmsq,
            td, md, bd, trough, mrough, brough, tmu, mmu,
            bmu, nrough,
            ntlayer, nmlayer, nblayer, nrepeat, proftyp);

   for (
      qtemp = q, ytemp = y, j = 0;
      j < npnts;
      qtemp++, ytemp++, j++
   ) {
      qeff = (*qtemp < 1.e-10) ? 1.e-10 : *qtemp;
      *y = .5 * grefint(&qeff, &lambda, gqcsq, gmu, gd, &nglay);
   }

   /* Evaluate minus spin state reflectivity */
   minusState();

   genmulti(tqcsq, mqcsq, bqcsq, tqcmsq, mqcmsq, bqcmsq,
            td, md, bd, trough, mrough, brough, tmu, mmu,
            bmu, nrough,
            ntlayer, nmlayer, nblayer, nrepeat, proftyp);
   for (
      qtemp = q, ytemp = y, j = 0;
      j < npnts;
      qtemp++, ytemp++, j++
   ) {
      qeff = (*qtemp < 1.e-10) ? 1.e-10 : *qtemp;
      *y += .5 * grefint(&qeff, &lambda, gqcsq, gmu, gd, &nglay);
   }
   /* Un-correct */
   uncorrect(qccorr);
}


STATIC void dressReflec(int nparm, double *y, double *dy, int ndata)
{
   register int j;

   switch (nparm) {
      case 0:
         for (j = 0; j < ndata; y++, j++)
            *y = log10(fabs(bki + bmintns * (*y)));
         break;
      case NA - 1:
         for (j = 0; j < ndata; y++, j++)
            *y = 1. / fabs(bki + bmintns * (*y));
         break;
      case NA:
         for (j = 0; j < ndata; y++, j++)
            *y /= fabs(bki + bmintns * (*y));
         break;
      default:
         for (j = 0; j < ndata; j++) {
            *y = (fabs(*dy) <= 1.e-10) ? 0. :
               bmintns / fabs(bki + bmintns * (*y)) * (*dy);
            y++;
            dy++;
         }

   }
}


/* Subroutine evaluates function or derivative for reflectivity fit */
/* to log(data) and spin asymmetry */
/* John Ankner 28 March 1992 */

#include <stdio.h>
#include <math.h>
#include <genderiv4.h>
#include <delparm.h>
#include <extres.h>
#include <calcReflec.h>
#include <mancon4.h>

#include <parameters.h>
#include <cparms.h>

#include <cdata.h>
#include <genmem.h>
#include <genpsl.h>
#include <genpsc.h>
#include <genpsr.h>
#include <genpsi.h>
#include <genpsd.h>

/* Local function prototypes */
#include <static.h>

STATIC void dressReflec(int nparm, double *y, double *dy, int ndata);
STATIC void dumpExtended(double qtemp[], double *y, int npnts, int xspin[4]);

void genderiv4(double *q, double *yfit, int ndata, int nparm)
/* double q[MAXPTS], yfit[MAXPTS * 4] */
{
   double delP;
   int npnts;

   /* Generate extended function and derivative values to convolute with */
   /* instrumental resolution */
   npnts = nlow + ndata + nhigh;
   if (nparm <= NA) {

      /* Calculate extended reflectivity and derivative */

      if (nparm > 0 && nparm < NA - 1) {
         register int j, jmax;
         static double orig[NA];

         jmax = npnts * ncross;

         /* Save current parameters */
         for (j = 0; j < NA; j++)
            orig[j] = A[j];

         /* Take derivative of valid fit parameter */

         /* Evaluate reflectivity at slight positive parameter increment */
         delparm(nparm, TRUE, &delP);
         calcReflec(qtemp, dy, npnts, TRUE);
         /* delparm(nparm, FALSE, &delP); */
         for (j = 0; j < NA; j++) A[j] = orig[j];

         /* Evaluate reflectivity at slight negative parameter increment */
         delparm(nparm, FALSE, &delP);
         calcReflec(qtemp, y, npnts, TRUE);
         /* delparm(nparm, TRUE, &delP); */
         for (j = 0; j < NA; j++) A[j] = orig[j];

         /* Calculate numerical derivative */
         if (fabs(delP) < 1.e-20)
            for (j = 0; j < jmax; j++)
               y[j] = 0.;
         else
            for (j = 0; j < jmax; j++)
               y[j] = (dy[j] - y[j]) / delP;

         /* Perform convolution with instrumental resolution */
         mancon4(qtemp, lambda, lamdel, thedel, y, dy, ndata,
                 nlow, nhigh, ncross, FALSE);
      } else if (nparm != NA - 1) { /* Optimize for bg derivative: no need to calculate */
         /* Calculate reflectivity */
         calcReflec(qtemp, y, npnts, TRUE);

         /* Dump extended reflectivity when debugging */
         /* dumpExtended(qtemp, y, npnts, xspin); */

         /* Perform convolution with instrumental resolution */
         mancon4(qtemp, lambda, lamdel, thedel, y, yfit, ndata,
              nlow, nhigh, ncross, FALSE);
       }

      /* Dress with intensity factors */
      dressReflec(nparm, yfit, dy, ncross * ndata);
   } else
      puts("/** Invalid NPARM **/");
}


STATIC void dressReflec(int nparm, double *y, double *dy, int ndata)
{
   register int j;

   /* Dress with intensity factors */
   switch (nparm) {
      case 0:
         /* Reflectivity */
         for (j = 0; j < ndata ; j++)
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
            y[j] /= (fabs(bki + bmintns * y[j]));
          */
         break;
      default:
         /* Derivative of internal parameters */
         for (j = 0; j < ndata; j++)
            y[j] = (fabs(dy[j]) <= 1.e-10) ?
                   0. :
                   bmintns * dy[j];
               /* Bug found Tue Apr 18 11:00:14 EDT 2000 KOD */
               /* Original code did not have noff[n] in index */
               /* if (fabs(dy[j]) <= 1.e-10) y[j] = 0.; */

   }
}


STATIC void dumpExtended(double qtemp[], double *y, int npnts, int xspin[4])
{
   static char datfile[] = "mltmp.ex ";
   FILE *unit34;
   register int xsec, n;

   for (xsec = 0; xsec < 4; xsec++)
      if (xspin[xsec]) {
         datfile[sizeof(datfile) - 2] = (char) xsec + 'a';
         unit34 = fopen(datfile, "w");
         for (n = 0; n < npnts; n++)
            fprintf(unit34, "%15.7G\t%15.7g\n", qtemp[n],
               bki + bmintns * (*y++));
         fclose(unit34);
      }
}


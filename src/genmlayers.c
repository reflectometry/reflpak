/* Subroutine generates layer profile for the refractive indices QCSQ,
   absorptions MU, and roughnesses ROUGH specified
   by the fit program by explicitly calculating the roughnesses of the
   interfacial regions as variations of average QCSQ and MU on a hyperbolic
   tangent or error function profile [see Anastasiadis, Russell, Satija, and
   Majkrzak, J. Chem. Phys. 92, 5677 (1990)]
   John Ankner 14-June-1990 */

#include <stdio.h>
#include <math.h>
#include <genmlayers.h>
#include <derf.h>
#include <gAverage.h>

#include <parameters.h>
#include <glayd.h>
#include <glayi.h>


/* Local function prototypes */
#include <static.h>

STATIC void makeOverlapStep(double dist, register int j, register int nglay,
   double qcsq[], double d[], double rough[], double mu[], char proftyp);
STATIC double overlapAverage(double param[], register int j, double texpfac,
   double bexpfac);
STATIC void makeNonOverlapHalfStep(register int j, register int nglay,
   double qcsq[], double rough[], double mu[], double zint, double rufint);


void genmlayers(double qcsq[], double d[], double rough[], double mu[],
   int nlayer, double zint[], double rufint[], int nrough, char *proftyp)
{

   double ztot;
   register int i, j;
   double step;
   double gdmid, dist;

   /* Correct bogus input */
   for (j = 1; j <= nlayer; j++)
      if (rough[j] < 1.e-10) rough[j] = 1.e-10;

   /* Check for funny number of layers */
   if (nlayer < 1) {
      nglay = 0;
      puts("/** NLAYER must be positive **/");
   } else {
      /* Evaluate total normalized thickness of interfaces */
      ztot = 0.;
      for (j = 0; j <= nrough; j++)
          ztot += zint[j];

      /* Evaluate gradation of layers */
      for (j = 1; j < nlayer; j++) {
         /* Determine if interfaces overlap */
         if (j < nlayer) /* Conditional always evaluates true! KOD 3/1/2000 */
            gdmid = d[j] - .5 * ztot * (rough[j] + rough[j + 1]);
         else if (j == nlayer) { /* Else statement never executed */
            gdmid = d[j] - .5 * ztot * rough[j];
            if (gdmid <= 1.) gdmid = 1.;
         }
         if (gdmid <= 1.e-10) {

            /* Overlapping interfaces---step through entire layer */
            step = d[j] / (double) (nrough + 1);
            /* Take first half step */
            gd[nglay] = step / 2.;
            dist = step / 4.;
            makeOverlapStep(dist, j, nglay, qcsq, d, rough, mu, *proftyp);
            nglay++;
            dist += .75 * step;

            /* Step through layers */
            for (i = 0; i < nrough; i++) {
               gd[nglay + i] = step;
               makeOverlapStep(dist, j, nglay + i, qcsq, d, rough, mu, *proftyp);
               dist += step;
            }
            nglay += nrough;

            /* Take final half step */
            gd[nglay] = step / 2.;
            dist = d[j] - step / 4.;
            makeOverlapStep(dist, j, nglay, qcsq, d, rough, mu, *proftyp);
            nglay++;
         } else {
            /* Evaluate contribution from each interface separately */
            register int midpoint = nrough / 2 + 1;

            /* Top-most interface */
            for (i = 0; i <= nrough - midpoint; i++)
               makeNonOverlapHalfStep(j, nglay + i, qcsq, rough, mu,
                  zint[i + midpoint], rufint[i + midpoint]);
            nglay += i;

            /* Central bulk-like portion */
               gd[nglay] = gdmid;
            gqcsq[nglay] = qcsq[j];
              gmu[nglay] = mu[j];
            nglay++;

            /* Bottom-most interface */
            for (i = 0; i <= nrough / 2; i++)
               makeNonOverlapHalfStep(j + 1, nglay++, qcsq, rough, mu, zint[i], rufint[i]);

         }
      }
   }
}


STATIC void makeOverlapStep(double dist, register int j, register int nglay,
   double qcsq[], double d[], double rough[], double mu[], char proftyp)
{
   double texpfac, bexpfac;

   if (proftyp == 'H') {
      texpfac = tanh(CT * dist / rough[j]);
      bexpfac = tanh(CT * (dist - d[j]) / rough[j + 1]);
   } else {
      texpfac = derf(CE * dist / rough[j]);
      bexpfac = derf(CE * (dist - d[j]) / rough[j + 1]);
   }
   gqcsq[nglay] = overlapAverage(qcsq, j, texpfac, bexpfac);
   gmu[nglay]   = overlapAverage(  mu, j, texpfac, bexpfac);
}


STATIC double overlapAverage(double param[], int j, double texpfac,
   double bexpfac)
{
   register double pjm1 = param[j - 1];
   register double pj   = param[j];
   register double pjp1 = param[j + 1];

   return .5 * (pjm1 + pj
           +   (pj   - pjm1) * texpfac
           +    pj   + pjp1
           +   (pjp1 - pj  ) * bexpfac)
           - pj;
}


STATIC void makeNonOverlapHalfStep(register int j, register int nglay,
   double qcsq[], double rough[], double mu[], double zint, double rufint)
{
      gd[nglay] = zint * rough[j];
   gqcsq[nglay] = gAverage(qcsq, j, rufint);
    gmu[nglay] = gAverage(  mu, j, rufint);
}


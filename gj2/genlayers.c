/* Subroutine generates layer profile for the refractive indices QCSQ, */
/* absorptions MU, and roughnesses ROUGH specified */
/* by the fit program by explicitly calculating the roughnesses of the */
/* interfacial regions as variations of average QCSQ and MU on a hyperbolic */
/* tangent or error function profile [see Anastasiadis, Russell, Satija, */
/* and Majkrzak, */
/* J. Chem. Phys. 92, 5677 (1990)] */
/* John Ankner 25 March 1992 */

/* With substitution mu->the, generates magnetic profile */

#include <stdio.h>
#include <math.h>
#include <genlayers.h>
#include <derf.h>

#include <parameters.h>

/* Local function prototypes */
#include <static.h>

STATIC void makeOverlapStep(double dist, register int j, register int nglay,
   double qcsq[], double d[], double rough[], double mu[], char proftyp,
   double gqcsq[], double gmu[]);
STATIC double overlapAverage(double param[], int j, double texpfac, double bexpfac);
STATIC int makeNonOverlapStep(int steps, register int j,
   register int offset, register int nglay,
   double rough[], double zint[], double rufint[], double qcsq[], double mu[],
   double gd[], double gqcsq[], double gmu[]);
STATIC double gAverage(double param[], int j, double rufint);


double vacThick(double *rough, double *zint, int nrough)
{
   int i;
   double thick = 0.;

   if (rough[1] > 1.e-8) {
      for (i = 0; i < nrough / 2 + 1; i++)
         thick += zint[i];
      thick *= rough[1];
   } else
      thick = 1.e-10;

   return thick;
}


int genlayers(double *qcsq, double *d, double *rough, double *mu, int nlayer,
   double *zint, double *rufint, int nrough, char *proftyp,
   double *gqcsq, double *gmu, double *gd)
/* double qcsq[nlayer + 1], mu[nlayer + 1], d[nlayer + 1], rough[nlayer + 1]; */
/* double zint[nrough + 1], rufint[nrough + 1]; */
/* double gqcsq[MAXGEN], double gmu[MAXGEN], double gd[MAXGEN] */
{
   double step, dist, gdmid, ztot;
   register int i, j, nglay;
   int midpoint;

   /* Correct bogus input */
   for (j = 1; j <= nlayer; j++)
      if (rough[j] < 1.e-10) rough[j] = 1.e-10;

   /* Check for funny number of layers */
   nglay = 0;
   if (nlayer < 1) {
      puts("/** NLAYER must be positive **/");
      return nglay;
   }

   /* Evaluate total normalized thickness of interfaces */
   ztot = 0.;
   for (j = 0; j <= nrough; j++)
      ztot += zint[j];

   midpoint = nrough / 2 + 1;

   /* Evaluate vacuum gradation */
      gd[nglay] = 1.e-10;
     gmu[nglay] =   mu[0];
   gqcsq[nglay] = qcsq[0];
   nglay++;
   if (rough[1] > 1.e-8) {
      /* Construct graded interface */
      nglay += makeNonOverlapStep(midpoint, 1, 0, nglay, rough, zint, rufint,
         qcsq, mu, gd, gqcsq, gmu);
   } else {
      /* Construct three-step interface */
         gd[nglay] = 1.e-10;
        gmu[nglay] =   mu[0];
      gqcsq[nglay] = qcsq[0];
      nglay++;
   }

   /* Evaluate gradation of layers */
   for (j = 1; j <= nlayer; j++) {
      /* Determine if interfaces overlap */
      if (j < nlayer)
         gdmid = d[j] - .5 * ztot * (rough[j] + rough[j + 1]);
      else {
         gdmid = d[j] - .5 * ztot * rough[j];
         if (gdmid <= 1.) gdmid = 1.;
      }
      if (gdmid <= 1.e-10) {
         /* Overlapping interfaces---step through entire layer */
         step = d[j] / (double) (nrough + 1);
         /* Take first half step */
         gd[nglay] = step / 2.;
         dist = step / 4.;
         makeOverlapStep(dist, j, nglay, qcsq, d, rough, mu, proftyp[0],
            gqcsq, gmu);
         nglay++;

         /* Step through layers */
         dist += .75 * step;
         /* Should be nrough + 1? KOD Fri Apr 21 19:23:41 EDT 2000 */
         for (i = 0; i < nrough; i++) {
            gd[nglay + i] = step;
            makeOverlapStep(dist, j, nglay + i, qcsq, d, rough, mu, proftyp[0],
               gqcsq, gmu);
            dist += step;
         }
         nglay += nrough;
         /* Take final half step */
         gd[nglay] = step / 2.;
         dist = d[j] - step / 4.;
         makeOverlapStep(dist, j, nglay, qcsq, d, rough, mu, proftyp[0], gqcsq, gmu);
         nglay++;
      } else {
         /* Evaluate contribution from each interface separately */

         /* Top-most interface */
         if (rough[j] > 1.e-8) {
            /* Construct graded interface */
            nglay += makeNonOverlapStep(nrough + 1 - midpoint, j, midpoint,
               nglay, rough, zint, rufint, qcsq, mu, gd, gqcsq, gmu);
         } else {
            /* Construct three-step interface */
               gd[nglay] = 1.e-10;
              gmu[nglay] =   mu[j];
            gqcsq[nglay] = qcsq[j];
            nglay++;
         }
         /* Central bulk-like portion */
            gd[nglay] = gdmid;
           gmu[nglay] = mu[j];
         gqcsq[nglay] = qcsq[j];
         nglay++;

         /* Bottom-most interface */

         if (j < nlayer) {
            /* Next interface exists */
            if (rough[j + 1] > 1.e-8) {
               /* Construct graded interface */
               nglay += makeNonOverlapStep(midpoint, j + 1, 0, nglay, rough,
                  zint, rufint, qcsq, mu, gd, gqcsq, gmu);
            } else {
               /* Construct three-step interface */
                  gd[nglay] = 1.e-10;
                 gmu[nglay] =   mu[j];
               gqcsq[nglay] = qcsq[j];
               nglay++;
            }
         } else nglay--;
      }
   }
   return nglay;
}


STATIC void makeOverlapStep(double dist, register int j, register int nglay,
   double qcsq[], double d[], double rough[], double mu[], char proftyp,
   double gqcsq[], double gmu[])
{
   double texpfac, bexpfac;

   if (proftyp == 'H') {
      texpfac = tanh(CT * dist / rough[j]);
      bexpfac = tanh(CT * (dist - d[j]) / rough[j + 1]);
   } else {
      texpfac = derf(CE * dist / (double) rough[j]);
      bexpfac = derf(CE * (dist - d[j]) / rough[j + 1]);
   }
   gqcsq[nglay] = overlapAverage(qcsq, j, texpfac, bexpfac);
     gmu[nglay] = overlapAverage(  mu, j, texpfac, bexpfac);
}


STATIC double overlapAverage(double param[], int j, double texpfac, double bexpfac)
{
   register double pjm1 = param[j - 1];
   register double pj   = param[j];
   register double pjp1 = param[j + 1];

   return .5 * (pjm1 + pj
           +   (pj - pjm1) * texpfac
           +    pj + pjp1
           +   (pjp1 - pj) * bexpfac)
           - pj;
}


STATIC int makeNonOverlapStep(int steps, register int j,
   register int offset, register int nglay,
   double rough[], double zint[], double rufint[], double qcsq[], double mu[],
   double gd[], double gqcsq[], double gmu[])
{
   register int i;

   for (i = 0; i < steps; i++) {
         gd[nglay] = zint[i + offset] * rough[j];
      gqcsq[nglay] = gAverage(qcsq, j, rufint[i + offset]);
        gmu[nglay] = gAverage(  mu, j, rufint[i + offset]);
      nglay++;
   }
   return steps;
}


STATIC double gAverage(double param[], int j, double rufint)
{
   return .5 * (
      param[j] + param[j - 1]
      + (param[j] - param[j - 1]) * rufint
   );
}


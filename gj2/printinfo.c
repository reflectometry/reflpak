/* Generates output */

#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <complex.h>
#include <printinfo.h>
#include <genva.h>
#include <genlayers.h>
#include <ngenlayers.h>
#include <mgenlayers.h>
#include <gmagpro4.h>
#include <calcReflec.h>
#include <copyBasename.h>
#include <loadData.h>
#include <noFile.h>
#include <genderiv4.h>
#include <extres.h>
#include <queryString.h>
#include <cleanFree.h>

#include <parameters.h>
#include <cdata.h>
#include <mglayd.h>
#include <nglayd.h>
#include <glayim.h>
#include <glayin.h>
#include <glayd.h>
#include <glayi.h>
#include <clista.h>
#include <genpsr.h>
#include <genpsl.h>
#include <genpsc.h>
#include <genpsi.h>
#include <genpsd.h>

/* Local function prototypes */
#include <static.h>

STATIC void printLimit(char *xsec, double qmin, double qmax, int npnts);
STATIC int selectFilename(char *filnam, char *outfile, char *infile,
   char *extension);
STATIC void printReflect(double q4x[], double *y4x, int npnts);
STATIC void printAmplitude(double q4x[], complex *yfita, int npnts);
STATIC int isvtterm(FILE *stream);


/* Module variables */
static const char *fourfloat = "%#15.7G%#15.7G%#15.7G%#15.7G\n";
#define threefloat (fourfloat + 7)
#define twofloat (threefloat + 7)
static const char *oneFloatOneC = "%#15.7G ( %#15.7G, %#15.7G )\n";


STATIC int isvtterm(FILE *stream)
{
   char *term;

   return (
      isatty(fileno(stream)) &&
      (term = getenv("TERM")) != NULL &&
      (
         strncmp(term, "vt", 2) == 0 ||
         strncmp(term, "xterm", 5) == 0
      )
   );
}


STATIC void printLimit(char *xsec, double qmin, double qmax, int npnts)
{
   printf(" QLimits NPnts for %s: %#15.7G%#15.7G%5d\n",
          xsec, qmin, qmax, npnts);
}


int printLayers(char *command)
{
   register int j;
   char *s;
   double *values;
   int vtterm;

   static const char *boldon = "\x1B[0;1m";
   static const char *boldoff = "\x1B[0m";
   static const double one[] = { 1., 1. };

   vtterm = isvtterm(stdout);

   /* Values or uncertainties */
   values = (command[2] == 'U' || command[3] == 'U') ? DA : A;

   if (command[2] != 'M') {
      puts("        QC        D     RO      MU"
           "         QM        DM    RM    TH\n");
      if (vtterm) fputs(boldon, stdout);
      printf(" %2d %#10.3G             %#10.3G\n", 0, values[QC], values[MU]);
      for (j = 1; j <= nlayer; j++) {
         if (vtterm && (j & 1)) fputs((j & 2) ? boldon : boldoff, stdout);
         printf(" %2d "
                "%#10.3G"
                "%#7.1f"
                "%#6.1f"
                "%#10.3G "
                "%#10.3G "
                "%#7.1f"
                "%#6.1f "
                "%#5.1f  "
                "%2d\n",
                j, values[QC + j], values[D + j], values[RO + j],
                values[MU + j], values[QM + j], values[DM + j], values[RM + j],
                values[TH + j], j);
      }
      if (vtterm) fputs(boldoff, stdout);
   } else {
      puts("        QM       DM    RM    TH");
      for (j = 1; j <= nlayer; j++) {
         if (vtterm && (j & 1)) fputs((j & 2) ? boldon : boldoff, stdout);
         printf(" %2d %#10.3G %#7.1f%#6.1f %#5.1f\n",
                 j, values[QM + j], values[DM + j], values[RM + j],
                 values[TH + j]);
      }
      if (vtterm) fputs(boldoff, stdout);
   }
   printf(" NLayers %5d\n", nlayer);
   printf(" NRough PRofile %5d  %s   ztot %#.7G\n", nrough,
      (proftyp[0] == 'E' ? "erf" : "tanh"), vacThick((double *)one, zint, nrough));
   printf(" WaveLength %#15.7G\n", lambda);
   if (aspin) printLimit("++ (a)", qmina, qmaxa, npntsa);
   if (bspin) printLimit("+- (b)", qminb, qmaxb, npntsb);
   if (cspin) printLimit("-+ (c)", qminc, qmaxc, npntsc);
   if (dspin) printLimit("-- (d)", qmind, qmaxd, npntsd);
   printf(" InFile, OutFile, Pol. State %-15s %-15s  %s\n", infile, outfile, polstat);
   printf(" ParmFile %s\n", parfile);
   printf(" Delta Lambda,  Delta Theta %#15.7G%#15.7G\n", lamdel, thedel);
   printf(" Beam Intensity and BacKground %#15.7G%#15.7G\n", values[BI],
      values[BK]);
   genva(listA, mfit, fitlist);
   s = strtok(fitlist,"\n");
   printf(" VAry %s\n", s);
   for (s = strtok(NULL,"\n"); s != NULL; s = strtok(NULL, "\n"))
      printf("        %s\n", s);

   return FALSE;
}


int listData(void)
{
   register int j, ntot, xsec;
   int jmax;

   puts("      XDAT           YDAT           SRVAR    YFIT");

   j = 0;
   jmax = 0;
   ntot = 0;
   for (xsec = 0; xsec < 4; xsec++) {
      jmax += npntsx[xsec];
      for (; j < jmax; j++)
{
printf("%d ", j-ntot);
         printf(fourfloat, xdat[j], ydat[j], srvar[j],
                           yfit[nqx[xsec][j - ntot]]);
}
      ntot = jmax;
   }
   return FALSE;
}


int genReflect(char *command)
{
   int failed = FALSE;
   int npnts;
   register int n;
   double qmin, qmax, qi;
   register double qstep;


   /* Determine number of points and spacing */
   npnts = 0;
   for (n = 0; npnts == 0 && n < 4; n++)
      if (xspin[n]) {
         npnts = npntsx[n];
         qmin = qminx[n];
         qmax = qmaxx[n];
      }

   if (npnts < 1) {
      puts("/** NPNTS must be positive **/");
      failed = TRUE;
      return failed;
   }

   /* Make sure q4x is defined */
   cleanFree((void **) (&q4x));
   q4x = (double *) malloc(sizeof(double) * npnts);

   if (q4x == NULL) {
      puts("/** Cannot get memory for q4x **/");
      failed = TRUE;
      return failed;
   }

   /* Calculate profile */
   n4x = npnts;
   qstep = (npnts == 1) ? 0. : (qmax - qmin) / (double) (npnts - 1);
   qi = qmin;
   for (n = 0; n < npnts; n++) {
      q4x[n] = qi;
      qi += qstep;
   }
   /* Calculate profile */
   if (command[1] == 'A') {
      /* Make sure yfita is defined */
      cleanFree((void **) (&yfita));  
      yfita = (complex *) malloc(sizeof(complex) * ncross * npnts);

      if (yfita == NULL) {
         puts("/** Cannot get memory for yfita **/");
         failed = TRUE;
         return failed;
      } else {
         calcReflec(q4x, yfita, npnts, FALSE);
         printAmplitude(q4x, yfita, npnts);
      }
   } else {
      /* Make sure y4x is defined */
      cleanFree((void **) (&y4x));
      y4x = (double *) malloc(sizeof(double) * ncross * npnts);
      if (y4x == NULL) {
         puts("/** Cannot get memory for y4x **/");
         failed = TRUE;
         return failed;
      } else {
         calcReflec(q4x, y4x, npnts, TRUE);
         printReflect(q4x, y4x, npnts);
      }
   }
   return failed;
}


STATIC void printReflect(double q4x[], double *y4x, int npnts)
{
   register int n, xsec;

   for (xsec = 0; xsec < 4; xsec++) {
      if (xspin[xsec]) for (n = 0; n < npnts; n++) {
         *y4x = log10(*y4x);
         printf(twofloat, q4x[n], *(y4x++));
      }
   }
}


STATIC void printAmplitude(double q4x[], complex *yfita, int npnts)
{
   register int n, xsec;

   for (xsec = 0; xsec < 4; xsec++) {
      if (xspin[xsec]) for (n = 0; n < npnts; n++) {
         printf(oneFloatOneC, q4x[n], yfita->real, yfita->imag);
         yfita++;
      }
   }
}


STATIC int selectFilename(char *filnam, char *outfile, char *infile,
   char *extension)
{
   int l;

   l = copyBasename(filnam, outfile);
   if (l == 0) l = copyBasename(filnam, infile);
   strcat(filnam, extension);
   l += strlen(extension);
   filnam[l] = ' ';
   filnam[l + 1] = 0;
   return l;
}


int genProfile(char *command)
{
   int failed = FALSE;
   int l;
   int save;
   register int n;
   double thick;
   FILE *unit1 = NULL, *unit2 = NULL, *unit3 = NULL;

   save = (*command == 'S');
   ngenlayers(qcsq, d, rough, mu, nlayer, zint, rufint, nrough, proftyp);
   mgenlayers(qcmsq, dm, mrough, the, nlayer, zint, rufint, nrough, proftyp);
   gmagpro4();
   switch (command[3]) {
      case 0:
         puts("  Layer       QCNSQ        QCMSQ        MU"
              "         D           THE");
         for (n = 0; n <= nglay; n ++)
            printf("%5i      %#10.3G  %#10.3G  %#10.3G  %#10.3G  %#10.3G\n",
                     n + 1, gqcsq[n], gqmsq[n], gmu[n], gd[n], gthe[n]);
         if (save) {
            /* Save layer profiles to OUTFILEs */
            l = selectFilename(filnam, outfile, infile, ".pro");
            /* Open output files for nuclear Qc, magnetic Qc, Theta angle, */
            filnam[l] = 'n';
            unit1 = fopen(filnam, "w");
            if (unit1 == NULL) {
               noFile(filnam);
               failed = TRUE;
            }
            filnam[l] = 'm';
            unit2 = fopen(filnam, "w");
            if (unit2 == NULL) {
               noFile(filnam);
               failed = TRUE;
            }
            filnam[l] = 't';
            unit3 = fopen(filnam, "w");
            if (unit3 == NULL) {
               noFile(filnam);
               failed = TRUE;
            }
            if (!failed) {
               thick = 0.;
               /* Bug found: should be nglay, was nglayn */
               for (n = 0; n <= nglay; n++) {
                  fprintf(unit1, twofloat, thick, gqcsq[n]);
                  fprintf(unit2, twofloat, thick, gqmsq[n]);
                  fprintf(unit3, twofloat, thick, gthe[n]);
                  thick += gd[n];
                  fprintf(unit1, twofloat, thick, gqcsq[n]);
                  fprintf(unit2, twofloat, thick, gqmsq[n]);
                  fprintf(unit3, twofloat, thick, gthe[n]);
               }
            }
            if (unit1 != NULL) fclose(unit1);
            if (unit2 != NULL) fclose(unit2);
            if (unit3 != NULL) fclose(unit3);
            /* if (unit4 != NULL) fclose(unit4); */
         }
         break;
      case 'A':
      case 'B':
      case 'C':
      case 'D':
         /* Save layer profile to OUTFILE */
         l = selectFilename(filnam, outfile, infile, ".pro");
         filnam[l] = command[3] + 'a' - 'A';
   
         /* Open output file */
         unit1 = fopen(filnam, "w");
         if (unit1 == NULL) {
            noFile(filnam);
            failed = TRUE;
         } else {
            thick = 0.;
            switch (command[3]) {
               case 'A':
                  for (n = 0; n <= nglay; n++) {
                     fprintf(unit1, twofloat, thick, gqcsq[n] + gqmsq[n] * sin(M_PI / 180. * gthe[n]));
                     thick += gd[n];
                     fprintf(unit1, twofloat, thick, gqcsq[n] + gqmsq[n] * sin(M_PI / 180. * gthe[n]));
                  }
                  break;
               case 'B':
               case 'C':
                  for (n = 0; n <= nglay; n++) {
                     fprintf(unit1, twofloat, thick, gqmsq[n] * cos(M_PI / 180. * gthe[n]));
                     thick += gd[n];
                     fprintf(unit1, twofloat, thick, gqmsq[n] * cos(M_PI / 180. * gthe[n]));
                     }
                  break;
               case 'D':
                  for (n = 0; n <= nglay; n++) {
                     fprintf(unit1, twofloat, thick, gqcsq[n] - gqmsq[n] * sin(M_PI / 180. * gthe[n]));
                     thick += gd[n];
                     fprintf(unit1, twofloat, thick, gqcsq[n] - gqmsq[n] * sin(M_PI / 180. * gthe[n]));
                  }
                  break;
            }
            fclose(unit1);
         }
         break;
      case 'O':
         /* Save layer profiles to OUTFILEs */
         l = selectFilename(filnam, outfile, infile, ".pro");
         filnam[l] = 'N';
         unit1 = fopen(filnam, "w");
         if (unit1 == NULL) {
            noFile(filnam);
            failed = TRUE;
         } else {
            thick = 0.;
            for (n = 0; n <= nglayn; n++) {
               fprintf(unit1, threefloat, thick, gqcnsq[n], gmun[n]);
               thick += gdn[n];
               fprintf(unit1, threefloat, thick, gqcnsq[n], gmun[n]);
            }
            fclose(unit1);
         }
         filnam[l] = 'M';
         unit1 = fopen(filnam, "w");
         if (unit1 == NULL) {
            noFile(filnam);
            failed = TRUE;
         } else {
            thick = 0.;
            for (n = 0; n < nglaym; n++) {
               fprintf(unit1, threefloat, thick, gqcmsq[n], gthem[n]);
               thick += gdm[n];
               fprintf(unit1, threefloat, thick, gqcmsq[n], gthem[n]);
            }
            fclose(unit1);
         }
         break;
      default:
         failed = TRUE;

   }
   return failed;
}


int saveTemps(char *outfile, int xspin[4], void *fit, int npnts, int cmplx)
{
   int failed = FALSE;
   int l, xsec;
   register int n;
   register double *rfit = (double *) fit;
   register complex *cfit = (complex *) fit;
   FILE *unit1;

   l = selectFilename(filnam, outfile, infile, ".gen");
   filnam[l + 1] = 0;
   for (xsec = 0; xsec < 4; xsec++) {
      if (xspin[xsec]) {
         filnam[l] = (char) xsec + 'a';
         unit1 = fopen(filnam, "w");
         if (unit1 == NULL) {
            noFile(filnam);
            failed = TRUE;
            break;
         }
         if (cmplx) {
            for (n = 0; n < npnts; n++) {
               fprintf(unit1, oneFloatOneC, q4x[n], cfit->real, cfit->imag);
               cfit++;
            }
         } else {
            for (n = 0; n < npnts; n++)
               fprintf(unit1, twofloat, q4x[n], *(rfit++));
         }
         fclose(unit1);
      }
   }
   return failed;
}


int printDerivs(char *command, int npnts)
{
   int failed;
   int l, np;
   register int n;
   double qmin, qmax;
   register double qstep;

   if (strcmp(command, "RD") == 0) {
      char *string;

      /* Generate specified derivative */
      string = queryString("Enter parameter number: ", NULL, 0);
      if (string) sscanf(string, "%d\n", &np);
/* Bug! should be else */
   }
   np = 0;
   /* Read in data */
   failed = loadData(infile, xspin);
   if (failed) return failed;

   /* Generate ordinate array */
   qmin = q4x[0];
   qmax = q4x[n4x - 1];
   qstep = (n4x <= 1) ? 0. : (qmax - qmin) / (double) (n4x - 1);
   for (n = 0; n < n4x; n++)
      xtemp[n] = (double) n * qstep + qmin;

   /* Calculate reflectivity or derivative */
   if (extend(xtemp, n4x, lambda, lamdel, thedel) != NULL) {
      int nc;
      register double *Y4x;
      FILE *unit1;

      genderiv4(xtemp, y4x, n4x, np);

      /* Output */
      Y4x = y4x;
      for (nc = 0; nc < ncross; nc++)
         for (n = 0; n < n4x; n++)
            printf(twofloat, xtemp[n], *(Y4x++));

      if (strcmp(command, "SRF") == 0) {
         /* Send to appropriate output files */
         l = selectFilename(filnam, outfile, infile, ".fit");
         Y4x = y4x;
         for (nc = 0; nc < ncross; nc++) {
            filnam[l] = polstat[nc];
            unit1 = fopen(filnam, "w");
            for (n = 0; n < n4x; n++)
                fprintf(unit1, twofloat, xtemp[n], *(Y4x++));
            fclose(unit1);
         }
      }
   } else failed = TRUE;
   return failed;
}


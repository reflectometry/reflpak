/* Generates output */

#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include <complex.h>
#include <stdio.h>
#include <string.h>

#include "printinfo.h"
#include "badInput.h"
#include "genvac.h"
#include "genmulti.h"
#include "grefamp.h"
#include "grefint.h"
#include "lenpre.h"
#include "lenc.h"
#include "extres.h"
#include "genderiv.h"
#include "gensderiv.h"
#include "noFile.h"

/* Global data */
#include "parameters.h"
#include "cparms.h"
#include "cdata.h"

#include "genva.h"
#include "clista.h"
#include "glayi.h"
#include "glayd.h"
#include "genpsc.h"
#include "genpsl.h"
#include "genpsr.h"
#include "genpsi.h"
#include "genpsd.h"

/* Local function prototypes */
#include "static.h"

STATIC void printLayer(char layer, double qcsq[], double d[], double rough[],
   double mu[], int nlayer);
STATIC double correct(void);
STATIC void uncorrect(double qccorr);
STATIC int isvtterm(FILE *stream);


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


STATIC void printLayer(char layer, double qcsq[], double d[],
   double rough[], double mu[], int nlayer)
{
   register int j;
   int vtterm;

   static const char *boldon = "\x1B[0;1m";
   static const char *boldoff = "\x1B[0m";

   vtterm = isvtterm(stdout);

   printf(" %c      QC        D         RO        MU\n", layer);
   for (j = 1; j <= nlayer; j++) {
      if (vtterm && (j &1)) fputs((j & 2) ? boldon : boldoff, stdout);
      printf(" %1d %#10.3G%#10.3G%#10.3G%#10.3G\n",
         j, qcsq[j], d[j], rough[j], mu[j]);
   }
   if (vtterm) fputs(boldoff, stdout);
}


int printLayers(char *command)
{
   int printUnc;

   static const double one[] = { 1., 1. };

   /* Values or uncertainties */
   printUnc = (command[2] == (char) 'U' || command[3] == (char) 'U');

   if (*command == 'T' || *command == 'V') {
      puts(" V      QC                            MU");
      printf("   %#10.3G                    %#10.3G\n",
      tqcsq[0], tmu[0]);
      if (printUnc) 
         printLayer('T', Dtqcsq, Dtd, Dtrough, Dtmu, ntlayer);
      else
         printLayer('T', tqcsq, td, trough, tmu, ntlayer);
      printf(" NTLayers %5d\n", ntlayer);
   }
   if (*command == 'M' || *command == 'V') {
      if (printUnc)
         printLayer('M', Dmqcsq, Dmd, Dmrough, Dmmu, nmlayer);
      else
         printLayer('M', mqcsq, md, mrough, mmu, nmlayer);
      printf(" NMLayers  Num. Multi. Repeats%5d%5d\n", nmlayer, nrepeat);
   }
   if (*command == 'B' || *command == 'V') {
      if (printUnc)
         printLayer('B', Dbqcsq, Dbd, Dbrough, Dbmu, nblayer);
      else
         printLayer('B', bqcsq, bd, brough, bmu, nblayer);
      printf(" NBLayers %5d\n", nblayer);
   }
   printf(" NRough PRofile %5d  %s   ztot %#.7G\n", nrough,
      (*proftyp == 'E' ? "erf" : "tanh"), vacThick((double *)one, zint, nrough));
   printf(" WaveLength %#15.7G\n", lambda);
   printf(" QLimits NPnts%#15.7G%#15.7G%5d\n", qmin, qmax, npnts);
   printf(" InFile, OutFile %-30s %-30s\n", infile, outfile);
   printf(" ParmFile %s\n", parfile);
   printf(" Delta Lambda, Delta Theta %#15.7G%#15.7G\n", lamdel, thedel);
   printf(" Beam Intensity and BacKground %#15.7G%#15.7G\n",
       (printUnc ? Dbmintns : bmintns), (printUnc ? Dbki : bki));
   genva(listA, mfit, fitlist);
   printf(" VAry%s\n", fitlist);

   return FALSE;
}


int listData(void)
{
   register int j;

   if (loaded) {
     puts("      xdat           ydat           srvar      yfit");
     for (j = 0; j < npnts; j++)
       printf("%#15.7G%#15.7G%#15.7G%#15.7G\n",
	      xdat[j], ydat[j], srvar[j], yfit[j]);
   } else {
     puts("use GD to load the data first");
   }
   return FALSE;
}


int genReflect(char *command)
{
   int failed = FALSE;
   register int j;
   double r;
   double qi, qstep, qccorr;
   FILE *file;
   complex cr;

    if (npnts < 1)
       puts("/** NPNTS must be positive **/");
    else {
      qi = qmin;
      qstep = (npnts <= 1) ? 0. : (qmax - qmin) / (double) (npnts - 1);
      qccorr = correct();
      genmulti(tqcsq, mqcsq, bqcsq, tqcmsq, mqcmsq, bqcmsq,
               td, md, bd,
               trough, mrough, brough, tmu, mmu, bmu,
               nrough, ntlayer, nmlayer, nblayer, nrepeat, proftyp);
      uncorrect(qccorr);

      if (strcmp(command, "SA") == 0) {
         file = fopen(outfile, "w");
         if (file == NULL) {
            noFile(outfile);
            failed = TRUE;
            return failed;
         }
      }
      for (j = 0; j < npnts; j++) {
         if (strcmp(command, "GR") == 0) {
            r = log10(grefint(&qi, &lambda, gqcsq, gmu, gd, &nglay));
            printf("%.15f %.15f\n", qi, r);
            xtemp[j] = qi;
            ytemp[j] = r;
        } else if (strcmp(command, "SA") == 0) {
           /* Generate amplitude of reflectivity */
/*           cr = grefamp(&qi, &lambda, gqcsq, gmu, gd, &nglay); */
           grefamp(&qi, &lambda, gqcsq, gmu, gd, &nglay, &(cr.real), &(cr.imag));
           printf("%.15f\t(%.15f,%.15f)\n", qi, cr.real, cr.imag);
           fprintf(file, "%.15f\t( %.15f, %.15f )\n", qi, cr.real, cr.imag);
        }
        qi += qstep;
      }
      if (strcmp(command, "SA") == 0)
         fclose(file);
   }
   return failed;
}


int genProfile(void)
{
   register int j;

   genmulti(tqcsq, mqcsq, bqcsq, tqcmsq, mqcmsq, bqcmsq,
            td, md, bd,
            trough, mrough, brough, tmu, mmu, bmu,
            nrough, ntlayer, nmlayer, nblayer, nrepeat, proftyp);
   puts("  Layer       QCSQ           MU            D      ");
   for (j = 0; j <= nglay; j++)
       printf("%5d%#15.7G%#15.7G%#15.7G\n", j + 1, gqcsq[j], gmu[j], gd[j]);

   return FALSE;
}


/* Module variables */
static char filnam[30+1];

int saveProfile(char *command)
{
   int failed = FALSE;
   int l;
   register int i, j;
   FILE *file;
   double thick;

   l = lenc(outfile);
   if (l > 1) {
     strncpy(filnam, outfile, l);
     filnam[l] = 0;
   } else {
     l = lenpre(infile);
     strncpy(filnam, infile, l);
     filnam[l] = 0;
     strcat(filnam, ".pro");
   }
   genmulti(tqcsq, mqcsq, bqcsq, tqcmsq, mqcmsq, bqcmsq,
            td, md, bd,
            trough, mrough, brough, tmu, mmu, bmu,
            nrough, ntlayer, nmlayer, nblayer, nrepeat, proftyp);
   puts("  Layer       QCSQ           MU            D      ");
   for (j = 0; j <= nglay; j++)
      printf("%5d%#15.7G%#15.7G%#15.7G\n",
         j + 1, gqcsq[j], gmu[j], gd[j]);
   file = fopen(filnam, "w");
   if (file == NULL) {
      noFile(filnam);
      failed = TRUE;
   } else {
      thick = 0.;
      for (i = 0; i <= nglay; i++) {
         if (strcmp(command, "SSP") == 0)
            fprintf(file, "%#.15G %#.15G %#.15G\n",
               gqcsq[i] / 50.7, -gmu[i] / (2. * lambda), gd[i]);
         else {
            fprintf(file, "%#.15G %#.15G\n", thick, gqcsq[i]);
            thick += gd[i];
            fprintf(file, "%#.15G %#.15G\n", thick, gqcsq[i]);
         }
      }
      fclose(file);
   }
   return failed;
}


int saveTemps(char *outfile)
{
   int failed = FALSE;
   FILE *file;
   register int j;

   file = fopen(outfile, "w");
   if (file == NULL) {
       noFile(outfile);
       failed = TRUE;
   } else {
      for (j = 0; j < npnts; j++)
         fprintf(file, "%#.15G %#.15G\n", xtemp[j], ytemp[j]);
      fclose(file);
   }
   return failed;
}


int printDerivs(char *command)
{
   register int j;
   int failed = FALSE;
   int l, np;
   FILE *file;
   double qstep;

   if (strcmp(command, "RD") == 0 || strcmp(command, "RSD") == 0) {
      /* Generate specified derivative */
      fputs("Enter parameter number: ", stdout);
      if (scanf("%d", &np) != 1) {
         badInput(NULL);
         failed = TRUE;
         return failed;
      }
      reflec = TRUE;
   } else {
      /* Generate reflectivity */
      np = 0;
      reflec = TRUE;
      /* Open output file */
      l = lenc(outfile);
      if (l > 1) {
         strncpy(filnam, outfile, l);
         filnam[l] = 0;
      } else {
         l = lenpre(infile);
         strncpy(filnam, infile, l);
         filnam[l] = 0;
         strcat(filnam, ".fit");
      }
      file = fopen(filnam, "w");
      if (file == NULL) {
         noFile(filnam);
         failed = TRUE;
         return failed;
      }
   }
   /* Generate ordinate array */
   qstep = (npnts <= 1) ? 0. : (qmax - qmin) / (double) (npnts - 1);
   for (j = 0; j < npnts; j++)
      xtemp[j] = (double) j * qstep + qmin;
   if (extend(xtemp, npnts, lambda, lamdel, thedel) != NULL) {
      if (strcmp(command, "RD") == 0 || strcmp(command, "SRF") == 0)
         genderiv(xtemp, yfit, npnts, np);
      else
         gensderiv(xtemp, yfit, npnts, np);
      for (j = 0; j < npnts; j++) {
         /* printf("%#.15G %#.15G\n", xtemp[j], yfit[j]); */
         if (*command == 'S')
            fprintf(file, "%#.15G %#.15G\n", xtemp[j], yfit[j]);
         /* statement has no purpose 2/25/2000 KOD */
         /* qi += qstep; */
      }
   } else failed = TRUE;
   if (*command == 'S') fclose(file);
   return failed;
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


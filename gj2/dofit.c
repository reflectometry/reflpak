extern void *MALLOC(int);

/* Fitting routine preparation and execution */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <signal.h>
#include <dofit.h>
#include <fgenm4.h>
#include <mrqmin.h>
#include <loadData.h>
#include <extres.h>
#include <lenc.h>
#include <parseva.h>
#include <genderiv4.h>
#include <genshift.h>
#include <dlconstrain.h>
#include <noFile.h>
#include <mancon4.h>
#include <copyBasename.h>
#include <cleanFree.h>
#include <genva.h>
#include <stopFit.h>
#include <plotit.h>
#include <queryString.h>

#include <cparms.h>

#include <clista.h>
#include <cdata.h>
#include <genmem.h>
#include <genpsi.h>
#include <genpsc.h>
#include <genpsr.h>
#include <genpsl.h>
#include <genpsd.h>

/* Local function prototypes */
#include <static.h>
#include "error.h"

STATIC double partialChi(int npnts, double ydat[], double srvar[],
   double y4x[], int nq[]);


int clearLista(int lista[])
{
   register int j;

   for (j = mfit - 1; j >= 0; j--)
      lista[j] = lista[j + 1];
   mfit = 0;
   return FALSE;
}


int varyParm(char *command)
{
   int failed = FALSE;
   int nc, onlist, mloc;
   register int j;

   nc = parseva(command + 2);
   if (nc >= 0 && nc < NA) {
      /* Valid parameter number */
      onlist = FALSE;
      for (j = 0; j < mfit; j++) {
         if (listA[j] == nc) {
            onlist = TRUE;
            mloc = j;
         }
      }
      if (onlist) {
         for (j = mloc; j < mfit; j++)
            listA[j] = listA[j + 1];
         mfit--;
      } else {
         listA[mfit] = nc;
         mfit++;
      }
   } else {
      ERROR("/** Invalid fit parameter number: %s **/\n", command + 2);
      failed = TRUE;
   }
   return failed;
}


STATIC double partialChi(int npnts, double ydat[], double srvar[],
   double y4x[], int nq[])
{
   double chisqx, pchisq;
   register int n;

   chisqx = 0.;
   for (n = 0; n < npnts; n++) {
      if (srvar[n] < 1.e-10) srvar[n] = 1.e-10;
      pchisq = (ydat[n] - y4x[nq[n]]) / srvar[n];
      pchisq *= pchisq;
      chisqx += pchisq;
   }
   return chisqx;
}


int calcChiSq(char *command)
{
   int failed = FALSE;
   int ntot, noff, xsec;

   /* Read in data */
   if (!loadData(infile, xspin)) {
      if (extend(q4x, n4x, lambda, lamdel, thedel) != NULL) {
         /* Calculate reflectivity */
         genderiv4(q4x, y4x, n4x, 0);

         /* Calculate chi-squared for relevant cross sections */
         chisq = 0.;
         ntot = 0;
         noff = 0;
         for (xsec = 0; xsec < 4; xsec++) {
            if (xspin[xsec]) {
               chisq += partialChi(npntsx[xsec], ydat + ntot,
                                   srvar + ntot, y4x + noff, nqx[xsec]);
	       printf("Chi-squared %c:%#15.7G; ", (char)xsec+'A', chisq / (double) (npntsx[xsec] - mfit));
               ntot += npntsx[xsec];
               noff += n4x;
            }
            if (xsec == 1 && (aspin || bspin) && (cspin || dspin))
               putc('\n', stdout);
         }
         printf("\nChi-squared: %#15.7G\n", chisq / (double) (ntot - mfit));
      } else {
         ERROR("/** Too many degrees of freedom **/");
         failed = TRUE;
      }
   }
   return failed;
}


int fitReflec(char *command)
{
   int failed = FALSE;
   int ndata;
   register int j;
   double sumsq, old_sumsq;
   void icp_fitupdate(void);

   /* Read in data */
   loadData(infile, xspin);
   ndata = npntsa + npntsb + npntsc + npntsd;
   /* Although mrqmin called with xdata, fgenm4 uses q4x for its source */
   /* of q's when calling genderiv4 */
   if (extend(q4x, n4x, lambda, lamdel, thedel) != NULL) {

      /* Fit data */
      if (ndata <= mfit) {
         puts("/** More parameters than data points **/");
         failed = TRUE;
      } else {
         /* genderiv temp data allocated by extend */
         /* Allocate data for mrqmin */
         cleanFree((void **) (&ymod));
         cleanFree((void **) (&dyda));
         ymod = MALLOC(sizeof(double) * ndata);
         dyda = MALLOC(sizeof(double) * ndata * mfit);
         if (ymod == NULL || dyda == NULL) {
            cleanFree((void **) (&ymod));
            cleanFree((void **) (&dyda));
            puts("/** Cannot allocate temporary data for fit **/");
            failed = TRUE;
         } else {
            FILE *unit99 = NULL, *gnuPipe = NULL;
            void (*oldhandler)();
            dynarray Covar, Alpha;
	    int sendgui  = 0;

            Covar.a = (double *) covar;
            Covar.row = NA;
            Covar.col = NA;
   
            Alpha.a = (double *) alpha;
            Alpha.row = NA;
            Alpha.col = NA;

            /* Setup signal handlers to interrupt fitting */
            oldhandler = signal(SIGINT, stopFit);
            abortFit = FALSE;

            /* Transfer generating parameters to fit parameters */
            genshift(a, TRUE);

            /* Check for movie request */
            if (command[2] == 'M') {
               gnuPipe = popen("gnuplot", "w");
               if (gnuPipe == NULL)
                  puts("/** Cannot initialize movie **/");
            } else {
	      sendgui = (command[2] == 'G' || command[3] == 'G');
	    }

            /* Initialize fit routine */
            alamda = -1.;
            sumsq = mrqmin(xdat, ydat, srvar, ndata, a, NA, listA, mfit,
                   Covar, Alpha, beta, NA, 0., fgenm4, &alamda, NULL);
	    if (sendgui) { ipc_fitupdate(); }
            else printf("\n Chi-squared: %#15.7G\n", sumsq / (double) (ndata - mfit));
            if (gnuPipe)
               preFitFrame(command, gnuPipe, xspin, sumsq / (double) (ndata - mfit));

            /* Apply MRQMIN until CHISQ changes by less than 5.e-4 */
            /* on successive iterations */
            old_sumsq = 2*sumsq; /* force the first step */
            while (!abortFit && fabs(sumsq - old_sumsq) > 5.e-4*sumsq) {
               old_sumsq = sumsq;
               sumsq = mrqmin(xdat, ydat, srvar, ndata, a, NA, listA, mfit,
                      Covar, Alpha, beta, NA, old_sumsq, fgenm4, &alamda, unit99);
	       if (sumsq<old_sumsq) { /* Improvement */
		 chisq = sumsq; /* update assumes global variable */
	         if (sendgui) ipc_fitupdate();
                 else printf("\n Chi-squared: %#15.7G\n", sumsq / (double) (ndata - mfit));
	       }
               if (gnuPipe)
                  fitFrame(gnuPipe, xspin, sumsq / (double) (ndata - mfit));
            }
            if (abortFit && !sendgui) puts("\nAborting the fit.");

            /* Finished--calculate covariance matrix */
            alamda = 0.;
            mrqmin(xdat, ydat, srvar, ndata, a, NA, listA, mfit,
                   Covar, Alpha, beta, NA, old_sumsq, fgenm4, &alamda, unit99);

            /* Restore signal handlers */
            signal(SIGINT, oldhandler);

            /* Close output file */
            if (unit99) {
               fputs("# End fit\n", unit99); 
	       fclose(unit99);
	    }

            /* Transfer fit parameters back to generating variables */
            /* constrain(a); */
            (*Constrain)(FALSE, a, nlayer);
            genshift(a, FALSE);
            for (j = 0; j < mfit; j++) DA[listA[j]] = sqrt(fabs(covar[j][j]));
	    if (!sendgui) {
	      for (j = 0; j < mfit; j++) {
		char varName[10];
		
		genva(listA + j, 1, varName);
		printf("%5s: %#15.7G +/- %#15.7G\n", varName, a[listA[j]],
		       DA[listA[j]]);
	      }
	    }

            /* Terminate movie */
            if (gnuPipe) {
               queryString("Press enter to terminate movie", NULL, 0);
               fputs("quit\n", gnuPipe);
               pclose(gnuPipe);
            }
         }
      }
   }
   return failed;
}


int calcExtend(int xspin[4])
{
   int failed = FALSE;
   register double qstep, qi;
   register int n;

   /* Read data from INFILEs */
   loadData(infile, xspin);

   /* Convert Q4X to an array of equal intervals */
   if (n4x <= 1) {
      puts("Not enough data points");
      failed = TRUE;
   } else {
      qstep = (q4x[n4x - 1] - q4x[0]) / (double) (n4x - 1);
      qi = q4x[0];
      for (n = 0; n < n4x; n++) {
         q4x[n] = qi;
         qi += qstep;
      }
      extres(q4x, lambda, lamdel, thedel, n4x);
      printf("Npnts: %6d\n"
             "Nlow: %6d; Qmin: %#15.7G\n"
             "Nhigh: %6d; Qmax: %#15.7G\n",
             n4x,
             nlow, q4x[0] - (double) nlow * (q4x[1] - q4x[0]),
             nhigh, q4x[n4x - 1] + (double) nhigh * (q4x[n4x - 1] - q4x[n4x - 2]));
   }
   return failed;
}

#if 0 /* Unused code, questionable algorithm */
int calcConvolve(char *polstat)
{
   int failed = FALSE;
   int l, ntot, npnts;
   double qmin, qmax;
   register int j;
   FILE *unit1;

   /* Read data from INFILEs */
   l = lenc(infile);
   strcpy(filnam, infile);
   npntsa = 0;
   npntsb = 0;
   npntsc = 0;
   npntsd = 0;
   ntot = 0;
   npnts = 0;
   aspin = FALSE;
   bspin = FALSE;
   cspin = FALSE;
   dspin = FALSE;
   for (j = 0; j < (int) strlen(polstat); j++) {
      filnam[l] = polstat[j];
      filnam[l + 1] = 0;
      unit1 = fopen(filnam, "r");
      if (unit1 == NULL) {
         noFile(filnam);
         failed = TRUE;
         break;
      }
      while (!feof(unit1)) {
         fgets(filebuf, FBUFFLEN, unit1);
         if (
            sscanf(filebuf, "%lf %lf %lf", &(xdat[npnts]),
                   &(ydat[npnts]), &(srvar[npnts])) == 3
         ) npnts++;
      }
      switch (polstat[j]) {
         case 'a':
            npntsa = npnts - ntot;
            qmin = xdat[ntot];
            qmax = xdat[npnts - 1];
            aspin = TRUE;
            break;
        case 'b':
            npntsb = npnts - ntot;
            qmin = xdat[ntot];
            qmax = xdat[npnts - 1];
            bspin = TRUE;
            if (aspin) {
              if (npntsb != npntsa) {
                puts("data files must be same size");
                failed = TRUE;
              }
            } else {
               register int nb;

               /* Shift data to appropriate location in YDAT for MANCON4 */
               for (nb = 1; nb <= npntsb; nb++)
                  ydat[npntsb + nb] = ydat[nb];
            }
            npnts = 2 * npntsb;
            break;
        case 'c':
            npntsc = npnts - ntot;
            qmin = xdat[ntot];
            qmax = xdat[npnts - 1];
            cspin = TRUE;
            if (aspin && (npntsc != npntsa)) {
              puts("data files must be same size");
              failed = TRUE;
            } else if (bspin && (npntsc != npntsb)) {
              puts("data files must be same size");
              failed = TRUE;
            } else {
               register int nc;

               /* Shift data to appropriate location in YDAT for MANCON4 */
               for (nc = 1; nc <= npntsc; nc++)
                  ydat[2 * npntsc + nc] = ydat[npntsa + npntsb + nc];
            }
            npnts = 3 * npntsc;
            break;
        case 'd':
            npntsd = npnts - ntot;
            qmin = xdat[ntot];
            qmax = xdat[npnts - 1];
            dspin = TRUE;
            if (aspin && (npntsd != npntsa)) {
              puts("data files must be same size");
              failed = TRUE;
            } else if (bspin && (npntsd != npntsb)) {
              puts("data files must be same size");
              failed = TRUE;
            } else if (cspin && (npntsd != npntsc)) {
              puts("data files must be same size");
              failed = TRUE;
            } else {
               register int nd;

               /* Shift data to appropriate location in YDAT for MANCON4 */
               for (nd = 1; nd <= npntsd; nd ++)
                  ydat[3 * npntsd + nd] = ydat[npntsa + npntsb + npntsc + nd];
            }
            npnts = 4 * npntsd;
            break;
      }
      ntot = npnts;
      fclose(unit1);
   }
   if (!failed) {
      int n, noff;

      /* n4x = sortq(xdat, npntsa, npntsb, npntsc, npntsd, q4x, nqa, nqb, nqc, nqd); */
      /****** Here I will cheat because I am still lazy ******/
      fputs("Enter nlow, nhigh: ", stdout);
      fgets(filebuf,  FBUFFLEN, stdin);
      sscanf(filebuf, "%d %d", &nlow, &nhigh);
      for (j = 0; j < npntsa; j++)
         q4x[j] = xdat[j];
      n4x = npntsa;
      mancon4(q4x, lambda, lamdel, thedel, ydat, yfit, n4x - nlow - nhigh,
                       nlow, nhigh, ncross, FALSE);
      npnts = n4x - nlow - nhigh;
      ncross = aspin + bspin + cspin + dspin;

      /* Dress with intensity factors */
      for (n = 0; n < ncross; n++) {
         noff = n * npnts;
         for (j = 0; j < npnts; j++)
            ydat[j + noff] = log10(fabs(bki + bmintns * ydat[j + noff]));
      }
      /* Send to appropriate output files */
      l = lenc(outfile);
      if (l >= 1)
         strcpy(filnam, outfile);
      else {
        l = copyBasename(filnam, infile);
        strcat(filnam, ".fit ");
        l += 4;
      }
      for (n = 0; n < ncross; n++) {
         filnam[l] = polstat[n];
         unit1 = fopen(filnam, "w");
         for (j = 0; j < npnts; j++)
            fprintf(unit1, "%#15.7G%#15.7G\n", xdat[j + nlow], ydat[j + noff]);
         fclose(unit1);
      }
   }
   return failed;
}
#endif

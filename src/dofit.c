/* Fitting routine preparation and execution */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <signal.h>
#include <dofit.h>
#include <genderiv.h>
#include <gensderiv.h>
#include <genshift.h>
#include <parseva.h>
#include <mrqmin.h>
#include <loadData.h>
#include <extres.h>
#include <cleanFree.h>
#include <stopFit.h>
#include <dlconstrain.h>
#include <plotit.h>
#include <queryString.h>

#include <cparms.h>
#include <cdata.h>
#include <clista.h>
#include <genva.h>
#include <fgen.h>
#include <fsgen.h>
#include <genmem.h>
#include <genpsl.h>
#include <genpsi.h>
#include <genpsc.h>
#include <genpsd.h>
#include <ipc.h>
#include "error.h"

#ifndef MALLOC
#define MALLOC malloc
#else
extern void* MALLOC(size_t);
#endif

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
   int nc, failed = FALSE, onlist, mloc;
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
       ERROR("/** Invalid fit parameter: %s **/\n", command + 2);
       failed = TRUE;
   }
   return failed;
}


double
calcChiSq(int n, double *fit, double *data, double *error)
{
   int j;
   double sumsq = 0.0;

   for (j=0; j < n; j++) {
      double chi = (data[j]-fit[j])/(error[j] < 1.e-10 ? 1.e-10 : error[j]);
      sumsq += chi*chi;
   }
   return sumsq;
}



int printChiSq(char *command)
{
   int failed = FALSE;

   loadData(infile);
   if (npnts - mfit < 1) {
      puts("/** Too many degrees of freedom **/");
      failed = TRUE;
   } else {
      if (extend(xdat, npnts, lambda, lamdel, thedel) != NULL) {
         reflec = TRUE;
         if (strcmp(command, "CSR") == 0) {
            genderiv(xdat, yfit, npnts, 0);
         } else {
            gensderiv(xdat, yfit, npnts, 0);
         }
         chisq = calcChiSq (npnts, yfit, ydat, srvar)/(double)(npnts-mfit);
         printf("calcChiSq Chi-squared: %#15.7G\n", chisq);
      }
   }
   return failed;
}


int fitReflec(char *command)
{
   int failed = FALSE;
   register int j;
   fitFunc func;

   reflec = TRUE;

   /* Read in data */
   loadData(infile);
   if (extend(xdat, npnts, lambda, lamdel, thedel) != NULL) {

      /* Fit data */
      if (npnts <= mfit) {
         puts("/** More parameters than data points **/");
         failed = TRUE;
      } else {
         /* genderiv temp data allocated by extend */
         /* Allocate data for mrqmin */
         cleanFree(&ymod);
         cleanFree(&dyda);
         ymod = MALLOC(sizeof(double) * npnts);
         dyda = MALLOC(sizeof(double) * npnts * mfit);
         if (ymod == NULL || dyda == NULL) {
            cleanFree(&ymod);
            cleanFree(&dyda);
            puts("/** Cannot allocate temporary data for fit **/");
            failed = TRUE;
         } else {
            FILE *unit99 = NULL, *gnuPipe = NULL;
            void (*oldhandler)(int);
            dynarray Covar, Alpha;
	    int sendgui  = 0;

            Covar.a = (double *) covar;
            Covar.row = NA;
            Covar.col = NA;

            Alpha.a = (double *) alpha;
            Alpha.row = NA;
            Alpha.col = NA;

            if (command[2] == 'S' || command[3] == 'S')
               func = fsgen;
            else func = fgen;

            /* Setup signal handlers to interrupt fitting */
            oldhandler = signal(SIGINT, stopFit);
            abortFit = FALSE;

            /* Transfer generating parameters to fit parameters */
            genshift(a, TRUE);

            /* Check for movie request */
            if (command[2] == 'M' || command[3] == 'M') {
               gnuPipe = popen("gnuplot", "w");
               if (gnuPipe == NULL)
                  puts("/** Cannot initialize movie **/");
            } else {
	      sendgui = (command[2] == 'G' || command[3] == 'G');
	    }

            /* Initialize fit routine */
            alamda = -1.;
            unit99 = mrqmin(xdat, ydat, srvar, npnts, a, NA, listA, mfit,
               Covar, Alpha, beta, NA, &chisq, func, &alamda, NULL);
	    if (sendgui) { ipc_fitupdate(); }
            else printf("\n Chi-squared: %#15.7G\n", chisq / (double) (npnts - mfit));
            if (gnuPipe)
               preFitFrame(command, gnuPipe, npnts, chisq / (double) (npnts - mfit));

            /* Apply MRQMIN until CHISQ changes by less than 5.e-3 on
               successive iterations */
            ochisq = 1.e20;
            while (!abortFit && fabs(1.0 - ochisq / chisq) > 5.e-3) {
               ochisq = chisq;
               mrqmin(xdat, ydat, srvar, npnts, a, NA, listA, mfit,
                  Covar, Alpha, beta, NA, &chisq, func, &alamda, unit99);
	       if (sendgui) { ipc_fitupdate(); }
               else printf("\n Chi-squared: %#15.7G\n", chisq / (double) (npnts - mfit));
               if (gnuPipe)
                  fitFrame(gnuPipe, npnts, chisq / (double) (npnts - mfit));
               if (chisq < 1.e-10) chisq = 1.e-10;
            }
            if (abortFit && !sendgui) puts("\nAborting the fit.");

            /* Finished--calculate covariance matrix */
            alamda = 0.;
            mrqmin(xdat, ydat, srvar, npnts, a, NA, listA, mfit,
               Covar, Alpha, beta, NA, &chisq, func, &alamda, unit99);

            /* Restore signal handlers */
            signal(SIGINT, oldhandler);

            /* Close output file */
            if (unit99) {
               fputs("# End fit\n", unit99);
	       fclose(unit99);
	    }

            /* Transfer fit parameters back to generating variables */
            /* constrain(a); */
            (*Constrain)(FALSE, a, ntlayer, nmlayer, nrepeat, nblayer);
            genshift(a, FALSE);
	    for (j = 0; j < mfit; j++) DA[listA[j]] = sqrt(fabs(covar[j][j]));
	    if (!sendgui) {
            for (j = 0; j < mfit; j++) {
               char varName[10];

               genva(listA + j, 1, varName);
               printf("%7s: %#15.7G +/- %#15.7G\n", varName, a[listA[j]], /*ARRAY*/
                  DA[listA[j]]); /*ARRAY*/
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


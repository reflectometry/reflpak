/* Loads data from file */

#include <stdio.h>
#include <string.h>
#include <loadData.h>
#include <allocData.h>
#include <lenc.h>
#include <sortq.h>
#include <noFile.h>
#include <linebuf.h>

#include <genpsi.h>
#include <genpsc.h>
#include <genpsr.h>
#include <cparms.h>
#include <cdata.h>

#include <math.h>
#include "error.h"

#define LN10 2.30258509299404568402  /* log_e 10 */

/* If the data is substantially negative (more than 70%), then assume
   that it is log data.  If it is log data which isn't negative, then
   it is not reflectivity.  If it is linear data which is mostly negative,
   then it isn't worth fitting.
*/
void log2lin(int n, double *x, double *y, double *dy)
{
  int i,neg;

  neg = 0;
  for (i=0; i < n; i++) if (y[i] < 0) neg++;
  if (neg > (n*7)/10) {
    for (i=0; i < n; i++) {
      y[i] = exp(LN10 * y[i]);
      dy[i] = y[i] * dy[i]/LN10;
    }
  }
}

int loadData(char *infile, int xspin[4])
{
   int failed = FALSE;
   int l, npnts, ntot, nc;
   int nsecx[4];  /* nsecx: map from nc to spec'd xsecs */
   register int xsec;
   LINEBUF unitx[4];

   l = lenc(infile);
   strcpy(filnam, infile);
   filnam[l + 1] = 0;

   npntsa = 0;
   npntsb = 0;
   npntsc = 0;
   npntsd = 0;

   nc = 0;
   for (xsec = 0; xsec < 4; xsec++) {
      if (xspin[xsec]) {
         filnam[l] = (char) (xsec) + 'a';
         if (openBuf(filnam, "r", unitx + nc, FBUFFLEN) == NULL) {
	    filnam[l] = (char) (xsec) + 'A';
	    if (openBuf(filnam, "r", unitx + nc, 0) == NULL) {
               noFile(filnam);
               failed = TRUE;
               for (nc--; nc >= 0; nc--)
                  closeBuf(unitx + nc, 0);
               break;
	    }
         }
	 nsecx[nc++] = xsec;
      }
   }
   if (!failed) {
      npnts = 0;
      for (xsec = 0; xsec < ncross; xsec++) {
         npnts += countData(unitx + xsec);
      }
 
      /* We are pessimistic */
      failed = TRUE;
      if (allocData(npnts, &xdat, &ydat, &srvar, &yfit, &q4x)) {
         register double *Xdat, *Ydat, *Srvar;

         ntot = 0;
         Xdat = xdat;
         Ydat = ydat;
         Srvar = srvar;
         for (xsec = 0; xsec < ncross; xsec++) {
            npnts = 0;
            while (getNextLine(unitx + xsec) != NULL) {
               if (unitx[xsec].isComment) flushLine(unitx + xsec, NULL);
               else if (sscanf(unitx[xsec].buffer, "%lf %lf %lf", Xdat, Ydat, Srvar) == 3 && Xdat[0]!=0.0) {
                  Xdat++;
                  Ydat++;
                  Srvar++;
                  npnts++;
               }
            }
            qminx[nsecx[xsec]] = xdat[ntot];
            qmaxx[nsecx[xsec]] = (npnts == 0) ? xdat[ntot] :
                                                xdat[ntot + npnts - 1];
            npntsx[nsecx[xsec]] = npnts;
            ntot += npnts;
            closeBuf(unitx + xsec, 0);
         }
	 log2lin(ntot,xdat,ydat,srvar);
         if (allocMaps(npntsx, nqx, xspin)) {
            n4x = sortq(xdat, npntsx, q4x, nqx);
            if (allocDatax(n4x, &xtemp, &q4x, &y4x, &yfita))
               /*Successful after all */
               failed = FALSE;
         }
      }
   }
   if (failed) ERROR("/** Load failed **/");

   return failed;
}


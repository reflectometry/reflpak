/* Loads data from file */

#include <stdio.h>
#include <stdlib.h>
#include <loadData.h>
#include <linebuf.h>
#include <noFile.h>
#include <cleanFree.h>
#include <cparms.h>
#include <cdata.h>
#include <genpsc.h>

/* Local function prototypes */
#include <static.h>
#include "error.h"

#include <math.h>

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

int loadData(char *infile)
{
   int n = -1, oldn = npnts, retval = 1;
   LINEBUF data;

   if (openBuf(infile, "r", &data, FBUFFLEN) == NULL) {
      noFile(infile);
      loaded = FALSE;
   } else {
      /* Free previously loaded data */
      n = countData(&data);
      if (allocCdata(n)) {
         n = 0;
         while (getNextLine(&data) != NULL) {
	     if (data.isComment) flushLine(&data, NULL);
	     else if (sscanf(data.buffer, "%lf %lf %lf", xdat + n,
			     ydat + n, srvar + n) == 3) { 
	       n++;
	     } else {
	       retval = 0;
	       ERROR("failing at %d with:\n   %s\n", n, data.buffer);
	       break;
	     }
	 }
         closeBuf(&data, 0);

	 if (n == npnts) {
	   loaded = TRUE;
	   log2lin(npnts, xdat, ydat, srvar);
	   qmin = xdat[0];
	   qmax = xdat[npnts - 1]; /*ARRAY*/
	 } else {
	   ERROR("invalid format for data file %s\n", infile); fflush(stdout);
           retval = 0;
	   allocCdata(oldn);
	 }
      }
   }
   return retval;
}



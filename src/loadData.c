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

/* If the second half of the data is all negative, then assume
   that it is log data.  If it is log data which isn't negative, then
   it is not reflectivity.  If it is linear data which is mostly negative,
   then it isn't worth fitting.
*/
void log2lin(int n, double *y, double *dy)
{
  int i;

  for (i=n/2; i < n; i++) 
    if (y[i] > 0) return;

  for (i=0; i < n; i++) {
    y[i] = exp(LN10 * y[i]);
    dy[i] = y[i] * dy[i]/LN10;
  }
}

void isrealR(int n, double *y)
{
  int i,neg=0;

  for (i=0; i < n; i++) neg += y[i] < 0;
  realR = neg>n/10;
}

int loadData(char *infile)
{
   int n = -1, oldn = npnts, retval = 1;
   LINEBUF data;
   int columns=0;

   if (openBuf(infile, "r", &data, FBUFFLEN) == NULL) {
      noFile(infile);
      loaded = FALSE;
   } else {
      /* Free previously loaded data */
      n = countData(&data);
      if (allocCdata(n)) {
         n = 0;
         while (getNextLine(&data) != NULL) {
	     if (data.isComment) {
	       flushLine(&data, NULL);
	       continue;
	     }
	     if (n == 0) {
	       /* First row --- see if we have 2 or 3 columns */
	       columns=sscanf(data.buffer, "%lf %lf %lf", xdat, ydat, srvar);
	       if (columns < 2) columns = 2; /* trigger error */
	     }
	     if (sscanf(data.buffer, "%lf %lf %lf", xdat + n,
			ydat + n, srvar + n) == columns) { 
	       /* For two column data, set weight tiny so the graph
		  looks pretty. */
	       if (columns == 2) srvar[n]=1;
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
	   log2lin(npnts, ydat, srvar);
	   isrealR(npnts, ydat);
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



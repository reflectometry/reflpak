/* Subroutine sorts through the Q values of the four cross sections stored */
/* in XDAT and returns an array Q4X containing all of the Q values that need */
/* to be evaluated for all of the cross sections. */
/* John Ankner 4 August 1992 */

#include <stdio.h>
#include <math.h>
#include <sortq.h>

/* Local function prototypes */
#include <static.h>

STATIC int sortXsec(double xdat[], double q4x[], int npnts, int offset,
   int n4x);
STATIC void linkXsec(double xdat[], double q4x, int n, int *nc, int nq[],
   int npnts, int offset);


STATIC int sortXsec(double xdat[], double q4x[], int npnts, int offset,
   int n4x)
{
   register int n, nn, nnn;
   register double newq, qdiff;

   if (npnts > 0) {
      if (offset > 0) {
         for (n = offset; n < offset + npnts; n++) {
            newq = xdat[n];
            for (nn = 0; nn < n4x; nn++) {
               qdiff = 5.e-5 + (q4x[nn] - newq) /
                               (q4x[nn] + newq);
               if (qdiff > 0) break;
            }
            if (nn == n4x || qdiff > 2 * 5.e-5) {
               /* Shift Q4X list elements back */
               for (nnn = n4x; nnn > nn; nnn--)
                  q4x[nnn] = q4x[nnn - 1];
               /* Q point not yet on list---insert into list */
               q4x[nn] = newq;
               n4x++;
            }
         }
      } else {
         for (n = 0; n < npnts; n++)
            q4x[n] = xdat[n];
         n4x += npnts;
      }
   }
   return n4x;
}


STATIC void linkXsec(double xdat[], double q4x, int n, int *nc, int nq[],
   int npnts, int offset)
{
   register int nn;

   for (nn = offset + *nc; nn < offset + npnts; nn++)
      if (fabs((q4x - xdat[nn]) / (q4x + xdat[nn])) < 5.e-5) {
         /* Put on list */
         nq[(*nc)++] = n;
      }

}


#include <parameters.h>

#define QTOL 5.e-5
int sortq(double *xdat, int npntsx[4], double *q4x, int *nqx[4])
/* double xdat[4 * MAXPTS], q4x[4 * MAXPTS]; */
{
   double qdiff, newq;
   int n, nn, nnn, nmax;
   int npnts, n4x, xsec;
   int nx[4];

   /* Run through the four cross sections and place values in Q4X */
   /* Note: previous code by Ankner would permit q's within    */
   /*       same cross-section within tolerance to be placed   */
   /*       in q4x if they occured in the first cross-section  */
   /*       with data.  This version never permits q's within  */
   /*       tolerance from occuring more than once in q4x but  */
   /*       it runs more slowly for the first cross-section    */
   /*       with data                                          */
   /*       For checking only one cross-section, Anker had     */
   /*       execution time = k*npnts; this has execution time  */
   /*       = k*npnts*(npnts+1)/2                              */
   n4x = 0;
   nmax = npntsx[0] + npntsx[1] + npntsx[2] + npntsx[3];
   for (n = 0; n < nmax; n++) {
      newq = xdat[n];
      for (nn = 0; nn < n4x; nn++) {
         /*                tol->|                       */
         /* -00--+----+----0----+----+--00 line of oldq */
         /*           |<---newq------->| => break       */
#ifdef MINUSQ
         qdiff = QTOL + (q4x[nn] - newq) / fabs(q4x[nn] + newq);
#else
         qdiff = QTOL + (q4x[nn] - newq) / (q4x[nn] + newq);
#endif
         if (qdiff > 0) break;
      }
      if (nn == n4x || qdiff > 2 * QTOL) {
         /* newq is not within tolerance of oldq  */
         /* because biased qdiff is > 2 * tol or  */
         /* biased qdiff < 0 for all oldq because */
         /* all oldq < newq - tol => nn == n4x    */
         /* loop executes only if oldq > newq     */
         for (nnn = n4x; nnn > nn; nnn--)
            q4x[nnn] = q4x[nnn - 1];
         q4x[nn] = newq;
         n4x++;
      }
   }

   /* Create array index lists so that the four cross sections can */
   /* be matched to their corresponding Q4X values */
   nx[0] = 0;
   nx[1] = 0;
   nx[2] = 0;
   nx[3] = 0;
   for (n = 0; n < n4x; n++) {
      npnts = 0;
      for (xsec = 0; xsec < 4; xsec++) {
         linkXsec(xdat, q4x[n], n, nx + xsec, nqx[xsec], npntsx[xsec], npnts);
         npnts += npntsx[xsec];
      }
   }
   return n4x;
}


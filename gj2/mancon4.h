/* Subroutine performs convolution of data in array YFIT with Gaussian resolution */
/* function in Q, calculated from LAMBDA, LAMDEL, and THEDEL */
/* John Ankner 14 September 1992 */

#ifndef _MANCON4_H
#define _MANCON4_H

void mancon4(double *q, double lambda, double lamdel, double thedel,
   double *y, double *yfit, int ndata, int nlow, int nhigh, int ncross,
   int deldelq);

#endif /* _MANCON4_H */


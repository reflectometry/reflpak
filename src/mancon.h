/* Subroutine performs convolution of data in array YFIT with Gaussian
   resolution function in Q, calculated from LAMBDA, LAMDEL, and THEDEL
   John Ankner 19 June 1989 */

#ifndef _MANCON_H
#define _MANCON_H

void mancon(double *q, double lambda, double lamdel, double thedel,
   double *y, double *yfit, int npnts, int nlow, int nhigh, int deldelq);

#endif /* _MANCON_H */


/* Subroutine calculates length of low- and high-Q extensions of data to
   be convoluted with delta-Q Gaussian resolution function
   John Ankner 11-May-1989 */

#ifndef _EXTRES_H
#define _EXTRES_H

void extres(double q[], double lambda, double lamdel, double thedel,
   int npnts);

double *extend(double q[], int ndata, double lambda, double lamdel,
   double thedel);

#endif /* _EXTRES_H */


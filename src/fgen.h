/* Subroutine FGEN calculates the log(reflectivity) and derivatives
   to be used by fit routine MRQMIN
   John Ankner 3-July-1990 */

#ifndef _FGEN_H
#define _FGEN_H

void fgen(double q[], double a[], double yfit[], double dyda[], int ndata,
   int ma);

#endif /* _FGEN_H */


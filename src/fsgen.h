/* Subroutine FSGEN calculates the log(reflectivity) and derivatives
   for case of sum of spin up and spin down reflectivities
   to be used by fit routine MRQMIN
   John Ankner 3-July-1990 */

#ifndef _FSGEN_H
#define _FSGEN_h

void fsgen(double q[], double a[], double yfit[], double dyda[], int ndata,
   int ma);

#endif /* _FSGEN_H */


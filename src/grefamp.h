/* Subroutine calculates reflected amplitude of NLAYER stack
   exactly (without the roughness correction of REFINT)
   From Parratt, Phys. Rev. 95, 359(1954)
   John Ankner 14 December 1992 */

#ifndef _GENFAMP_H
#define _GENFAMP_H

#include <complex.h>

/* For Fortran namespace compatibility */
#define grefamp grefamp_

/*complex grefamp(double *qi, double *lambda, double gqcsq[], double gmu[],
   double gd[], int *nglay); */
void grefamp(double *qi, double *lambda, double gqcsq[], double gmu[],
   double gd[], int *nglay, double *gampreal, double *gampimag);

#endif /* _GENFAMP_H */


/* Subroutine calculates reflected intensity of NLAYER stack
   exactly (without the roughness correction of REFINT)
   From Parratt, Phys. Rev. 95, 359(1954)
   John Ankner 3-May-1989 */

#ifndef _GREFINT_H
#define _GREFINT_H

/* For Fortran namespace compatibility */
#define grefint grefint_

double grefint(double *qi, double *lambda, double gqcsq[], double gmu[],
   double gd[], int *nglay);

#define newgrefint newgrefint_

double newgrefint(double *q, double *y, int *npnts,
		  double *lambda, double gqcsq[], double gmu[],
		  double gd[], int *nglay);

#endif /* _GREFINT_H */


/* Modification of C.F. Majkrzak's program r6dp.f for calculating */
/* reflectivities of four polarization states of neutron reflectivity data. */
/* This version allows non-vacuum incident and substrate media and has */
/* been converted into a subroutine. */
/*** Note:  this subroutine does not deal with any component of sample ***/
/***        moment that may lie out of the plane of the film.  Such a  ***/
/***        perpendicular component will cause a neutron precession,   ***/
/***        therefore an additional spin flip term.  If reflectivity   ***/
/***        data from a sample with an out-of-plane moment is modeled  ***/
/***        using this subroutine, one will obtain erroneous results,  ***/
/***        since all of the spin flip scattering will be attributed   ***/
/***        to in-plane moments perpendicular to the neutron           ***/
/***        polarization.                                              ***/
/* John Ankner 22 June 1992 */

#ifndef _R4X_H
#define _R4X_H

/* For Fortran namespace */
#define r4x r4x_

void r4x(double q[], double ya[], double yb[], double yc[], double yd[],
   int *npnts, double *lambda, double *aguide,
   double *gqcsq, double *gmu, double *gd, double *gqmsq,
   double *gthe, int *nglay);

#endif /* _R4X_H */


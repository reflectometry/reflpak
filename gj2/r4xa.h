/* Modification of C.F. Majkrzak's program r6dp.f for calculating */
/* reflectivities of four polarization states of neutron reflectivity data. */
/* Identical to R4X, except that this one returns amplitudes. */
/*** Note:  this subroutine does not deal with any component of sample ***/
/***        moment that may lie out of the plane of the film.  Such a  ***/
/***        perpendicular component will cause a neutron precession,   ***/
/***        therefore an additional spin flip term.  If reflectivity   ***/
/***        data from a sample with an out-of-plane moment is modeled  ***/
/***        using this subroutine, one will obtain erroneous results,  ***/
/***        since all of the spin flip scattering will be attributed   ***/
/***        to in-plane moments perpendicular to the neutron           ***/
/***        polarization.                                              ***/
/* John Ankner 30 April 1993 */

#ifndef _R4XA_H
#define _R4XA_H

#include <complex.h>

/* For Fortran namespace */
#define r4xa r4xa_

void r4xa(double q[], complex yaa[], complex yba[], complex yca[],
   complex yda[], int *npnts, double *lambda,
   double *gqcsq, double *gmu, double *gd, double *gqmsq,
   double *gthe, int *nglay);

#endif /* _R4XA_H */


/* Subroutine generates layer profile for the refractive indices QCSQ, */
/* absorptions MU, and roughnesses ROUGH specified */
/* by the fit program by explicitly calculating the roughnesses of the */
/* interfacial regions as variations of average QCSQ and MU on a hyperbolic */
/* tangent or error function profile [see Anastasiadis, Russell, Satija, */
/* and Majkrzak, */
/* J. Chem. Phys. 92, 5677 (1990)] */
/* John Ankner 25 March 1992 */

/* By making substitution the->mu, it also generates magnetic profile */

#ifndef _GENLAYERS_H
#define _GENLAYERS_H

int genlayers(double *qcsq, double *d, double *rough, double *mu, int nlayer,
   double *zint, double *rufint, int nrough, char *proftyp, 
   double *gqcsq, double *gmu, double *gd);
double vacThick(double *rough, double *zint, int nrough);

#endif /* _GENLAYERS_H */


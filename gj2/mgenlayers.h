/* Subroutine generates layer profile for the magnetic refractive indices QCMSQ, */
/* thicknesses MD, and roughnesses MROUGH specified */
/* by the fit program by explicitly calculating the roughnesses of the */
/* interfacial regions as variations of average QCMSQ on a hyperbolic */
/* tangent or error function profile [see Anastasiadis, Russell, Satija, */
/* and Majkrzak, */
/* J. Chem. Phys. 92, 5677 (1990)] */
/* John Ankner 25 March 1992 */

#ifndef _MGENLAYERS_H
#define _MGENLAYERS_H

void mgenlayers(double *qcmsq, double *dm, double *mrough, double *the,
   int nlayer, double *zint, double *rufint, int nrough,
   char *proftyp);

#endif /* _MGENLAYERS_H */


/* Subroutine generates layer profile for the magnetic refractive indices QCMSQ, */
/* thicknesses MD, and roughnesses MROUGH specified */
/* by the fit program by explicitly calculating the roughnesses of the */
/* interfacial regions as variations of average QCMSQ on a hyperbolic */
/* tangent or error function profile [see Anastasiadis, Russell, Satija, */
/* and Majkrzak, */
/* J. Chem. Phys. 92, 5677 (1990)] */
/* John Ankner 25 March 1992 */

#include <stdio.h>
#include <math.h>
#include <mgenlayers.h>
#include <genlayers.h>
#include <derf.h>

#include <parameters.h>

#include <mglayd.h>
#include <glayim.h>

void mgenlayers(double *qcmsq, double *dm, double *mrough, double *the,
   int nlayer, double *zint, double *rufint, int nrough,
   char *proftyp)
/* double qcmsq[nlayer + 1], dm[nlayer + 1], mrough[nlayer + 1]; */
/* double the[nlayer + 1]; */
/* double zint[nrough + 1], rufint[nrough + 1] */
{
   the[0] = the[1];
   nglaym = genlayers(qcmsq, dm, mrough, the, nlayer, zint, rufint, nrough,
      proftyp, gqcmsq, gthem, gdm);
}


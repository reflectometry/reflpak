/* Subroutine generates layer profile for the refractive indices QCSQ, */
/* absorptions MU, and roughnesses ROUGH specified */
/* by the fit program by explicitly calculating the roughnesses of the */
/* interfacial regions as variations of average QCSQ and MU on a hyperbolic */
/* tangent or error function profile [see Anastasiadis, Russell, Satija, */
/* and Majkrzak, */
/* J. Chem. Phys. 92, 5677 (1990)] */
/* John Ankner 25 March 1992 */

#include <stdio.h>
#include <math.h>
#include <ngenlayers.h>
#include <genlayers.h>
#include <derf.h>

#include <parameters.h>

#include <nglayd.h>
#include <glayin.h>

void ngenlayers(double *qcsq, double *d, double *rough, double *mu, int nlayer,
   double *zint, double *rufint, int nrough, char *proftyp)
/* double qcsq[nlayer + 1], mu[nlayer + 1], d[nlayer + 1], rough[nlayer + 1]; */
/* double zint[nrough + 1], rufint[nrough + 1]; */
{
   nglayn = genlayers(qcsq, d, rough, mu, nlayer, zint, rufint, nrough,
      proftyp, gqcnsq, gmun, gdn);
}


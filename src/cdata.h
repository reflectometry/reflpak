/* Implements a new FORTRAN COMMON block CDATA */

#ifndef _CDATA_H
#define _CDATA_H

#include <common.h>
#include <parameters.h>

COMMON int realR;
COMMON int npnts, loaded;
COMMON double *xdat, *ydat, *srvar, *yfit, *xtemp, *ytemp;
/* COMMON double ytemp1[MAXPTS], xtemp1[MAXPTS]; */
COMMON double chisq, ochisq, qmin, qmax, alamda;
COMMON double a[NA];
COMMON double covar[NA][NA], alpha[NA][NA], beta[NA];

void freeCdata(void);
int allocCdata(int);

#endif /* _CDATA_H */


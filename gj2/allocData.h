/* Allocates space for temporary data */

#ifndef _ALLOCDATA_H
#define _ALLOCDATA_H

/* For complex */
#include <complex.h>

int allocTemp(int ndata, int nlow, int nhigh);
int allocData(int npnts, double **xdat, double **ydat, double **srvar,
   double **yfit, double **q4x);
int allocDatax(int n4x, double **xtemp, double **q4x, double **y4x,
   complex **yfita);
int allocMaps(int npntsx[4], int *nqx[4], int xspin[4]);

#endif /* _ALLOCDATA_H */


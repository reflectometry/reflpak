/* Temporary arrays allocated dynamically */

#ifndef _GENMEM_H
#define _GENMEM_H

#include <common.h>
#include <parameters.h>

COMMON double *qtemp, *y, *dy;
/* COMMON double qtemp[MAXPTS], dy[4 * MAXPTS], y[4 * MAXPTS]; */
COMMON double *ymod, *dyda;
/* COMMON double ymod[MAXPTS], dyda[NA * MAXPTS]; */
COMMON int nlow, nhigh;

#endif /* _GENMEM_H */


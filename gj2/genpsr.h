/* Implements FORTRAN COMMON block GENPSR */

#ifndef _GENPSR_H
#define _GENPSR_H

#include <common.h>
#include <parameters.h>

COMMON double zint[MAXINT], rufint[MAXINT];
/* COMMON double q4x[MAXPTS]; */
COMMON double *q4x;

#endif /* _GENPSR_H */


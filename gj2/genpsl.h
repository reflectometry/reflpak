/* Implements FORTRAN COMMON block GENPSL */

#ifndef _GENPSL_H
#define _GENPSL_H

#include <common.h>
#include <parameters.h>

COMMON int xspin[4];
#define aspin (xspin[0])
#define bspin (xspin[1])
#define cspin (xspin[2])
#define dspin (xspin[3])

#endif /* _GENPSL_H */


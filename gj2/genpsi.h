/* Implements FORTRAN COMMON block GENPSI */

#ifndef _GENPSI_H
#define _GENPSI_H

#include <common.h>
#include <parameters.h>

COMMON int nlayer, nrough; 
COMMON int ncross;
COMMON int npntsx[4];
#define npntsa (npntsx[0])
#define npntsb (npntsx[1])
#define npntsc (npntsx[2])
#define npntsd (npntsx[3])

COMMON int n4x;
COMMON int *nqx[4];

#endif /* _GENPSI_H */


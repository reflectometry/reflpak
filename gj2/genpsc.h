/* Implements FORTRAN COMMON block GENPSC */

#ifndef _GENPSC_H
#define _GENPSC_H

/* For L_tmpnam */
#include <stdio.h>

/* For PATH_MAX */
#include <limits.h>

#include <common.h>
#include <parameters.h>
#include <cparms.h>


COMMON char proftyp[PROFTYPLEN+2], polstat[POLSTATLEN+2];
COMMON char infile[INFILELEN+2], outfile[OUTFILELEN+2];
COMMON char parfile[PARFILELEN+2];
COMMON char fitlist[490];

/* char *constrainModule = "./constrain.so"; */
/* char *constrainScript = "./constrain.sta"; */
COMMON char constrainModule[L_tmpnam + 1], constrainScript[L_tmpnam + 1];

COMMON char currentDir[PATH_MAX + 1];
COMMON char *ConstraintScript;
#endif /* _GENPSC_H */


/* Implements FORTRAN COMMON block GENPSC */

#ifndef _GENPSC_H
#define _GENPSC_H

/* For L_tmpname */
#include <stdio.h>

/* For PATH_MAX */
#include <limits.h>

#include <common.h>
#include <cparms.h>

COMMON char proftyp[PROFTYPLEN+2], infile[INFILELEN+2], outfile[OUTFILELEN+2],
   fitlist[70+1];
COMMON char parfile[PARFILELEN+2];
COMMON char constrainModule[L_tmpnam + 1], constrainScript[L_tmpnam + 1];
COMMON char currentDir[PATH_MAX + 1];
extern char *ConstraintScript;
#endif /* _GENPSC_H */


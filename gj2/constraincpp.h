/* Defines coding requirments for constrain module */

#ifndef _CONSTRAINCPP_H
#define _CONSTRAINCPP_H

/* For NULL */
#include <stddef.h>
#include <parameters.h>

#define Str(x) #x
#define STr(x) #x, Str(x)

static char *prototype = "int NL";

static char *makeargv[] = {
   NULL, NULL,
   NULL, NULL,
   NULL,
    STr(QC),
    STr(D),
    STr(RO),
    STr(MU),
    STr(QM),
    STr(DM),
    STr(RM),
    STr(TH),
    "-",
    STr(BK),
    STr(BI),
    "-",
    "NL",
    NULL};

#define MAJOR GJ2COMPAT
#define MINOR 3

#endif /* _CONSTRAINCPP_H */


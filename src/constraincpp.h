/* Defines coding requirments for constrain module */

#ifndef _CONSTRAINCPP_H
#define _CONSTRAINCPP_H

/* For NULL */
#include <stddef.h>
#include <parameters.h>

#define Str(x) #x
#define STr(x) #x, Str(x)
#define STR(x) Str(x)

static char *prototype = "int NTL, int NML, int NMR, int NBL";

static char *makeargv[] = {
   NULL, NULL,
   NULL, NULL,
   NULL,
    "TQC", STR(QC),
    "TQM", STR(QM),
    "TMU", STR(MU),
    "TD" , STR(D),
    "TRO", STR(RO),
    "MQC", "(" STR(MAXLAY) "*" STR(NUMPARAMS) "+" STR(QC) ")",
    "MQM", "(" STR(MAXLAY) "*" STR(NUMPARAMS) "+" STR(QM) ")",
    "MMU", "(" STR(MAXLAY) "*" STR(NUMPARAMS) "+" STR(MU) ")",
    "MD" , "(" STR(MAXLAY) "*" STR(NUMPARAMS) "+" STR(D) ")",
    "MRO", "(" STR(MAXLAY) "*" STR(NUMPARAMS) "+" STR(RO) ")",
    "BQC", "( 2 *" STR(MAXLAY) "*" STR(NUMPARAMS) "+" STR(QC) ")",
    "BQM", "( 2 *" STR(MAXLAY) "*" STR(NUMPARAMS) "+" STR(QM) ")",
    "BMU", "( 2 *" STR(MAXLAY) "*" STR(NUMPARAMS) "+" STR(MU) ")",
    "BD" , "( 2 *" STR(MAXLAY) "*" STR(NUMPARAMS) "+" STR(D) ")",
    "BRO", "( 2 *" STR(MAXLAY) "*" STR(NUMPARAMS) "+" STR(RO) ")",
    "-",
    STr(BK),
    STr(BI),
    "-",
    "NTL",
    "NML",
    "NMR",
    "NBL",
    NULL};

#define MAJOR MLAYCOMPAT
#define MINOR 2

#endif /* _CONSTRAINCPP_H */


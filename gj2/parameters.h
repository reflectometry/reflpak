/* Defines various parameters used in all the FORTRAN modules */

#ifndef _PARAMETERS_H
#define _PARAMETERS_H

/* 1 more than maximum number of layers */
/* #define MAXLAY 50 */
/* #define MAXLAY 100 */
#define MAXLAY 124

/* Number of fitting parameters for layer */
#define NUMPARAMS 8

/* Total number of fiting parameters (includes background and beam intensity) */
#define NA ((NUMPARAMS)*(MAXLAY)+2)

/* Parameter numbers */
#define QC 0
#define QM MAXLAY
#define MU (2*MAXLAY)
#define D (3*MAXLAY)
#define DM (4*MAXLAY)
#define RO (5*MAXLAY)
#define RM (6*MAXLAY)
#define TH (7*MAXLAY)
#define BK (NA-2)
#define BI (NA-1)

/* Number of data points we can support for input file */
/* #define MAXPTS 2000 */
#define MAXPTS  200

/* Number of data points we can support for profile */
/* This must be updated in r4x.f if you change it here */
/* #define MAXGEN 10000 */
/* #define MAXGEN 2000 */
#define MAXGEN 4096
/* #define MAXGEN 8192 */

/* Maximum number of interface sublayers */
#define MAXINT 1002

/* Ensures that d(tanh CT*Z/ZF)/dZ = .5
   when Z = .5 * ZF, where ZF is fwhm */
#define CT 2.292

/* Constant CE that ensures that d(erf CE*Z/ZF)/dZ = .5
   when Z = .5 * ZF, where ZF is fwhm */
#define CE 1.665

/* Fractional change in parameters when making a least-squares step */
#define DELA 1.e-8

#endif /* _PARAMETERS_H */


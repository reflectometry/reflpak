/* Defines various parameters used in all the FORTRAN modules */

#ifndef _PARAMETERS_H
#define _PARAMETERS_H

/* Top, middle and bottom */
#define NUMREGIONS 3

/* 1 more than number of sublayers in region */
#define MAXLAY 10

/* Number of fitting parameters for sublayer */
#define NUMPARAMS 5

/* Total number of fiting parameters (includes background and beam intensity) */
#define NA ((NUMREGIONS)*(NUMPARAMS)*(MAXLAY)+2)

/* Parameter numbers */
#define QC 0
#define QM MAXLAY
#define MU (2*MAXLAY)
#define D (3*MAXLAY)
#define RO (4*MAXLAY)
#define BK (NA-2)
#define BI (NA-1)

/* Number of data points we can support for input file */
#define MAXPTS 2000

/* Number of data points we can support for profile */
#define MAXGEN 10000

/* Maximum number of interface sublayers */
#define MAXINT 1002

/* Comment is incorrect */
/* Ensures that d(tanh CT * Z/ ZF) / DZ = .5
   when Z = .5 * ZF, where ZF is fwhm */
/* Ensures that d(tanh(y))/dy|(y=CE*Z/ZF) = 0.334 when Z=.5*ZF,
   where ZF is fwhm */
#define CT 2.292

/* Comment is incorrect */
/* Constant CE that ensures that d(erf CE*Z/ZF)/dZ = .5 when Z=.5*ZF,
   where ZF is fwhm */

/* Constant CE ensures that .5*sqrt(Pi)*d(erf(y))/dy|(y=CE*Z/ZF) = .5
   when Z=.5*ZF where ZF is fwhm
   Note: .5*sqrt(Pi)*d(erf(y))/dy = exp(-y**2) */
#define CE 1.665

/* Fractional change in parameters when making a least-squares step */
#define DELA 1.e-8

#endif /* _PARAMETERS_H */


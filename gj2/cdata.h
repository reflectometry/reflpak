/* Implements a new FORTRAN COMMON block CDATA */

#ifndef _CDATA_H
#define _CDATA_H

#include <complex.h>
#include <common.h>
#include <parameters.h>
#include <cparms.h>

/* COMMON double xdat[4 * MAXPTS], ydat[4 * MAXPTS], srvar[4 * MAXPTS]; */
/* COMMON double yfit[4 * MAXPTS], y4x[4 * MAXPTS]; */
/* COMMON double ytemp[4 * MAXPTS]; */
/* COMMON complex y4xa[4 * MAXPTS], yfita[4 * MAXPTS]; */
/* COMMON double xtemp[4 * MAXPTS]; */

COMMON double *xdat, *ydat, *srvar;
COMMON double *yfit, *y4x;
COMMON double *xtemp;
COMMON complex *yfita;

COMMON double chisq, ochisq;
COMMON double alamda;
COMMON double a[NA];
COMMON double covar[NA][NA], alpha[NA][NA], beta[NA];
COMMON char filebuf[FBUFFLEN];
COMMON char filnam[FILNAMLEN];
COMMON double qminx[4], qmaxx[4];
#define qmina (qminx[0])
#define qminb (qminx[1])
#define qminc (qminx[2])
#define qmind (qminx[3])
#define qmaxa (qmaxx[0])
#define qmaxb (qmaxx[1])
#define qmaxc (qmaxx[2])
#define qmaxd (qmaxx[3])

#endif /* _CDATA_H */


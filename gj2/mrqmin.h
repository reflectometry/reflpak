#ifndef MRQMIN_H
#define MRQMIN_H

/*
 Levenberg-Marquardt method, attempting to reduce the value CHISQ of a fit
 between a set of NDATA points X(I),Y(I) with individual standard deviations
 SIG(I), and a non-linear function dependent on MA coefficients A.  The
 array LISTA numbers the parameters A such that the first MFIT elements
 correspond to values actually being adjusted; the remaining MA-MFIT
 parameters are held fixed at their input value.  The program returns current
 best-fit values for the MA fit parameters A and CHISQ.  The arrays
 COVAR(NCA,NCA), ALPHA(NCA,NCA) with physical dimension NCA (>= MFIT) are
 used as working space during most iterations.  Supply a subroutine
 FUNCS(X,A,YFIT,DYDA,NDATA,MA)
 that evaluates the fitting function YFIT, and its
 derivatives DYDA with respect to the fitting parameters
 over he entire scan.  / ** Different from Numerical Recipes ** /  On the
 first call provide an initial guess for the parameters A and set
 ALAMDA<0 for initialization (which then sets ALAMDA=.001).  If a step
 succeeds CHISQ becomes smaller and ALAMDA decreases by a factor of
 10.  You must call this routine repeatedly until convergence is achieved.
 Then, make one final call with ALAMDA=0, so that COVAR(I,J) returns the
 covariance matrix, and ALPHA(I,J) the curvature matrix.
 Adapted from Numerical Recipes, ch. 14.
 John Ankner 24-April-1989 */

#include <stdio.h>  /* For FILE */
#include <parameters.h>
#include <dynamic.h>

/* For Fortran namespace */
#define mrqmin mrqmin_

typedef void (*fitFunc)(double [], double [], double [], double [], int, int);

FILE *mrqmin(double x[], double y[], double sig[], int ndata, double a[],
   int ma, int lista[], int mfit, dynarray covar, dynarray alpha,
   double beta[], int nca, double *chisq, fitFunc funcs, double *alamda,
   FILE *unit99);

#endif /* _MRQMIN_H */


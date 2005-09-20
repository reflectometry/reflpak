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

#include <math.h>
#include <mrqmin.h>
#include <genmem.h>
#include <parameters.h>
#include <dynamic.h>


/* Local function prototypes */
#include <static.h>

STATIC double 
mrqcof(double x[], double y[], double sig[], int ndata, double a[],
   int ma, int lista[], int mfit, dynarray alpha, double beta[], int nalp,
   fitFunc funcs);
STATIC void 
gaussj(dynarray a, int n, int np, double b[], int m, int mp);


/* Return chisq; stop if new chisq is not significantly different
   from old chisq.
 */
double mrqmin(double x[], double y[], double sig[], int ndata, double a[],
   int ma, int lista[], int mfit, dynarray covar, dynarray alpha,
   double beta[], int nca, double old_chisq, fitFunc funcs, double *alamda,
   FILE *unit99)
{
/* Set to largest number of fit parameters */
#define NMAX NA

   static double atry[NMAX], da[NMAX];
   double chisq = -1.;
   register int kk, j, k;
   int ihit;


   /* printf("try\n"); */
   /* Initialization of fit matrices */
   if (*alamda < 0.) {
      kk = mfit;
      /* Does LISTA contain a proper permutation of coefficients? */
      for (j = 0; j < ma; j++) {
         ihit = 0;
         for (k = 0; k < mfit; k++)
            if (lista[k] == j) ihit++;
         if (ihit == 0) {
            lista[kk] = j;
            kk++;
         } else if (ihit > 1)
            puts("/** Improper permutation in LISTA **/");
      }
      if (kk != ma) puts("/** Improper permutation in LISTA **/");
      *alamda = 0.001;
      chisq = mrqcof(x, y, sig, ndata, a, ma, lista, mfit, alpha, beta, nca, funcs);
      for (j = 0; j < ma; j++)
         atry[j] = a[j];

      if (unit99)
         fputs("# Begin fit\n", unit99);
      return chisq;
   }

   /* Alter linearized fitting matrix by augmenting diagonal elements */
   for (j = 0; j < mfit; j++) {
      for (k = 0; k < mfit; k++)
         refray(covar,j,k) = refray(alpha,j,k);
         refray(covar,j,j) = refray(alpha,j,j) * (1. + *alamda);
         da[j] = beta[j];
   }

   /* Matrix solution */
   gaussj(covar, mfit, nca, da, 1, 1);

   /* Exit if simply evaluating the COVAR matrix */
   if (*alamda == 0.) return old_chisq;

   /* Did the trial succeed? */
   for (j = 0; j < ma; j++)
      atry[j] = a[j];
   for (j = 0; j < mfit; j++) {
      atry[lista[j]] = a[lista[j]] + da[j];
      /* printf(" ATRY%3d: %#15.7G\n", lista[j] + 1, atry[lista[j]]); */
      if (unit99)
	fprintf(unit99, " ATRY%3d: %#15.7G\n", lista[j] + 1, atry[lista[j]]);
   }
   chisq = mrqcof(x, y, sig, ndata, atry, ma, lista, mfit, covar, da, nca, funcs);

   /* Success, accept the new solution and decrease ALAMDA */
   if (chisq < old_chisq) {
      /* printf("success --- decrease ALAMDA to %g\n",*alamda); */
      *alamda *= 0.1;
      for (j = 0; j < mfit; j++) {
         for (k = 0; k < mfit; k++)
            refray(alpha,j,k) = refray(covar,j,k);
         beta[j] = da[j];
         a[lista[j]] = atry[lista[j]]; /*ARRAY*/
	 /* printf(" A(%3d): %#15.7G\n", lista[j] + 1, atry[lista[j]]); */
         if (unit99)
	   fprintf(unit99, " A(%3d): %#15.7G\n", lista[j] + 1, atry[lista[j]]);
      }

   /* Failure, ignore the new solution and increase ALAMDA */
   } else {
      /* printf("fail --- increase ALAMDA to %g\n",*alamda); */
      *alamda *= 10.;
   }

   return chisq;
}


/* Used by MRQMIN to evaluate the linearized fitting matrix ALPHA
   and vector BETA as in (14.4.8)
   John Ankner 24-April-1989 */

STATIC double 
mrqcof(double x[], double y[], double sig[], int ndata, double a[],
   int ma, int lista[], int mfit, dynarray alpha, double beta[], int nalp,
   fitFunc funcs)
{
   register int i, j, k;
   double chisq;

   /* Initialize symmetric ALPHA,BETA */
   for (j = 0; j < mfit; j++) {
      for (k = 0; k <= j; k++)
         refray(alpha,j,k) = 0.;
      beta[j] = 0.;
   }
   chisq = 0.;

   /* Summation loop over all data */
   (*funcs)(x, a, ymod, dyda, ndata, ma);
   for (i = 0; i < ndata; i++) {
      double sig2i, dy, wt;

      sig2i = 1. / (sig[i] * sig[i]);
      dy = y[i] - ymod[i];
      for (j = 0; j < mfit; j++) {
         wt = dyda[i + j * ndata] * sig2i;
         for (k = 0; k <= j; k++)
            refray(alpha,j,k) += wt * dyda[i + k * ndata];
         beta[j] += dy * wt;
      }
      /* And find CHISQ */
      chisq += dy * dy * sig2i;
   }

   /* Fill in the symmetric side */
   for (j = 1; j < mfit; j++)
      for (k = 0; k < j; k++)
         refray(alpha,k,j) = refray(alpha,j,k);

   return chisq;
}


/* Linear equation solution by Gauss-Jordan elimination.  A is an input matrix
   of N by N elements, stored in an array of physical dimensions NP by NP.
   B is an input matrix of N by M containing the M right-hand side vectors,
   stored in an array of physical dimensions NP by MP.  On output, A is replaced
   by its matrix inverse, and B is replaced by the corresponding set of solution
   vectors
   From Numerical Recipes, chapter 2
   John Ankner 24-April-1989 */

/* GaussJ has been optimized in this module with m = mp = 1 */

STATIC void gaussj(dynarray a, int n, int np, double b[], int m, int mp)
{
#define NMAX NA

/* The integer arrays IPIV, INDXR, and INDXC are used for bookkeeping
   on the pivoting.  NMAX should be as large as the largest
   anticipated value of N. */

/* double precision a[np][np], b[np] */
   static int ipiv[NMAX], indxr[NMAX], indxc[NMAX];
   register int i, j, k, l, ll;
   int irow, icol;
   double big, dum, pivinv;

   a.row = np;
   a.col = np;

   for (j = 0; j < n; j++)
      ipiv[j] = 0;

   /* This is the main loop over the columns to be reduced */
   for (i = 0; i < n; i++) {
      big = 0.;

      /* This is the outer loop of the search for a pivot element */
      for (j = 0; j < n; j++) {
         if (ipiv[j] != 1) {
            for (k = 0; k < n; k++) {
               if (ipiv[k] == 0) {
                  if (fabs(refray(a,j,k)) >= big) {
                     big = fabs(refray(a,j,k));
                     irow = j;
                     icol = k;
                  }
               } else if (ipiv[k] > 1) puts("/** Singular matrix **/");
            }
         }
      }
      ipiv[icol]++;

      /* We now have the pivot element, so we interchange rows, if needed,
         to put the pivot element on the diagonal.  The columns are not
         physically interchanged, only relabeled:  INDXC(I), on the column
         of the Ith pivot element, is the Ith column that is reduced, while
         INDXR(I) is the row in which that pivot element was originally
         located.  If INDXR(I) .ne. INDXC(I) there is an implied column
         interchange.  With this form of bookkeeping, the solution B's will
         end up in the correct order, and the inverse matrix will be
         scrambled by columns. */

      if (irow != icol) {
         for (l = 0; l < n; l++) {
            dum = refray(a,irow,l);
            refray(a,irow,l) = refray(a,icol,l);
            refray(a,icol,l) = dum;
         }
         dum = b[irow];
         b[irow] = b[icol];
         b[icol] = dum;
      }

      /* We are now ready to divide the pivot row by the pivot element,
         located at IROW and ICOL. */

      indxr[i] = irow;
      indxc[i] = icol;
      if (refray(a,icol,icol) < 1.e-30) {
         puts("/** Singular matrix **/");
         pivinv = 0.;
      } else
         pivinv = 1. / refray(a,icol,icol);
      refray(a,icol,icol) = 1.;
      for (l = 0; l < n; l++)
         refray(a,icol,l) *= pivinv;
      b[icol] *= pivinv;

      /* Next, we reduce the rows, except for the pivot */
      for (ll = 0; ll < n; ll++) {
         if (ll != icol) {
            dum = refray(a,ll,icol);
            refray(a,ll,icol) = 0.;
            for (l = 0; l < n; l++)
               refray(a,ll,l) -= refray(a,icol,l) * dum;
            b[ll] -= b[icol] * dum;
         }
      }
   }

   /* This is the end of the main loop over columns of the reduction.  It
      only remains to unscramble the solution in view of the column
      interchanges.  We do this by interchanging pairs of columns in the
      reverse order that the permutation was built up. */

   for (l = n - 1; l >= 0; l--) {
      if (indxr[l] != indxc[l]) {
         for (k = 0; k < n; k++) {
            dum = refray(a,k,indxr[l]);
            refray(a,k,indxr[l]) = refray(a,k,indxc[l]);
            refray(a,k,indxc[l]) = dum;
         }
      }
   }
}


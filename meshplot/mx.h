/* This program is public domain */
#ifndef _MX_H
#define _MX_H

#undef EXTERN
#ifdef __cplusplus
# define EXTERN extern "C"
#else
# define EXTERN extern
# include <stddef.h>
#endif

#ifdef USE_DOUBLE
#define mxtype double
#else
#define mxtype float
#endif

EXTERN void mx_hsv2rgb(int n, mxtype *x);
EXTERN void mx_transpose(int m, int n, mxtype *a, mxtype *b);
EXTERN void mx_integrate(int m, int n, const mxtype *a, int dim, mxtype *b);
EXTERN void mx_extract_columns(int m, int n, const mxtype *a,
			       int column, int width, mxtype *b);
EXTERN void mx_divide_columns(int m, int n, mxtype *M, const mxtype *y);
EXTERN void mx_divide_rows(int m, int n, mxtype *M, const mxtype *y);
EXTERN void mx_divide_elements(int m, int n, mxtype *M, const mxtype *y);
EXTERN void mx_divide_scalar(int m, int n, mxtype *M, const mxtype y);

EXTERN int mx_slice_find(int m, int n, const mxtype x[], const mxtype y[], 
			 mxtype x1, mxtype y1, mxtype x2, mxtype y2,
			 int maxidx, int idx[]);

EXTERN void mx_slice_interp(int m, int n, 
			    const mxtype x[], const mxtype y[], 
			    const mxtype z[], const mxtype dz[],
			    mxtype x1, mxtype y1, mxtype x2, mxtype y2,
			    int nidx, const int idx[], mxtype result[],
			    int interpolate);

#endif /* _MX_H */

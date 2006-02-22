#include <stddef.h>
#ifdef USE_DOUBLE
#define mxtype double
#else
#define mxtype float
#endif

void mx_transpose(int m, int n, mxtype *a, mxtype *b);
void mx_integrate(int m, int n, const mxtype *a, int dim, mxtype *b);
void mx_extract_columns(int m, int n, const mxtype *a,
			int column, int width, mxtype *b);
void mx_divide_columns(int m, int n, mxtype *M, const mxtype *y);
void mxdx_divide_columns(int m, int n, mxtype *M, mxtype *dM, const mxtype *y);

void mx_quad_search(int n, int m, mxtype *x, mxtype *y, 
		    int *xidx, int *yidx,
		    double x1, double y1, double x2, double y2);

int mx_slice(const size_t m, const size_t n, 
	     const mxtype x[], const mxtype y[],
	     const mxtype L[], size_t Nidx, size_t idx[]);

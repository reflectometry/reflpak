#ifndef PRECISION
#define PRECISION float
#endif

#define mxtype PRECISION

void mx_transpose(int n, int m, mxtype *a, mxtype *b);
void mx_extract_columns(int m, int n, const mxtype *a,
			int column, int width, mxtype *b);
void mx_divide_columns(int m, int n, mxtype *M, const mxtype *y);
void mxdx_divide_columns(int m, int n, mxtype *M, mxtype *dM, const mxtype *y);

void mx_quad_search(int n, int m, mxtype *x, mxtype *y, 
		    int *xidx, int *yidx,
		    double x1, double y1, double x2, double y2);
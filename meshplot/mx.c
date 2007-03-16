#include <math.h>
#include "mx.h"

/* Generic matrix operations */

/* From Robin Becker <robin@jessikat.fsnet.co.uk>
 * Posted to sci.math.num-analysis on Dec 6 2003, 2:24 pm
 * He does not remember who is the original author.
 */
void mx_transpose(int n, int m, mxtype *a, mxtype *b)
{
  int size = m*n;
  if(b!=a){ /* out of place transpose */
    mxtype *bmn, *aij, *anm;
    bmn = b + size; /*b+n*m*/
    anm = a + size;
    while(b<bmn) for(aij=a++;aij<anm; aij+=n ) *b++ = *aij;
  }
  else if(n!=1 && m!=1){ /* in place transpose */
    /* PAK: use (n!=1&&m!=1) instead of (size!=3) to avoid vector transpose */
    int i,row,column,current;
    for(i=1, size -= 2;i<size;i++){
      current = i;
      do {
	/*current = row+n*column*/
	column = current/m;
	row = current%m;
	current = n*row + column;
      } while(current < i);

      if (current>i) {
	mxtype temp = a[i];
	a[i] = a[current];
	a[current] = temp;
      }
    }
  }
}

void mx_flip(int m, int n, mxtype *a, int dim)
{
}

void mx_skew(int m, int n, mxtype *a, double angle, int dim)
{
  int j,k;

  /* Use transpose to do dim==2 */
  /* TODO: dim==1 should be identical to dim==2, but looping variables reversed */
  if (dim==2) mx_transpose(m,n,a,a);

  for (j=0; j < n; j++) {
    int delta = sin(angle)*(j-n/2);
    int offset = floor(delta);
    double portion = delta-offset;
    mxtype *pa = a+j*m;
    if (delta < 0) {
      /* Shifting up, so start at the top */
      for (k = 0; k < m+offset-1; k++) {
	pa[k] = pa[k-offset]*(1-portion) + pa[k-offset+1]*portion;
      }
      if (offset) pa[k] = pa[k-offset]*(1-portion);
      while (++k < m) pa[k] = 0.;
    } else {
      /* Shifting down, so start at the bottom */
      for (k = m-1; k >= offset; k--) {
	pa[k] = pa[k-offset-1]*(1-portion) + pa[k-offset]*portion;
      }
      if (offset) pa[k] = pa[k-offset]*(1-portion);
      while (--k >= 0) pa[k] = 0.;
    }
  }

  if (dim==2) mx_transpose(m,n,a,a);

}

/* Rotate a matrix in place. */
void mx_rotate(int m, int n, mxtype *a, double angle)
{
 /* [The following is frequently referenced but was not my source.]
  *
  * A. Paeth, "A fast algorithm for general raster rotation," in
  * Proceedings, Graphics Interface '86, pp. 77-81,
  * Vancouver, BC, 1986.
  */

  mx_skew(m,n,a,0.5*angle,1);
  mx_flip(m,n,a,2);
  mx_skew(m,n,a,atan(sin(angle)),2);
  mx_flip(m,n,a,2);
  mx_skew(m,n,a,0.5*angle,1);
}

/* Integrate the array
 * n is the fastest varying dimension.
 * if dim==0, integrate along m.
 * */
void mx_integrate(int m, int n, const mxtype *a, int dim, mxtype *b)
{
  int i,j;
  if (dim == 1) {
    for (j=0; j < n; j++) {
      b[j] = 0;
      for (i=0; i < m; i++) b[j] += a[j+i*n];
    }
  } else {
    for (i=0; i < m; i++) {
      b[i] = 0;
      for (j=0; j < n; j++) b[i] += a[j+i*n];
    }
  }
}

/* 0-origin dense column extraction */
void mx_extract_columns(int m, int n, const mxtype *a,
			int column, int width, mxtype *b)
{
  int i, j;
  int idx = 0;
  a += column;
  for (i=0; i < m; i++) {
    for (j=0; j < width; j++) b[idx++] = a[j];
    a += n;
  }
}

/* Scale all columns by a value */
void mx_divide_columns(int m, int n, mxtype *M, const mxtype *y)
{
  int i, j;
  for (i=0; i < m; i++) {
    for (j=0; j < n; j++) M[j] /= y[i];
    M += n;
  }
}

/* Scale all columns by a value */
void mxdx_divide_columns(int m, int n, mxtype *M, mxtype *dM, const mxtype *y)
{
  mx_divide_columns(m,n,M,y);
  mx_divide_columns(m,n,dM,y);
}

/* Find the set of quads traversed by a line */
void mx_quad_search(int n, int m, mxtype *x, mxtype *y, 
		    int *xidx, int *yidx,
		    double x1, double y1, double x2, double y2)
{
  
}

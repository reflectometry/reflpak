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

void mx_integrate(int m, int n, const mxtype *a,
		  int dim, mxtype *b)
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

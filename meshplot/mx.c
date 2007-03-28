#include <math.h>
#include <stdlib.h>
#include "mx.h"

/* Generic matrix operations */

/* From Robin Becker <robin@jessikat.fsnet.co.uk>
 * Posted to sci.math.num-analysis on Dec 6 2003, 2:24 pm
 * He does not remember who is the original author.
 * Modified by Paul Kienzle
 */
void mx_transpose(int n, int m, mxtype *a, mxtype *b)
{
  int size = m*n;
  if(b!=a){ /* out of place transpose */
    mxtype *bmn, *aij, *anm;
    bmn = b + size; /* b+n*m */
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

/* Scale entire matrix by a value */
void mx_divide_scalar(int m, int n, mxtype *M, const mxtype y)
{
  int i,j;

  for (i=0; i < m; i++) {
    for (j=0; j < n; j++) M[j] /= y;
    M += n;
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
void mx_divide_rows(int m, int n, mxtype *M, const mxtype *y)
{
  int i, j;
  for (i=0; i < m; i++) {
    for (j=0; j < n; j++) M[j] /= y[j];
    M += n;
  }
}

/* Scale all columns by a value */
void mx_divide_elements(int m, int n, mxtype *M, const mxtype *y)
{
  int i, j;
  for (i=0; i < m; i++) {
    for (j=0; j < n; j++) M[j] /= y[j];
    M += n; y+=n;
  }
}


static void hsv2rgb(mxtype h, mxtype s, mxtype v, mxtype *r, mxtype *g, mxtype *b)
{
  if (s <= 0.0) {
    *r = *g = *b = v;
  } else {
    int segment = floor(6.*h);
    float f = 6.*h - segment;
    float p = v * (1. - s);
    float q = v * (1. - (s * f));
    float t = v * (1. - (s * (1. - f)));
    switch (segment) {
    case 0: *r = v; *g = t; *b = p; break;
    case 1: *r = q; *g = v; *b = p; break;
    case 2: *r = p; *g = v; *b = t; break;
    case 3: *r = p; *g = q; *b = v; break;
    case 4: *r = t; *g = p; *b = v; break;
    case 5: *r = v; *g = p; *b = q; break;
    }
  }
}

void mx_hsv2rgb(int n, mxtype *x)
{
  int i;
  for (i=0; i < n; i++) {
    hsv2rgb(x[4*i],x[4*i+1],x[4*i+2],x+4*i,x+4*i+1,x+4*i+2);
  }
}


/* t = intersect(Ax,Adx,Ay,Ady,Bx,Bdx,By,Bdy)
 *
 * Return true if the line defined by P1 = (Ax,Ay) and P2 = (Ax+Adx,Ay+Ady) 
 * intersects the segment defined by Q1 = (Bx,By) and Q2 = (Bx+Bdx,By+Bdy)
 *
 * Algorithm:
 * 
 * Distance between line (Ax,Ay) --> (Ax+Adx,Ay+Ady) and point Bx,By
 *
 *   | A.dx * (A.y-B.y) - A.dy * (A.x-B.x) |
 *   ---------------------------------------
 *           sqrt( A.dx^2 + A.dy^2 )
 *
 * Intersection of two lines A,B:
 *
 *   numA = B.dx * (A.y - B.y) - B.dy * (A.x - B.x)
 *   numB = A.dx * (A.y - B.y) - A.dy * (A.x - B.x)
 *   den = B.dy * A.dx - B.dx * A.dy
 *   uA = numA/den
 *   uB = numB/den
 *   x = A.x + uA*A.dx = B.x + uB*B.dx
 *   y = A.y + uA*A.dy = B.y + uB*B.dy
 * Note: if 0 <= uA,uB <= 1, then (x,y) lies within the respective segment
 *
 * Based on information from Paul Bourke
 * at http://astronomy.swin.edu.au/~pbourke/geometry/
 */
static int 
is_intersect(mxtype Ax, mxtype Adx, mxtype Ay, mxtype Ady,
	     mxtype Bx, mxtype Bdx, mxtype By, mxtype Bdy)
{
  mxtype num = Adx * (Ay-By) - Ady * (Ax-Bx);
  mxtype den = Bdy * Adx - Bdx * Ady;
  if (den == 0) { /* A and B are parallel */
    return num == 0.;
  } else { /* A and B intersect, see if it is within segment B */
    mxtype u = num/den;
    return (0. <= u && u <= 1.);
  }
}
static int
intersection(mxtype Ax, mxtype Adx, mxtype Ay, mxtype Ady,
	     mxtype Bx, mxtype Bdx, mxtype By, mxtype Bdy,
	     mxtype *x, mxtype *y)
{
  mxtype num = Adx * (Ay-By) - Ady * (Ax-Bx);
  mxtype den = Bdy * Adx - Bdx * Ady;
  if (den == 0) { /* A and B are parallel */
    *x = Bx + 0.5*Bdx;
    *y = By + 0.5*Bdy;
    return num == 0.;
  } else { /* A and B intersect, see if it is within segment B */
    mxtype u = num/den;
    *x = Bx + u*Bdx;
    *y = By + u*Bdy;
    return (0. <= u && u <= 1.);    
  }
}

/* Find the set of quads traversed by a line.
 * x,y give the indices of the corners; these have dimension m x n
 * idx returns the quad numbers in an m x n grid.
 * n is the fastest varying dimension.
 * The resulting quads are not sorted.
 * Returns the number of quads found, which may be more than maxidx.  This
 * allows you to call once with maxidx==0, allocate space, and call again
 * with maxidx at the correct value.
 */
int mx_slice_find(int n, int m, const mxtype x[], const mxtype y[],
		  mxtype x1, mxtype y1, mxtype x2, mxtype y2,
		  int maxidx, int idx[])
{
  const mxtype dx = x2-x1, dy = y2-y1;
  int i,j;
  int k=0;
  for (i=0; i < m-1; i++) {
    for (j=0; j < n-1; j++) {
      int offset = j+i*n;
      mxtype px1 = x[offset],     py1 = y[offset];
      mxtype px2 = x[offset+1],   py2 = y[offset+1];
      mxtype px3 = x[offset+n+1], py3 = y[offset+n+1];
      mxtype px4 = x[offset+n],   py4 = y[offset+n];
      /* Only need to check three edges since traversal hits at least two */
      if (is_intersect(x1,dx,y1,dy,px1,px2-px1,py1,py2-py1) ||
	  is_intersect(x1,dx,y1,dy,px2,px3-px2,py2,py3-py2) ||
	  is_intersect(x1,dx,y1,dy,px3,px4-px3,py3,py4-py3)) {
	if (k < maxidx) idx[k] = offset;
	k++;
#if 0
      printf("(%g,%g)->(%g,%g) quad %d: (%g,%g) (%g,%g), (%g,%g), (%g,%g)\n",
	     x1,y1,x2,y2,j+i*n,px1,py1, px2,py2, px3,py3, px4,py4);
      printf ("intersect 12: %d\n",is_intersect(x1,dx,y1,dy,px1,px2-px1,py1,py2-py1));
      printf ("intersect 23: %d\n",is_intersect(x1,dx,y1,dy,px2,px3-px2,py2,py3-py2));
      printf ("intersect 34: %d\n",is_intersect(x1,dx,y1,dy,px3,px4-px3,py3,py4-py3));
      printf ("intersect 41: %d\n",is_intersect(x1,dx,y1,dy,px4,px1-px4,py4,py1-py4));
#endif
      }
    }
  }
  return k;
}

static int xycompare(const void *vp, const void *wp)
{
  const mxtype *v = (mxtype*)vp;
  const mxtype *w = (mxtype*)wp;
  return (v[0]>w[0] ? 1 : (v[0]<w[0] ? -1 : (v[1]>w[1] ? 1 : (v[1]<w[1] ? -1 : 0))));
}

static int yxcompare(const void *vp, const void *wp)
{
  const mxtype *v = (mxtype*)vp;
  const mxtype *w = (mxtype*)wp;
  return (v[1]>w[1] ? 1 : (v[1]<w[1] ? -1 : (v[0]>w[0] ? 1 : (v[0]<w[0] ? -1 : 0))));
}

void mx_slice_interp(int m, int n, 
		     const mxtype x[], const mxtype y[], 
		     const mxtype z[], const mxtype dz[],
		     mxtype x1, mxtype y1, mxtype x2, mxtype y2,
		     int nidx, const int idx[], mxtype result[],
		     int interpolate)
{
  const mxtype dx = x2-x1, dy = y2-y1;
  int k;

  for (k=0; k < nidx; k++) {
    /* Retrieve the original quad */
    int offset = idx[k];
    mxtype px1 = x[offset],     py1 = y[offset];
    mxtype px2 = x[offset+1],   py2 = y[offset+1];
    mxtype px3 = x[offset+m+1], py3 = y[offset+m+1];
    mxtype px4 = x[offset+m],   py4 = y[offset+m];
    
    /* Find two points of intersection ... for weird shaped quads with internally
     * crossing lines, only return the first two edges.  This is not guaranteed
     * to be in the actual quad if the quad is not convex, but that will be
     * sufficiently rare that it is not a problem (I hope!).
     */
    mxtype x[2],y[2];
    int p=0;
    if (p < 2 && intersection(x1,dx,y1,dy,px1,px2-px1,py1,py2-py1,x+p,y+p)) p++;
    if (p < 2 && intersection(x1,dx,y1,dy,px2,px3-px2,py2,py3-py2,x+p,y+p)) p++;
    if (p < 2 && intersection(x1,dx,y1,dy,px3,px4-px3,py3,py4-py3,x+p,y+p)) p++;
    if (p < 2 && intersection(x1,dx,y1,dy,px4,px1-px4,py4,py1-py4,x+p,y+p)) p++;
    
    /* Pull the x,y value out as the midpoint of the line through the quad. */
    if (p == 1) {
      result[4*k] = x[0];
      result[4*k+1] = y[0];
    } else {
      result[4*k] = 0.5*(x[0]+x[1]);
      result[4*k+1] = 0.5*(y[0]+y[1]);
    }
    
    /* Pull out the z value */
    if (interpolate) {
      /* interpolation; quads points are vertices and z dim is m x n */
      mxtype z1 = z[offset];
      //mxtype z2 = z[offset+m];
      //mxtype z3 = z[offset+m+1];
      //mxtype z4 = z[offset+1];
      mxtype dz1 = dz[offset];
      //mxtype dz2 = dz[offset+m];
      //mxtype dz3 = dz[offset+m+1];
      //mxtype dz4 = dz[offset+1];
      result[4*k+2] = z1;
      result[4*k+3] = dz1;
    } else {
      /* lookup; quad points are centers and z dim is (m-1)x(n-1) */
      int i = offset/m, j=offset%m;
      result[4*k+2] = z[j+i*(m-1)];
      result[4*k+3] = dz[j+i*(m-1)];
    }
  }

  qsort(result, nidx, 4*sizeof(mxtype), (x1==x2?yxcompare:xycompare)); 
}

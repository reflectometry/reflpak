#include "mx.h"
#include <stdio.h>
#include <stdlib.h>
/* Slice a 2D mesh with a straight line.
 *
 * A point is defined by two vertices (x,y) stored in an array as [x,y].
 *
 * A line is defined by the two points, (x1,y1) and (x2,y2) stored in an
 * array as [L.x,L.y,L.dx,L.dy] = [x1,y1,x2-x1,y2-y1].
 *
 * A mesh is defined by m x n points in row major order.
 *
 * The returned slice is a list of every quadrilateral on the mesh
 * which is traversed by the line.  The slice is not ordered..
 *
 * The basic algorithm is as follows:
 *
 * 1. Traverse the boundary looking for intersections between the segment
 *    on the boundary and the line.
 * 2. Whenever a intersection is found, shoot through the mesh in order
 *    of increasing position on the line.
 */

/* Based on information from Paul Bourke
 * at http://astronomy.swin.edu.au/~pbourke/geometry/
 *
 * Nearest point on a line L to point P:
 *   u = ((P.x - L.x) * L.dx + (P.y-L.y) * L.dy)/(L.dx^2 + L.dy^2)
 *   x = L.x + u*L.dx
 *   y = L.y + u*L.dy
 * Note: if 0 <= u <= 1, then (x,y) lies within the segment.
 *
 * Intersection of two lines A,B:
 *   numA = B.dx * (A.y - B.y) - B.dy * (A.x - B.x)
 *   numB = A.dx * (A.y - B.y) - A.dy * (A.x - B.x)
 *   den = B.dy * A.dx - B.dx * A.dy
 *   uA = numA/den
 *   uB = numB/den
 *   x = A.x + uA*A.dx = B.x + uB*B.dx
 *   y = A.y + uA*A.dy = B.y + uB*B.dy
 * Note: if 0 <= uA,uB <= 1, then (x,y) lies within the respective segment
 */


/* t = intersect(L,P1x,P1y,P2x,P2y,&u)
 *
 * Return true if the line segment defined by points P1 = (P1x,P1y) 
 * and P2 = (P2x,P2y) intersects the line L = [x,y,dx,dy].
 * Sets the position on the line u as follows:
 *   u < 0: intersection is before (x,y)
 *   u = 0: intersection is at (x,y)
 *   0<u<1: intersection is within (x,y) and (x+dx,y+dy)
 *   u = 1: intersection is at (x+dx,y+dy)
 *   u > 1: intersection is after (x+dx,y+dy)
 * If P1=P2 then the line segment is a point, and no intersection is returned.
 */
inline int
intersect(const mxtype L[], 
	  const mxtype P1x, const mxtype P1y,
	  const mxtype P2x, const mxtype P2y,
	  double *position_on_line)
{
  const double Pdx = P2x-P1x;
  const double Pdy = P2y-P1y;
  const double denominator = Pdy * L[2] - Pdx * L[3];

  //  printf("[%g,%g,%g,%g] and (%g,%g),(%g,%g)",L[0],L[1],L[2],L[3],P1x,P1y,P2x,P2y);
  if (denominator != 0) {
    /* P1-P2 defines a line segment */
    const double crossX = L[0] - P1x;
    const double crossY = L[1] - P1y;
    const double numeratorP = L[2] * crossY - L[3] * crossX;
    const double position_on_segment = numeratorP/denominator;
    if (position_on_segment >= 0. && position_on_segment < 1.) {
      const double numeratorL = Pdx * crossY - Pdy * crossX;
      *position_on_line = numeratorL/denominator;
      // printf(" intersect at Pu=%g, Lu=%g\n",position_on_segment,*position_on_line);
      return 1;
    }
    // printf(" intersect at Pu=%g (off segment)\n",position_on_segment); return 0;
  }
  // printf(" are parallel\n");
  return 0;
}

// Helper function for slice_mesh.
// Step through the grid starting at index i and going in direction
// STEP.  By ordering the segments in increasing order of where they
// intersect line L, we can make sure that we are not doing too much
// extra work and introducing too many duplicate indices.
typedef enum { STEP_RIGHT, STEP_DOWN, STEP_LEFT, STEP_UP } Step;
static void 
step_through_mesh(size_t m, size_t n,
		  const mxtype x[], const mxtype y[],
		  const mxtype L[],
		  size_t Nidx, size_t idx[], size_t *last,
		  double u, size_t i, Step step)
{
  const size_t cstep = m;
  const size_t rstep = 1;
  const size_t bstep = rstep+cstep;
  int il, it, ir, ib;
  double l=0., t=0., r=0., b=0.;
  printf("new shot\n");
  while (1) {
    printf("stepping %d from position %d\n",step,i);
    if (i+bstep >= n*m) {
      printf("out of range with i=%d\n",i);
      return;
    }
    il = step!=STEP_RIGHT 
      && intersect(L,x[i],y[i],x[i+rstep],y[i+rstep],&l);
    it = step!=STEP_DOWN 
      && intersect(L,x[i+cstep],y[i+cstep],x[i],y[i],&t);
    ir = step!=STEP_LEFT 
      && intersect(L,x[i+bstep],y[i+bstep],x[i+cstep],y[i+cstep],&r);
    ib = step!=STEP_UP 
      && intersect(L,x[i+rstep],y[i+rstep],x[i+bstep],y[i+bstep],&b);
    il = il && l >= u;
    it = it && t >= u;
    ir = ir && r >= u;
    ib = ib && b >= u;
    if (il || it || ir || ib) {
      printf("adding %d at position %d\n",i,*last);
      if (*last < Nidx) idx[*last] = i;
      else {printf("overflow\n"); exit(1);}
      ++*last;
    } else {
      printf("no borders intersect L\n");
      return;
    }
    printf("is[l,r,t,b]=[%d,%d,%d,%d]\n",il,ir,it,ib);
    if (il && (!it || l < t) && (!ir || l < r) && (!ib || l < b)) {
      if (i < cstep) return;
      u=l; i-=cstep; step=STEP_LEFT;
    } else if (it && (!ir || t < r) && (!ib || t < b)) {
      if (i < rstep) return;
      u=t; i-=rstep; step=STEP_UP;
    } else if (ir && (!ib || r < b)) {
      u=r; i+=cstep; step=STEP_RIGHT;
    } else if (ib) {
      u=b; i+=rstep; step=STEP_DOWN;
    } else {
      printf("Can't get here!\n");
      exit(0);
    }
  }
}


// Take a 1-D slice through a 2-D mesh.
// Mesh is represented by m X n grid of x,y for the corner points of
// the quadrilaterals containing each mesh point.
// The slice direction is represented as an array containing [x,y,dx,dy].
// A maximum of Nidx values are returned in the array idx.  These are the
// offsets of the top left corner of each quad in the mesh.
// Returns the number of grid points traversed.  Note that this may be
// greater than the number of index values available in the array, in which
// case you should rerun the slicing algorithm with at least the new number
// of indices.
int
mx_slice(const size_t m, const size_t n, 
	 const mxtype x[], const mxtype y[],
	 const mxtype L[], size_t Nidx, size_t idx[])
{
  const size_t cstep = m;
  const size_t rstep = 1;
  const size_t bottom = (m-1)*rstep;
  const size_t right = (n-1)*cstep;
  size_t i, last = 0;
  double u;

  // Note: we want the assignment of point on the boundary of
  // the rectangle to edge be a unique mapping. To do this, we
  // are testing for intersection of the line with a semi-open 
  // segment for each edge so that each corner only belongs to
  // one segment.  Null segments (those with zero length) do not
  // intersect the line.  We can do this with only one piece of
  // intersection code by choosing the order of the points in the
  // call and always accepting [0,1).

  // Traverse left border
  printf("== left\n");
  for (i=0; i < bottom; i+=rstep) {
    if (intersect(L,x[i],y[i],x[i+rstep],y[i+rstep],&u))
      step_through_mesh(m,n,x,y,L,Nidx,idx,&last,u,i,STEP_RIGHT);
  }

  // Traverse top border
  printf("== top\n");
  for (i=0; i < right; i+=cstep) {
    if (intersect(L,x[i+cstep],y[i+cstep],x[i],y[i],&u))
      step_through_mesh(m,n,x,y,L,Nidx,idx,&last,u,i,STEP_DOWN);
  }

  // Traverse bottom border
  printf("== bottom\n");
  for (i=bottom; i < bottom+right; i+=cstep) {
    if (intersect(L,x[i],y[i],x[i+cstep],y[i+cstep],&u))
      step_through_mesh(m,n,x,y,L,Nidx,idx,&last,u,i-rstep,STEP_UP);
  }

  // Traverse right boundary
  printf("== right\n");
  for (i=right; i < bottom+right; i+=rstep) {
    if (intersect(L,x[i+rstep],y[i+rstep],x[i],y[i],&u))
      step_through_mesh(m,n,x,y,L,Nidx,idx,&last,u,i-cstep,STEP_LEFT);
  }

  // Return the number of points in the slice
  return last;
}


#ifdef TEST

#include <stdio.h>

void test_regular(void)
{
  const mxtype x[] = { 0,0,0,0,0,1,1,1,1,1,2,2,2,2,2,3,3,3,3,3 };
  const mxtype y[] = { 4,3,2,1,0,4,3,2,1,0,4,3,2,1,0,4,3,2,1,0 };
  const mxtype vert[] = {0.5,0,0,1};
  const mxtype horz[] = {0,0.5,1,0};
  const mxtype edge[] = {0,0,1,0};
  const mxtype miss[] = {-1,-1,-1,-1};
  const mxtype diag[] = {0,0,1,1};
  const mxtype corner[]      = {0,0,-1,-1};
  const mxtype inside_edge[] = {0,1,1,0};
  const mxtype slope2[]      = {0,0,1,2};
  const mxtype diag_middle[] = {0,0.5,1,1};
  const mxtype Rvert[] = {0.5,0,0,-1};
  const mxtype Rhorz[] = {0,0.5,-1,0};
  const mxtype Rdiag[] = {0,0,-1,-1};
  const mxtype adiag[] = {0,3,1,-1};
  const mxtype Radiag[] = {0,3,-1,1};
  const size_t m=5,n=4,Nidx = 10;
  size_t idx[Nidx], i, k;

#undef DO_TEST
#define DO_TEST(L) do { \
    k = mx_slice(m,n,x,y,L,Nidx,idx); \
    printf("%s (%g,%g) (%g,%g): %d quads.\n",#L,L[0],L[1],L[0]+L[2],L[1]+L[3],k); \
    for (i=0; i < k; i++) printf("%d->(%g,%g) ",idx[i],x[idx[i]],y[idx[i]]); \
    printf("\n"); \
  } while (0)

  DO_TEST(diag);
  DO_TEST(Rdiag);
  DO_TEST(adiag);
  DO_TEST(Radiag);
  DO_TEST(diag_middle);
  DO_TEST(slope2);
  DO_TEST(Rhorz);
  DO_TEST(Rvert);
  DO_TEST(miss);
  DO_TEST(horz);
  DO_TEST(vert);
  DO_TEST(edge);
  DO_TEST(corner);
  DO_TEST(inside_edge);
}

int main(int argc, char *argv[])
{
  test_regular();  
  return 0;
}

#endif

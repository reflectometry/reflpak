/* To compile the test program, modify the configuration information at
   the start of this file for your compiler and type:

      cc slice.c -o slice

*/

#define TEST
#define HAVE_INLINE
#define HAVE___FUNCTION__
#undef HAVE_MXTYPE

/* ==== end configurate information === */

#ifdef HAVE_MXTYPE  /* Whether we need mx.h */
# include "mx.h"
#else
# define mxtype double
#endif

#ifndef HAVE___FUNCTION__
# define __FUNCTION__ "slice.c"
#endif

#ifndef HAVE_INLINE
# define inline
#endif


#include <math.h>
#include <stdio.h>
#include <stdlib.h>


/* Slice a 2D mesh with a straight line.
 *
 * A point is defined by two vertices (x,y).
 *
 * A line is defined by the two points, (x1,y1) and (x2,y2) stored in an
 * array as [L.x,L.y,L.dx,L.dy] = [x1,y1,x2-x1,y2-y1].
 *
 * A mesh is defined by m x n points in x and y matrices stored in row major.
 *
 * The returned slice is a list of every quadrilateral on the mesh
 * which is traversed by the line.  Quadrilaterals are defined by the
 * index in the x,y matrix of first corner of the quad (that is, the lowest
 * numbered x,y index of all the corners of the quad).
 *
 * When the slice overlays an edge use the higher numbered quad for the
 * slice.  That is, if it is between row 3 and row 4, use row 4.  If it is
 * between column 3 and column 4 use column 4.
 *
 * When the slice only intersects the edge at a single corner, don't include
 * the quad for that corner.
 */

/*
 * The basic algorithm is as follows:
 *
 * 1. Traverse the boundary looking for intersections between the segment
 *    on the boundary and the line.
 * 2. Whenever a intersection is found, shoot through the mesh in order
 *    of increasing position on the line.
 *
 * The current implementation only moves from a quad to one of its
 * neighbours.  It needs to choose a neighbour that can actually be entered
 * from the quad (including along an edge), skipping those which it only
 * intercepts at the corner.
 */

#define DEBUG 0


#ifndef FAIL
#define FAIL(msg) do { \
    printf("%s(%d): %s\n",__FUNCTION__,__LINE__,msg); exit(0); \
  } while (0)
#endif

#if DEBUG>=3
#define LOG3(msg) do { \
    printf("%s(%d): ",__FUNCTION__,__LINE__); msg; printf("\n"); \
  } while (0)
#else
#define LOG3(msg) do {} while (0)
#endif

#if DEBUG>=2
#define LOG2(msg) do { \
    printf("%s(%d): ",__FUNCTION__,__LINE__); msg; printf("\n"); \
  } while (0)
#else
#define LOG2(msg) do {} while (0)
#endif

/* t = intersect(L,P1x,P1y,P2x,P2y,&u)
 *
 * Return true if the line segment defined by points P1 = (P1x,P1y) 
 * and P2 = (P2x,P2y) intersects the line L = [Lx,Ly,Ldx,Ldy].
 *
 * Sets the position u on the line L as follows:
 *   u < 0: intersection is before (Lx,Ly)
 *   u = 0: intersection is at (Lx,Ly)
 *   0<u<1: intersection is within (Lx,Ly) and (Lx+Ldx,Ly+Ldy)
 *   u = 1: intersection is at (Lx+Ldx,Ly+Ldy)
 *   u > 1: intersection is after (Lx+Ldx,Ly+Ldy)
 * If P1=P2 then the line segment is a point, and no intersection is returned.
 *
 * Algorithm:
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
 *
 * Based on information from Paul Bourke
 * at http://astronomy.swin.edu.au/~pbourke/geometry/
 */
inline int
intersect(const mxtype L[], 
	  const mxtype P1x, const mxtype P1y,
	  const mxtype P2x, const mxtype P2y,
	  double *position_on_segment,
	  double *position_on_line)
{
  const double Lx = L[0];
  const double Ly = L[1];
  const double Ldx = L[2];
  const double Ldy = L[3];
  const double Pdx = P2x-P1x;
  const double Pdy = P2y-P1y;
  const double denominator = Pdy * Ldx - Pdx * Ldy;
  const double crossX = Lx - P1x;
  const double crossY = Ly - P1y;

  LOG3(printf("[%g,%g,%g,%g] and (%g,%g),(%g,%g)",L[0],L[1],L[2],L[3],P1x,P1y,P2x,P2y));
  if (denominator != 0) {
    /* P1-P2 defines a line segment that may or may not intersect L */
    const double numeratorP = Ldx * crossY - Ldy * crossX;
    *position_on_segment = numeratorP/denominator;
    if (*position_on_segment > 0. && *position_on_segment <= 1.) {
      /* P1-P2 intersects L */
      const double numeratorL = Pdx * crossY - Pdy * crossX;
      *position_on_line = numeratorL/denominator;
      LOG3(printf(" intersect at Pu=%g, Lu=%g",*position_on_segment,*position_on_line));
      return 1;
    }
    // printf(" intersect at Pu=%g (off segment)\n",position_on_segment);
  } else {
    /* P1-P2 defines a line segment parallel to L */
    const double u = -(crossX*Ldx + crossY*Ldy) / (Ldx*Ldx + Ldy*Ldy);
    const double Nx = Lx + u * Ldx;
    const double Ny = Ly + u * Ldy;
    if (Nx == P1x && Ny == P1y) {
      /* P1-P2 lies on L, return position of far end */
      *position_on_line = (fabs(Ldx)>fabs(Ldy)?(P2x-Lx)/Ldx:(P2y-Ly)/Ldy);
// HELP! What do we return if the lines overlap!!
      LOG3(printf(" overlap (Lu=%g)",*position_on_line));
      return 1;
    }
    LOG3(printf(" are parallel"));
  }
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
  double p, l=u, t=u, r=u, b=u;
  LOG2(printf("start stepping through mesh"));
  while (1) {
    LOG2(printf("stepping %d from position %d",step,i));
    il = step!=STEP_RIGHT 
      && intersect(L,x[i],y[i],x[i+rstep],y[i+rstep],&p,&l);
    it = step!=STEP_DOWN 
      && intersect(L,x[i],y[i],x[i+cstep],y[i+cstep],&p,&t);
    ir = step!=STEP_LEFT 
      && intersect(L,x[i+cstep],y[i+cstep],x[i+bstep],y[i+bstep],&p,&r);
    ib = step!=STEP_UP 
      && intersect(L,x[i+rstep],y[i+rstep],x[i+bstep],y[i+bstep],&p,&b);
    if (l > u || t > u || r > u || b > u) {
      il = il && l > u;
      it = it && t > u;
      ir = ir && r > u;
      ib = ib && b > u;
    } else {
      il = il && l == u;
      it = it && t == u;
      ir = ir && r == u;
      ib = ib && b == u;
    }
    if (il || it || ir || ib) {
      LOG2(printf("adding %d at position %d",i,*last));
      if (*last < Nidx) idx[*last] = i;
      else if (*last > n*m) { FAIL("overflow in mesh_slice"); }
      ++*last;
    } else {
      LOG2(printf("no borders intersect L"));
      return;
    }
    LOG2(printf("is[l,r,t,b]=[%d,%d,%d,%d]",il,ir,it,ib));
    if (il && (!it || l < t) && (!ir || l < r) && (!ib || l < b)) {
      if (i/m == 0) return;
      u=l; i-=cstep; step=STEP_LEFT;
    } else if (it && (!ir || t < r) && (!ib || t < b)) {
      if (i%m == 0) return;
      u=t; i-=rstep; step=STEP_UP;
    } else if (ir && (!ib || r < b)) {
      if (i/m == n-2) return;
      u=r; i+=cstep; step=STEP_RIGHT;
    } else if (ib) {
      if (i%m == m-2) return;
      u=b; i+=rstep; step=STEP_DOWN;
    } else {
      FAIL("Can't get here!");
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
  double p,u;

  // Note: we want the assignment of point on the boundary of
  // the rectangle to edge be a unique mapping. To do this, we
  // are testing for intersection of the line with a semi-open 
  // segment for each edge so that each corner only belongs to
  // one segment.  Null segments (those with zero length) do not
  // intersect the line.  We can do this with only one piece of
  // intersection code by choosing the order of the points in the
  // call and always accepting [0,1).

  // Traverse left border
  LOG2(printf("== left"));
  for (i=0; i < bottom; i+=rstep) {
    if (intersect(L,x[i],y[i],x[i+rstep],y[i+rstep],&p,&u))
      step_through_mesh(m,n,x,y,L,Nidx,idx,&last,u,i,STEP_RIGHT);
  }

  // Traverse top border
  LOG2(printf("== top"));
  for (i=0; i < right; i+=cstep) {
    if (intersect(L,x[i],y[i],x[i+cstep],y[i+cstep],&p,&u)) {
      double v;
      /* Avoid contention for left corner */
      if (i!=0 || intersect(L,x[i+cstep],y[i+cstep],x[i],y[i],&p,&v))
	step_through_mesh(m,n,x,y,L,Nidx,idx,&last,u,i,STEP_DOWN);
    }
  }

  // Traverse bottom border
  LOG2(printf("== bottom"));
  for (i=bottom; i < bottom+right; i+=cstep) {
    if (intersect(L,x[i],y[i],x[i+cstep],y[i+cstep],&p,&u))
      step_through_mesh(m,n,x,y,L,Nidx,idx,&last,u,i-rstep,STEP_UP);
  }

  // Traverse right boundary
  LOG2(printf("== right"));
  for (i=right; i < bottom+right; i+=rstep) {
    if (intersect(L,x[i],y[i],x[i+rstep],y[i+rstep],&p,&u))
      step_through_mesh(m,n,x,y,L,Nidx,idx,&last,u,i-cstep,STEP_LEFT);
  }

  // Return the number of points in the slice
  return last;
}


#ifdef TEST

#include <stdio.h>

void list_quads(const char name[], int k, const size_t idx[], 
		const mxtype x[], const mxtype y[])
{
  int i;

  printf("%s %d: [", name, k);
  if (k == 0) {
    printf("]");
  } else {
    for (i=0; i < k; i++) printf("%d%c",idx[i],(i<k-1?' ':']'));
//    for (i=0; i < k; i++) printf(" (%g,%g)",x[idx[i]],y[idx[i]]);
  }
  printf("\n");
}

void do_test(const size_t m, const size_t n,
	     const mxtype x[], const mxtype y[],
	     const mxtype Lx, const mxtype Ly, 
	     const mxtype Ldx, const mxtype Ldy,
	     const char *name, 
	     size_t Nexpected, const size_t expected[])
{
  const size_t Nidx = 10;
  size_t idx[Nidx], k, i;
  mxtype L[4];
  int success;

  if (expected == NULL) { Nexpected = 0; } 
  printf("%s (x,y)=(%g,%g) (dx,dy)=(%g,%g)\n",name,Lx,Ly,Ldx,Ldy);

  // Try forward
  L[0] = Lx; L[1] = Ly; L[2] = Ldx; L[3] = Ldy;
  k = mx_slice(m,n,x,y,L,Nidx,idx);
  list_quads(" forward",k,idx,x,y);

  success = (k == Nexpected);
  if (success) for(i=0; i < k; i++) success = success && (idx[i]==expected[i]);
  if (!success) {
    if (Nexpected == 0) printf("**expected []");
    else {
      printf(" *** expected [");
      for(i=0;i<Nexpected;i++) 
	printf("%d%c",expected[i],i==Nexpected-1?']':' ');
    }
    printf("\n");
  }

  // Try reverse
  L[2] = -Ldx; L[3] = -Ldy;
  k = mx_slice(m,n,x,y,L,Nidx,idx);
  list_quads(" reverse",k,idx,x,y);

  success = (k == Nexpected);
  if (success) 
    for(i=0; i < k; i++) success = success && (idx[k-i-1]==expected[i]);
  if (!success) {
    if (Nexpected == 0) printf("**expected []");
    else {
      printf(" *** expected [");
      for(i=0;i<Nexpected;i++) 
	printf("%d%c",expected[Nexpected-i-1],i==Nexpected-1?']':' ');
    }
    printf("\n");
  }

}

#undef DO_TEST
#define DO_TEST(name,Lx,Ly,Ldx,Ldy) \
    do_test(m,n,x,y,Lx,Ly,Ldx,Ldy,#name,sizeof(E)/sizeof(*E),E)


void test_regular(void)
{
  /*  Regular mesh

+--+--+--+
| 0| 5|10|
+--+--+--+
| 1| 6|11|
+--+--+--+
| 2| 7|12|
+--+--+--+
| 3| 8|13|
+--+--+--+

   */
  const size_t m=5,n=4;
  const mxtype x[] = { 0,0,0,0,0,1,1,1,1,1,2,2,2,2,2,3,3,3,3,3 };
  const mxtype y[] = { 4,3,2,1,0,4,3,2,1,0,4,3,2,1,0,4,3,2,1,0 };

  printf("\n\n=== line intersects segment in the middle ===\n");
  { size_t *E= NULL;        DO_TEST(miss,-1,-1,-1,1);     }
  { size_t E[]= {3,2,1,0}; DO_TEST(vert,0.5,0,0,1);      }
  { size_t E[]= {3,8,13};  DO_TEST(horz,0,0.5,1,0);      }
  { size_t E[]= {3,2,1,6,5}; DO_TEST(slope 2.1,0,0,1,2.1);      }
  { size_t E[]= {3,2,7,6,11,10}; DO_TEST(diag middle,0,0.5,1,1); }

  printf("\n\n=== line intersects segment along an edge ===\n");
  { size_t E[]= {0,5,10};  DO_TEST(top,   0,4,1,0); }
  { size_t E[]= {2,7,12};  DO_TEST(middle,0,2,1,0); }
  { size_t E[]= {3,8,13};  DO_TEST(bottom,0,0,1,0); }
  { size_t E[]= {0,1,2,3};     DO_TEST(left,  0,0,0,-1); }
  { size_t E[]= {5,6,7,8};     DO_TEST(middle,1,0,0,-1); }
  { size_t E[]= {10,11,12,13}; DO_TEST(right, 3,0,0,-1); }

  printf("\n\n=== line intersects segment on a corner ===\n");
  { size_t E[]= {3,7,11};  DO_TEST(diag,0,0,1,1);        }
  { size_t E[]= {3,7,11};  DO_TEST(diag2,-1,-1,1,1);     }
  { size_t E[]= {1,7,13};  DO_TEST(adiag,0,3,1,-1);      }
  { size_t *E= NULL;        DO_TEST(corner,0,0,-1,1);     }
  { size_t E[]= {3,2,6,5}; DO_TEST(slope 2,0,0,1,2);      }
}

void test_warped(void)
{

  const size_t m=5,n=4;
  const mxtype x[] = {  0,0,0,0,0,  5,4,3,2,1, 10,8,6,4,2, 10,8,6,4,2 };
  const mxtype y[] = { 10,8,6,4,2, 10,8,6,4,2,  5,4,3,2,1,  0,0,0,0,0 };

  printf("\n\n=== warped mesh ===\n");
printf("\n\
x----------x\n\
|0        . \\\n\
x--------x   \\\n\
|1      . \\  5\\\n\
x------x   \\   \\\n\
|2    . \\ 6 \\   \\\n\
x----x   \\   \\   x\n\
|3  . \\7  \\   x  |\n\
x--x 8 \\   x  |  |\n\
    \\   x  |  |  |\n\
     x  |  |  |  |\n\
     |13|12|11|10|\n\
     x--x--x--x--X\n");

  { size_t E[]= {2,3,8,13,12};  DO_TEST(connected,0,4.5,1,-1);  }
  printf("The next test could go either way since it is two separate segments\n");
  { size_t E[]= {3,13};         DO_TEST(disjoint,0,2.5,1,-1); }
  { size_t E[]= {2,7,6,5};      DO_TEST(borderpoint,0,4,2,1); }
  { size_t E[]= {5};            DO_TEST(borderline,15,0,1,-1); }
  { size_t E[]= {3,2,6,5};      DO_TEST(interiorpoint,0,3,1,1); }
  { size_t E[]= {2,7,12};       DO_TEST(interiorline,0,6,1,-1); }
}

void test_degenerate(void)
{

  /* 

Degenerate mesh

+--+--+--+
|0 |3/ 6 |
+--*-----+
|1 |4\ 7 |
+--+--+--+

  */

  const size_t m=3,n=4;
  const mxtype x[] = { 0,0,0, 1,1,1, 2,1,2, 3,3,3 };
  const mxtype y[] = { 2,1,0, 2,1,0, 2,1,0, 2,1,0 };

  printf("\n\n=== degenerate mesh (some edges have zero length) ===\n");
  { size_t E[]= {4,7,6,3};     DO_TEST(miss,1,1.5,0,1); }
  { size_t E[]= {1,3};         DO_TEST(point,1,1,1,2); }
  { size_t E[]= {1,6};         DO_TEST(edge,1,1,1,1); }
  { size_t E[]= {1,6};         DO_TEST(pointskip,1,1,2,1); }
  { size_t E[]= {4,3};         DO_TEST(vert,1,0,0,1); }
}


void test_twisted1(void)
{

  /*

Twisted mesh with twist inside the quads

+--+--+--+
| 0| 4| 8|
+--+--+--+
  .1 .5\ |  <-- 9
        .|.
   9 --> |\ 5 . 1 .
         +--+--+--+
         |10| 6| 2|
         +--+--+--+
  */

  const size_t m=4,n=4;
  const mxtype x[] = {-3,-3,3,3, -2,-2,2,2, -1,-1,1,1, 0,0,0,0   };
  const mxtype y[] = {2,1,-1,-2, 2,1,-1,-2, 2,1,-1,-2, 2,1,-1,-2 };

  printf("\n\n=== twisted mesh (some edges have negative length) ===\n");
  { size_t E[]= {1,5,8};      DO_TEST(twist1,0,0.5,1,0); }
  { size_t E[]= {8,5,1};      DO_TEST(twist2,0,-0.5,1,0); }
  printf("the following may not be the right 'expected'\n");
  { size_t E[]= {1,5,8};      DO_TEST(origin,0,0,1,1); }
  { size_t E[]= {10,9,8};     DO_TEST(twist3,0,0,-1,4); }
  { size_t E[]= {2,6,5,4,0};  DO_TEST(twist4,0,0,-3,2); }
  { size_t E[]= {6,5,4};      DO_TEST(edge,0,0,-1,1); }
  { size_t E[]= {10,9,1,5,9,8,4}; DO_TEST(disjoint,1,-2,-3,5); }
  { size_t E[]= {10,1,0};     DO_TEST(moredisjoint,1,-2,-1,1); }
}

void test_twisted2(void)
{
  /*

Twisted mesh with twist between the quads.

+--+--+--+
| 0| 5|10|
+--+--+--+
  .1 .6\ | <-- 11
         +
  12 --> |\ 7 . 2 .
         +--+--+--+
         |13| 8| 3|
         +--+--+--+
  */

  const size_t m=5,n=4;
  const mxtype x[] = {-3,-3,0,3,3, -2,-2,0,2,2, -1,-1,0,1,1, 0,0,0,0,0   };
  const mxtype y[] = {2,1,0,-1,-2, 2,1,0,-1,-2, 2,1,0,-1,-2, 2,1,0,-1,-2 };

  printf("\n\n=== twisted mesh (some edges have zero length) ===\n");
  { size_t E[]= {1,6,11};      DO_TEST(twist1,0,0.5,1,0); }
  { size_t E[]= {12,7,2};      DO_TEST(twist2,0,-0.5,1,0); }
  { size_t *E=NULL;            DO_TEST(origin,0,0,1,1); }
  { size_t E[]= {13,12,11,10}; DO_TEST(twist3,0,0,-1,4); }
  { size_t E[]= {3,8,7,6,5,0}; DO_TEST(twist4,0,0,-3,2); }
  { size_t E[]= {8,7,6,5};     DO_TEST(edge,0,0,-1,1); }
  { size_t E[]= {13,12,1,6,11,10,5}; DO_TEST(disjoint,1,-2,-3,5); }
  { size_t E[]= {13,1,0};     DO_TEST(moredisjoint,1,-2,-1,1); }
}

void test_nonconvex(void)
{

  /*
Mesh with non-convex node #5

+--+
|0 |  .
+--+.   .
|1  \ . 4 .
|    \  .   .
+-----+5 +--+
|2 . / . |  |
++ 6/.   |  |
 +-+     |  |
 10|    9| 8|
 +-+-----+--+


  */

  const size_t m=4, n=4;
  const mxtype x[] = {0,0,0,0, 2,2,4,1, 8,6,2,1, 8,6,2,1};
  const mxtype y[] = {8,6,4,3, 8,6,4,3, 4,4,2,2, 0,0,0,0};

  printf("\n\n=== non-concave quad in mesh ===\n");
  { size_t E[] = {10,6,2,1,0};    DO_TEST(miss,1.5,0,0,1); }
  printf("Should 5 appear twice ??\n");
  { size_t E[] = {9,5,6,2,1,5,4}; DO_TEST(reenter,3,0,0,1); }
  { size_t E[] = {9,5,4};         DO_TEST(corner,4,0,0,1); }
  { size_t E[] = {9,5,4};         DO_TEST(center,5,0,0,1); }
  { size_t E[] = {8,4};           DO_TEST(miss,6,0,0,1); }
}



int main(int argc, char *argv[])
{
  test_regular();
  test_warped();
  test_degenerate();
  test_twisted1();
  test_twisted2();
  return 0;
}

#endif

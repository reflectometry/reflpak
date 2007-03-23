/* To compile the test program, modify the configuration information at
   the start of this file for your compiler and type:

      cc slice.c -o slice

*/

#define HAVE_INLINE         /* If inline works on your compiler */
#define HAVE___FUNCTION__   /* If your compiler defines the __FUNCTION__ macro */
#undef HAVE_MXTYPE          /* If you are including "mx.h" */

/* ==== end configurate information === */

#ifndef HAVE___FUNCTION__
# define __FUNCTION__ "slice.c"
#endif

#ifndef HAVE_INLINE
# define inline
#endif


#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include "mx.h"

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
#define TRANSPOSE


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


#include <stdio.h>

void printmesh(int m, int n, const mxtype x[], const mxtype y[])
{
  int i,j;
  for (i=0; i < m; i++) {
    for (j=0; j < n; j++) {
      printf("%g,%g  ",x[j*m+i],y[j*m+i]);
    }
    printf("\n");
  }
}



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

int ucomp(const void *a,const void *b) { 
  return *(size_t*)a < *(size_t*)b ? -1 : (*(size_t*)a==*(size_t*)b ? 0 : 1);
}
void sort(size_t n, size_t idx[])
{
  qsort(idx,n,sizeof(size_t),ucomp);
}
void transpose(int m, int n, int Nx, int x[]) 
{
  int k;
#ifdef TRANSPOSE
  for (k=0; k < Nx; k++) {
    int i=x[k]%m,j=x[k]/m;
    x[k] = j+i*n;
  }
#endif  
}
void do_test(const size_t m, const size_t n,
	     mxtype x[], mxtype y[],
	     const mxtype Lx, const mxtype Ly, 
	     const mxtype Ldx, const mxtype Ldy,
	     const char *name, 
	     size_t Nexpected, size_t expected[])
{
  const size_t Nidx = 15;
  size_t idx[Nidx], Nfound, i;
  mxtype L[4];
  int success;

  if (expected == NULL) { Nexpected = 0; } 
  printf("%s (x,y)=(%g,%g) (dx,dy)=(%g,%g)\n",name,Lx,Ly,Ldx,Ldy);
  transpose(m,n,Nexpected,expected);
  sort(Nexpected,expected);

  // Try forward
  L[0] = Lx; L[1] = Ly; L[2] = Ldx; L[3] = Ldy;
#ifdef TRANSPOSE
  mx_transpose(m,n,x,x); mx_transpose(m,n,y,y);
  //printmesh(n,m,x,y);
  Nfound = mx_slice_find(n,m,x,y,Lx,Ly,Lx+Ldx,Ly+Ldy,Nidx,idx);
  mx_transpose(n,m,x,x); mx_transpose(n,m,y,y);
#else
  Nfound = mx_slice_find(m,n,x,y,Lx,Ly,Lx+Ldx,Ly+Ldy,Nidx,idx);
#endif
  if (Nfound > Nidx) Nfound = Nidx; /* Slice works as counter */
  sort(Nfound,idx);
  list_quads(" forward",Nfound,idx,x,y);

  success = (Nfound == Nexpected);
  if (success) for(i=0; i < Nfound; i++) {
    success = success && (idx[i]==expected[i]);
  }
  if (!success) {
    if (Nexpected == 0) printf("**expected []");
    else {
      printf(" *** expected [");
      for(i=0;i<Nexpected;i++) 
	printf("%d%c",expected[i],i==Nexpected-1?']':' ');
    }
    printf("\n");
  }
  transpose(n,m,Nexpected,expected);

#if 0
  // Try reverse
  L[2] = -Ldx; L[3] = -Ldy;
  Nfound = mx_slice_find(m,n,x,y,Lx,Ly,Lx+Ldx,Ly+Ldy,Nidx,idx);
  if (Nfound > Nidx) Nfound = Nidx; /* Slice works as counter */
  sort(Nfound,idx);
  list_quads(" reverse",Nfound,idx,x,y);

  success = (Nfound == Nexpected);
  if (success) 
    for(i=0; i < Nfound; i++) success = success && (idx[i]==expected[i]);
  if (!success) {
    if (Nexpected == 0) printf("**expected []");
    else {
      printf(" *** expected [");
      for(i=0;i<Nexpected;i++) 
	printf("%d%c",expected[Nexpected-i-1],i==Nexpected-1?']':' ');
    }
    printf("\n");
  }
#endif

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
  mxtype x[] = { 0,0,0,0,0,1,1,1,1,1,2,2,2,2,2,3,3,3,3,3 };
  mxtype y[] = { 4,3,2,1,0,4,3,2,1,0,4,3,2,1,0,4,3,2,1,0 };

  printf("\n\n=== line intersects segment in the middle ===\n");
  printmesh(5,4,x,y);
  { size_t *E= NULL;        DO_TEST(miss,-1,-1,-1,1);     }
  { size_t E[]= {3,2,1,0}; DO_TEST(vert,0.5,0,0,1);      }
  { size_t E[]= {3,8,13};  DO_TEST(horz,0,0.5,1,0);      }
  { size_t E[]= {3,2,1,6,5}; DO_TEST(slope 2.1,0,0,1,2.1);      }
  { size_t E[]= {3,2,7,6,11,10}; DO_TEST(diag middle,0,0.5,1,1); }

  printf("\n\n=== line intersects segment along an edge ===\n");
  printmesh(5,4,x,y);
  { size_t E[]= {0,5,10};  DO_TEST(top,   0,4,1,0); }
  { size_t E[]= {2,7,12};  DO_TEST(middle,0,2,1,0); }
  { size_t E[]= {3,8,13};  DO_TEST(bottom,0,0,1,0); }
  { size_t E[]= {0,1,2,3};     DO_TEST(left,  0,0,0,-1); }
  { size_t E[]= {5,6,7,8};     DO_TEST(middle,1,0,0,-1); }
  { size_t E[]= {10,11,12,13}; DO_TEST(right, 3,0,0,-1); }

  printf("\n\n=== line intersects segment on a corner ===\n");
  printmesh(5,4,x,y);
  { size_t E[]= {3,7,11};  DO_TEST(diag,0,0,1,1);        }
  { size_t E[]= {3,7,11};  DO_TEST(diag2,-1,-1,1,1);     }
  { size_t E[]= {1,7,13};  DO_TEST(adiag,0,3,1,-1);      }
  { size_t *E= NULL;        DO_TEST(corner,0,0,-1,1);     }
  { size_t E[]= {3,2,6,5}; DO_TEST(slope 2,0,0,1,2);      }
}

void test_warped(void)
{

  const size_t m=5,n=4;
  mxtype x[] = {  0,0,0,0,0,  5,4,3,2,1, 10,8,6,4,2, 10,8,6,4,2 };
  mxtype y[] = { 10,8,6,4,2, 10,8,6,4,2,  5,4,3,2,1,  0,0,0,0,0 };

  printf("\n\n=== warped mesh ===\n");
  printmesh(5,4,x,y);
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
  mxtype x[] = { 0,0,0, 1,1,1, 2,1,2, 3,3,3 };
  mxtype y[] = { 2,1,0, 2,1,0, 2,1,0, 2,1,0 };

  printf("\n\n=== degenerate mesh (some edges have zero length) ===\n");
  printmesh(3,4,x,y);
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
  mxtype x[] = {-3,-3,3,3, -2,-2,2,2, -1,-1,1,1, 0,0,0,0   };
  mxtype y[] = {2,1,-1,-2, 2,1,-1,-2, 2,1,-1,-2, 2,1,-1,-2 };

  printf("\n\n=== twisted mesh (some edges have negative length) ===\n");
  printmesh(4,4,x,y);
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
  mxtype x[] = {-3,-3,0,3,3, -2,-2,0,2,2, -1,-1,0,1,1, 0,0,0,0,0   };
  mxtype y[] = {2,1,0,-1,-2, 2,1,0,-1,-2, 2,1,0,-1,-2, 2,1,0,-1,-2 };

  printf("\n\n=== twisted mesh (some edges have zero length) ===\n");
  printmesh(5,4,x,y);
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
  mxtype x[] = {0,0,0,0, 2,2,4,1, 8,6,2,1, 8,6,2,1};
  mxtype y[] = {8,6,4,3, 8,6,4,3, 4,4,2,2, 0,0,0,0};

  printf("\n\n=== non-concave quad in mesh ===\n");
  printmesh(4,4,x,y);
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

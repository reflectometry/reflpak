#include <assert.h>
#include <stdlib.h>
#include <math.h>
#include <stdio.h>
#ifdef TEST
# ifdef OSX
#  include <OpenGL/gl.h>
# else
#  include <GL/gl.h>
# endif
#else 
# include "togl.h"
#endif
#include <GL/glu.h>
#define DEMO
#include "plot.h"

#ifdef PLOT_AXES
#define PLOT_RBORDER 2.0
#define PLOT_LBORDER 0.5
#define PLOT_TBORDER 0.25
#define PLOT_BBORDER 0.5
#define PLOT_DPI 80.
#endif

#define PLOT_DOUBLE_BUFFER 1
#define PLOT_COLORMAP_ALPHA 1.0
#define PLOT_LOGRANGE 1e-7
/* XXX FIXME XXX may want better handling of negative numbers in
 * the colormap.  Currently anything less than 7 orders of magnitude
 * below the highest color is set to ground.
 */

/* ============================================= */
/* Color functions */

static void hsv2rgb(float h, float s, float v, float *r, float *g, float *b)
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

void plot_graymap(int n, PlotColor *map)
{
  int i;
  for (i=0; i < n; i++) {
    map[4*i]=map[4*i+1]=map[4*i+2]=(double)i/(double)(n-1);
    map[4*i+3]=PLOT_COLORMAP_ALPHA;
  }
}
void plot_huemap(int n, PlotColor *map)
{
  int i;
  for (i=0; i < n; i++) {
    hsv2rgb(i/(n*1.1),1.,1.,map+4*i,map+4*i+1,map+4*i+2);
    map[4*i+3]=PLOT_COLORMAP_ALPHA;
  }
}
void plot_valmap(int n, PlotColor *map, PlotColor hue)
{
  int i;
  for (i=0; i < n; i++) {
    hsv2rgb(hue,1.,1.-i/(n*1.2),map+4*i,map+4*i+1,map+4*i+2);
    map[4*i+3]=PLOT_COLORMAP_ALPHA;
  }
}


/* ============================================= */
/* OpenGL functions */

/* Functions in this block should not depend on memory allocations,
 * and should have minimal dependence on types and datastructures
 * defined outside.
 */

/* We are using a state-based model for coloring a surface: Set the colormap, 
 * then call plot_mesh.   
 * XXX FIXME XXX In fine GL tradition we should have a limited size stack we
 * can push and pop so that we can color a mesh without having to restore
 * colors.
 * XXX FIXME XXX I wonder if OpenGL is thread safe?  This certainly
 * won't be.
 */
typedef struct PLOT_COLORMAP {
  double lo, hi, step;
  PlotColor *sky, *ground, *colors;
  int n, log;
} PlotColormap;
static PlotColormap plot_colormap;

#define PLOT_COLORMAP_LEN 64

PlotColor plot_invisible[4] = {0.,0.,0.,0.};
PlotColor plot_shadow[4] = {0.,0.,0.,0.1};
PlotColor plot_black[4] = {0.,0.,0.,1.};
PlotColor plot_white[4] = {1.,1.,1.,1.};
static PlotColor grid_color[4] = {0.5,0.5,0.5,0.5};
static PlotColor plot_default_colors[4*PLOT_COLORMAP_LEN];

static void mapcalc(void)
{
  if (plot_colormap.log) {
    plot_colormap.step =plot_colormap.n/(log(plot_colormap.hi)-log(plot_colormap.lo));
  } else {
    plot_colormap.step = plot_colormap.n/(plot_colormap.hi-plot_colormap.lo);
  }
}

static void mapinit(void)
{
#if 1
  plot_huemap(PLOT_COLORMAP_LEN,plot_default_colors);
#else
  plot_graymap(PLOT_COLORMAP_LEN,plot_default_colors);
#endif
  plot_colormap.sky = plot_colormap.ground = plot_shadow;
  plot_colormap.log = 0;
  plot_colormap.colors = plot_default_colors;
  plot_colormap.lo = 0.;
  plot_colormap.hi = 1.;
  plot_colormap.n = PLOT_COLORMAP_LEN;
  mapcalc();
}

/* Return the color corresponding to value v in the current colormap */
static PlotColor *mapcolor(double v)
{
  PlotColor *c;
  int idx;
  if (isnan(v)) {
    c = plot_shadow;
  } else if (v < plot_colormap.lo) {
    c = plot_colormap.ground;
  } else if (v > plot_colormap.hi) {
    c = plot_colormap.sky;
  } else {
    if (plot_colormap.log) v = log(v);
    idx = floor(plot_colormap.step*(v-plot_colormap.lo));
    if (idx >= plot_colormap.n) idx = plot_colormap.n-1;
    c = plot_colormap.colors + 4*idx;
  }
  // printf("Painting %f as [%f,%f,%f]\n",z,c[0],c[1],c[2]);
  return c;
}

#if 0
static PlotSwapfn swapfn;
void plot_init(PlotSwapfn fn)
{
  swapfn = fn;
  mapinit();
}
#else
void plot_init(void)
{
  mapinit();
}
#endif


/* Set the range for the colormap, and whether it is log or linear */
void plot_vrange(int islog, double lo, double hi)
{
  plot_colormap.log = islog;
  if (islog && lo < hi*PLOT_LOGRANGE) lo = hi*PLOT_LOGRANGE;
  plot_colormap.lo = lo;
  plot_colormap.hi = hi;
  mapcalc();
}

/* Set the colors for the colormap */
void plot_colors(int n, PlotColor *colors)
{
  plot_colormap.colors = colors;
  plot_colormap.n = n;
  mapcalc();
}

#ifdef TEST
void drawquadrants(const double limits[], int pick)
{
  double xlo=limits[0],xhi=limits[1];
  double ylo=limits[2],yhi=limits[3];
  double xmid = (xhi+xlo)/2;
  double ymid = (yhi+ylo)/2;
  PlotColor c1[4], c2[4], c3[4], c4[4];
  
  hsv2rgb(0.,0.,0.2,c1+0,c1+1,c1+2);
  hsv2rgb(0.,0.,0.4,c2+0,c2+1,c2+2);
  hsv2rgb(0.,0.,0.6,c3+0,c3+1,c3+2);
  hsv2rgb(0.,0.,0.8,c4+0,c4+1,c4+2);
  c1[3]=c2[3]=c3[3]=c4[3] = 0.2;

  printf("drawquadrants\n");
  glPushName(111);
  glPushName(0);
  glBegin(GL_QUAD_STRIP);
  glVertex2f(xlo,ylo);
  glVertex2f(xlo,ymid);
  glVertex2f(xmid,ylo);
  glColor4fv(c1);
  glVertex2f(xmid,ymid);
  glVertex2f(xhi,ylo);
  glColor4fv(c2);
  glVertex2f(xhi,ymid);
  glEnd();
  //printf("strip error=%d\n",glGetError());
  
  glLoadName(3);
  glBegin(GL_QUAD_STRIP);
  glVertex2f(xlo,ymid);
  glVertex2f(xlo,yhi);
  glVertex2f(xmid,ymid);
  glColor4fv(c3);
  glVertex2f(xmid,yhi);
  glVertex2f(xhi,ymid);
  glColor4fv(c4);
  glVertex2f(xhi,yhi);
  glEnd();
  //printf("strip error=%d\n",glGetError());
  
  glPopName();
  glPopName();
  
}
#endif

/* Generate a mesh object in list k */
void plot_mesh(int k, int m, int n, 
	       const double x[], const double y[], const double v[])
{
  int i, j;

  /* XXX FIXME XXX what to do when out of lists? */
  if (k < 0) return;

  glNewList(k,GL_COMPILE);
  glPushName(k);
  glPushName(-1);
  for (i = 0; i < m-1; i++) {
    glLoadName(i);
    glBegin(GL_QUAD_STRIP);
    glVertex2f(x[0],y[0]);
    glVertex2f(x[n],y[n]);
    for (j = 1; j < n; j++) {
      glVertex2f(x[j],y[j]);
      glColor4fv(mapcolor(v[j]));
      glVertex2f(x[j+n],y[j+n]);
    }
    glEnd();
    x+=n; y+=n; v+= n;
  }
  glPopName();
  glPopName();
  glEndList();

#if 0
  /* Use this code for a pick list which returns a triple containing
     the array id and the row/column of the array. Assume that array
     ids are pairs of odd/even.  You will need to change plot_add so
     that glGenList will generate 2 lists and plot_pick so that it will
     use the 2nd list of the pair.

     For my test box, this code was not reliable, so I am only picking
     rows instead of individual quads.  The calling program will have
     to sort out which column was clicked.
  */
  x-=m*n; y-=m*n; v-=m*n;
  glNewList(k+1,GL_COMPILE);
  glPushName(k);
  glPushName(-1);
  for (i = 0; i < m-1; i++) {
    glLoadName(i);
    glPushName(-1);
    for (j = 1; j < n; j++) {
      glLoadName(j);
      glBegin(GL_QUADS);
      glColor4fv(mapcolor(v[j]));
      glVertex2f(x[j-1],y[j-1]);
      glVertex2f(x[j+n-1],y[j+n-1]);
      glVertex2f(x[j],y[j]);
      glVertex2f(x[j+n],y[j+n]);
      glEnd();
    }
    glPopName();
    x+=n; y+=n; v+= n;
  }
  glPopName();
  glPopName();
  glEndList();
#endif
}

static void 
linear_tics(const double limits[2], double tics[2], int steps)
{
  double range, d;

  assert(limits[0] < limits[1]);
  
  range = limits[1]-limits[0];
  d = pow(10.,ceil(log10(range/steps)));
  if (5.*range / d <= steps) {
    tics[0] = d/5.;
    tics[1] = 4.;
  } else if ( 2. * range / d <= steps ) {
    tics[0] = d/2.;
    tics[1] = 5.;
  } else {
    tics[0] = d;
    tics[1] = 5.;
  }
}
void 
plot_grid_tics(const double limits[], double tics[], int numx, int numy)
{
  linear_tics(limits,tics,numx);
  linear_tics(limits+2,tics+2,numy);
}

void plot_grid_object(int k, const double limits[], 
		      int Mx, int mx, int My, int my, const double v[])
{
  int i,start,stop;
  float sizes[2];

  glNewList(k,GL_COMPILE);

  glColor4fv(grid_color);

  /* Minor tics */
  glGetFloatv(GL_LINE_WIDTH_RANGE,sizes);
  glLineWidth(sizes[0]); /* Minimum width line allowed for minor tics */
  glLineStipple(1,0x5555); /* dotted lines for minor tics */

  glEnable(GL_LINE_STIPPLE);
  glBegin(GL_LINES);
  start = Mx; stop = Mx+mx;
  for (i = start; i < stop; i++) {
    glVertex3f(v[i],limits[2],0.);
    glVertex3f(v[i],limits[3],0.);
  }
  start = Mx+mx+My; stop = Mx+mx+My+my;
  for (i = start; i < stop; i++) {
    glVertex3f(limits[0],v[i],0.);
    glVertex3f(limits[1],v[i],0.);
  }
  glEnd();
  glDisable(GL_LINE_STIPPLE);
  /* Major tics */
  glLineWidth(1.); /* Standard width line for major tics */
  glBegin(GL_LINES);
  start = 0; stop = Mx;
  for (i = start; i < stop; i++) {
    glVertex3f(v[i],limits[2],0.);
    glVertex3f(v[i],limits[3],0.);
  }
  start = Mx+mx; stop = Mx+mx+My;
  for (i = start; i < stop; i++) {
    glVertex3f(limits[0],v[i],0.);
    glVertex3f(limits[1],v[i],0.);
  }    
  glEnd();

  glEndList();
}

void plot_grid(const double limits[], const double grid[])
{
  int i,start,stop;
  float sizes[2];

  glPushMatrix();
  glOrtho(limits[0],limits[1],limits[2],limits[3],-1.,1.);

  glColor4fv(grid_color);

  if (grid[1]>0. || grid[3]>0.) {
    /* Minor tics */
    glGetFloatv(GL_LINE_WIDTH_RANGE,sizes);
    glLineWidth(sizes[0]); /* Minimum width line allowed for minor tics */
    glLineStipple(1,0x5555); /* dotted lines for minor tics */

    glEnable(GL_LINE_STIPPLE);
    glBegin(GL_LINES);
    if (grid[1]>0.) {
      int sub = grid[1];
      double d = grid[0]/sub;
      start = ceil(limits[0]/d);
      stop = floor(limits[1]/d);
      for (i = start; i <= stop; i++) {
	if (i%sub != 0) {
	  glVertex3f(i*d,limits[2],0.);
	  glVertex3f(i*d,limits[3],0.);
	}
      }
    }
    if (grid[3]>0.) {
      int sub = grid[3];
      double d = grid[2]/sub;
      start = ceil(limits[2]/d);
      stop = floor(limits[3]/d);
      for (i = start; i <= stop; i++) {
	if (i%sub != 0) {
	  glVertex3f(limits[0],i*d,0.);
	  glVertex3f(limits[1],i*d,0.);
	}
      }
    }
    glEnd();
    glDisable(GL_LINE_STIPPLE);
  }


  /* Major tics */
  if (grid[0] > 0. || grid[2] > 0.) {
    glLineWidth(1.); /* Standard width line for major tics */
    glBegin(GL_LINES);
    if (grid[0] > 0.) {
      double d = grid[0];
      start = ceil(limits[0]/d);
      stop = floor(limits[1]/d);
      for (i = start; i <= stop; i++) {
	glVertex3f(i*d,limits[2],0.);
	glVertex3f(i*d,limits[3],0.);
      }
    }
    if (grid[2] > 0.) {
      double d = grid[2];
      start = ceil(limits[2]/d);
      stop = floor(limits[3]/d);
      for (i = start; i <= stop; i++) {
	glVertex3f(limits[0],i*d,0.);
	glVertex3f(limits[1],i*d,0.);
      }    
      glEnd();
    }
  }

  glPopMatrix();

}

void plot_display(const double limits[], const int stack[])
{
  int i;

  glShadeModel(GL_FLAT);
  glEnable (GL_BLEND);
  glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glClearColor (1.0, 1.0, 1.0, 0.0);
  glClear (GL_COLOR_BUFFER_BIT);
  glLoadIdentity ();

#if 1
#ifdef PLOT_AXES
  glEnable(GL_SCISSOR_TEST);
#endif
  glPushMatrix();
  glOrtho(limits[0],limits[1],limits[2],limits[3],-1.,1.);
  // printf("limits=(%f,%f,%f,%f)\n",limits[0],limits[1],limits[2],limits[3]);
  for (i=PLOT_STACKOVERHEAD; i < stack[1]; i++) {
    // printf("stack[%d]=%d\n",i,stack[i]);
    if (stack[i] > 0) glCallList(stack[i]);
  }
  glPopMatrix();
#ifdef PLOT_AXES
  glDisable(GL_SCISSOR_TEST);
#endif
#endif

#if 0
  glColor3f(1.0,1.0,0.0);
  glPointSize(5.0);
  glBegin(GL_POINTS);
  glVertex2f( 1., 1.);
  glVertex2f(-1., 1.);
  glVertex2f( 1.,-1.);
  glVertex2f(-1.,-1.);
  glVertex2f( 0., 0.);
  glColor3f(1.0,0.0,1.0);
  glVertex2f( 1.1, 1.1);
  glVertex2f(-1.1, 1.1);
  glVertex2f( 1.1,-1.1);
  glVertex2f(-1.1,-1.1);
  glEnd();
#endif
}

#if 0
void drawbox(int x1, int y1, int x2, int y2)
{
}

void rubberband (int x1, int y1, int x2, int y2)
{
  glEnable(GL_SCISSOR_TEST);
  glEnable(GL_COLOR_LOGIC_OP);
  glLogicOp(GL_XOR);
  drawbox(x1,y1,x2,y2);
  glutSwapBuffers();
  drawbox(x1,y1,x2,y2);
  glDisable(GL_COLOR_LOGIC_OP);
  glDisable(GL_SCISSOR_TEST);
}
#endif

void plot_reshape (int w, int h)
{
#ifdef PLOT_AXES
  /* Translate borders from inches to pixels */
  double R = PLOT_RBORDER*PLOT_DPI;
  double T = PLOT_TBORDER*PLOT_DPI;
  double B = PLOT_BBORDER*PLOT_DPI;
  double L = PLOT_LBORDER*PLOT_DPI;
#endif

  /* Size of viewport in pixels */
  glViewport (0, 0, (GLsizei) w, (GLsizei) h); 

  /* Construct projection matrix leaving room for fixed borders */
  glMatrixMode (GL_PROJECTION);
  glLoadIdentity ();
#ifdef PLOT_AXES
  // printf("hello\n");
  glScissor(L,B,w-(L+R),h-(T+B));
  glTranslated((L-R)/w, (B-T)/h, 0.);
  glScaled(1.-(R+L)/w, 1.-(T+B)/h, 1.);
  /* Note this could be expressed as glOrtho if needed */
#else
  // glFrustum(-1.,1.,-1.,1.,-1.,1.);
#endif

  /* Initialize the model matrix to the empty transform */
  glMatrixMode (GL_MODELVIEW);
  glLoadIdentity();
  // printf("reshape\n");
}

/* ============================================= */
/* Display stack functions */
/* stack[0] is size of stack */
/* stack[1] is the next stack position */
static int findk(const int stack[], int k)
{
  int i;
  for (i=PLOT_STACKOVERHEAD; i< stack[1]; i++) 
    if (stack[i]==k || stack[i] == -k) return i;
  return -1;
}

/* Initialize a new display stack */
void plot_clearstack(int stack[], int n)
{
  int i;

  for (i=1; i < n; i++) stack[i] = 0;
  stack[0] = n;
  stack[1] = 2;
}

void plot_copystack(const int from[], int to[], int n)
{
  int i;
  to[0] = n;
  if (n < from[0]) {
    for (i=1; i < n; i++) to[i] = from[i];
    if (to[1] >= n) to[1] =  n-1;
  }
  else {
    for (i=1; i < from[0]; i++) to[i] = from[i];
  }
}

/* Create/delete plot objects. 
 * Current implementation uses display lists, but a future implementation could
 * use something else so long as it had an integer index.
 */
int plot_add(int stack[])
{
  int k;
  /* Check for space on stack */
  if (stack[1]>=stack[0]) return -1;
  /* Create new display list */
  k = glGenLists(1);
  /* Add display list to top of stack */
  stack[stack[1]] = k;
  /* Adjust stack */
  stack[1]++;
  /* Return the number so we can fill it */
  return k;
}

int plot_delete(int stack[], int k)
{
  int i = findk(stack,k);
  if (i < 0) return -1;
  while (++i < stack[1]) stack[i-1] = stack[i];
  stack[1]--;
  /* Free space on server */
  glDeleteLists(k,1);
  return 0;
}


/* hide/show encoded in top bit as +/-k */
int plot_show(int stack[], int k)
{
  int i = findk(stack,k);
  if (i < 0) return -1;
  stack[i] = k;
  return 0;
}

int plot_hide(int stack[], int k)
{
  int i = findk(stack,k);
  if (i < 0) return -1;
  stack[i] = -k;
  return 0;
}

/* Move k to top/bottom of the stack, and show it. */
int plot_raise(int stack[], int k)
{
  int i = findk(stack,k);
  if (i < 0) return -1;
  while (++i < stack[1]) stack[i-1] = stack[i];
  stack[i-1] = k;
  return 0;
}

int plot_lower(int stack[], int k)
{
  int i = findk(stack,k);
  if (i < 0) return -1;
  while (--i >= PLOT_STACKOVERHEAD) stack[i+1] = stack[i];
  stack[i+1] = k;
  return 0;
}

#define SELECT_BUFFER_LENGTH 512
static void show_hits(GLint hits, GLuint select[])
{
  int i,k;
  if (hits <= 0) printf("hits=%d\n",hits);
  k = 0;
  for (i=0; i < hits; i ++) {
    int j,dims=select[k];
    printf(" depth=[%5g,%5g]",
	   (double)select[k+1]/4294967295.,
	   (double)select[k+2]/4294967295.);
    for (j=k+3; j<k+3+dims; j++) printf(" %5d",select[j]);
    k+=dims+3;
    printf("\n");
  }
}



/* XXX FIXME XXX this function reports a hit even if the thing it is
 * hitting is invisible.  My solution is to make out of bounds values
 * into shadows. */
void plot_pick(const double limits[], const int stack[], int x, int y)
{
  GLuint select[SELECT_BUFFER_LENGTH];
  GLint hits;
  GLint viewport[4];
  int i;

  /* Prepare for selection mode */
  glGetIntegerv(GL_VIEWPORT, viewport);
  glSelectBuffer(SELECT_BUFFER_LENGTH, select);
  glRenderMode(GL_SELECT);
  glInitNames();

  /* Specify selection point and draw pick stack. The drawing needs to be in 
   * the same matrix as the pick matrix otherwise I get reports of -1 hits.
   * Use the center of pixel rather than the boundary, and use a very narrow
   * box to look for intercepts.
   */
  glPushMatrix();
  gluPickMatrix((GLdouble)x+0.5, (GLdouble)(viewport[3]-y)-0.5, 
		1e-5, 1e-5, viewport);
  glOrtho(limits[0],limits[1],limits[2],limits[3],-1.,1.);
  //drawquadrants(limits,1);
  for (i=PLOT_STACKOVERHEAD; i < stack[1]; i++) {
    if (stack[i] > 0) glCallList(stack[i]);
  }
  glPopMatrix();

  glFlush();

  /* Render scene to find which quadrilaterals overlap the selection */
  hits = glRenderMode (GL_RENDER);

  // printf("g error=%d\n",glGetError());
  /* Report hits */
  show_hits(hits,select);

  /* Maybe need to redraw full scene? */
}

#if 0
/* ============================================= */
/* high-level plot functions */

/* Determine the data limits of the plotted objects
 */
static void defaultlimits(double limits[6])
{
  limits[0]=limits[2]=limits[4] = 0.;
  limits[1]=limits[3]=limits[5] = 1.;
}
static void copylimits(double to[6], const double from[6])
{
  int i;
  for (i=0; i < 6; i++) to[i] = from[i];
}
static void extendlimits(double to[6], const double from[6])
{
  int i;
  if (to[0] < from[0]) to[0] = from[0];
  if (to[1] > from[1]) to[1] = from[1];
  if (to[2] < from[2]) to[2] = from[2];
  if (to[3] > from[3]) to[3] = from[3];
  if (to[4] < from[4]) to[4] = from[4];
  if (to[5] > from[5]) to[5] = from[5];
}
void plot_limits(const PlotInfo *plot, double limits[6], int visible) 
{
  int i;

  if (visible) {
    /* Find first visible object */
    for (i=0; i < plot->num_objects && !plot->V[i].visible; i++) ;
    if (i == plot->num_objects) {
      defaultlimits(limits);
    } else {
      copylimits(limits,plot->V[i].limits);
      while (i < plot->num_objects) {
	if (plot->V[i].visible) extendlimits(limits,plot->V[i].limits);
      }
    }
  } else {
    if (polot->num_objects == 0) {
      defaultlimits(limits);
    } else {
      copylimits(limits,plot->V[0].limits);
      for (i=1; i < plot->num_objects; i++) {
        extendlimits(limits,
    }
  }
#if 0
  printf("limits are [%f,%f,%f,%f,%f,%f]\n",
	 limits[0],limits[1],limits[2],limits[3],limits[4],limits[5]);
#endif
}

/* meshadd
 * Add a new mesh to the display, keeping track of the data limits.
 */
static double vmin(int k, double x[])
{
  int i;
  double min;
  min = x[0];
  for (i=1; i < k; i++) if (min > x[i]) min = x[i];
  return min;
}
static double vmax(int k, double x[])
{
  int i;
  double max;
  max = x[0];
  for (i=1; i < k; i++) if (max < x[i]) max = x[i];
  return max;
}
static void drawmesh(PlotObject *V)
{
  PlotColor colors[4*PLOT_COLORMAP_LEN];

  plot_valmap(PLOT_COLORMAP_LEN, colors, V->color[0]);
  plot_colors(PLOT_COLORMAP_LEN, colors);
  plot_mesh(V->glid, m, n, x, y, v);
}
int plot_add_mesh(PlotInfo *plot, int m, int n, 
	double x[], double y[], double v[])
{
  PlotObject *V = plot->V+plot->num_objects;

  V->type = PLOT_MESH;
  V->glid = plot_add(plot->stack);
  V->visible = 1;
  V->limits[0] = vmin(m*n,x);
  V->limits[1] = vmax(m*n,x);
  V->limits[2] = vmin(m*n,y);
  V->limits[3] = vmax(m*n,y);
  V->limits[4] = vmin(m*n,v);
  V->limits[5] = vmax(m*n,v);
  V->data.mesh.m = m;
  V->data.mesh.n = n;
  V->data.mesh.x = x;
  V->data.mesh.y = y;
  V->data.mesh.v = v;
  drawmesh(plot->V[i]
}
#endif


/* ===================================================== */
/* Demo code */ 
#if defined(DEMO) || defined(TEST)

void drawsquares(int stack[])
{
  static double x[] = {0., 1., 2., 0., 1., 2., 0., 1., 2.};
  static double y[] = {0., 0., 0., 1., 1., 1., 2., 2., 2.};
  static double v[] = {.1, .2, .3, .4, .5, .6, .7, .8, .9};
  static PlotColor map[4*PLOT_COLORMAP_LEN];
  int k = plot_add(stack);

  plot_valmap(PLOT_COLORMAP_LEN,map,0.);
  plot_colors(PLOT_COLORMAP_LEN,map);
  plot_mesh(k,3,3,x,y,v);
}

void buildwarp(int m, int n, double *x, double *y, double *v)
{
  int i,j;
  double p = 0.;
  for (i=0; i < m; i++) {
    for (j=0; j < n; j++) {
      double angle = (i * M_PI)/(m-1);
      double distance = 1. + (9.*j)/(n-1);
      *x++ = sin(angle)*distance;
      *y++ = cos(angle)*distance;
      *v++ = p; p += 1./m/n;
    }
  }
}

#define WARP_M 140
#define WARP_N 51
#define Q (WARP_M*WARP_N)
void drawwarp(int stack[])
{
  static double Wx[Q], Wy[Q], Wv[Q];
  static PlotColor Wmap[4*PLOT_COLORMAP_LEN];
  static int iter=-1;
  int i,k;

  iter++;
  buildwarp(WARP_M,WARP_N,Wx,Wy,Wv);
  for (i=0; i < Q; i++) { Wx[i] += 3*iter; Wy[i] += 2*iter; }
  k = plot_add(stack);
  plot_valmap(PLOT_COLORMAP_LEN,Wmap,iter/10.);
  plot_colors(PLOT_COLORMAP_LEN,Wmap);
  plot_mesh(k,WARP_M,WARP_N,Wx,Wy,Wv);
}

void plot_demo(double limits[6], int stack[])
{
  // printf("entering plotdemo\n");
  limits[4] = 0.1;
  limits[5] = 0.9;
  plot_vrange(0,limits[4],limits[5]);
  drawsquares(stack);
  drawwarp(stack);
  drawwarp(stack);
  limits[0] = 0.;
  limits[1] = 15.;
  limits[2] = -3.;
  limits[3] = 12.;

#if 0
  double tics[100];
  int n,k,v,Mx,mx,My,my;

  n=0; 
  for (v = ceil(limits[0]); n < 100 && v < limits[1]; v++)
    if (v%5 == 0) tics[n++] = v;
  Mx = n;
  for (v = ceil(limits[0]); n < 100 && v < limits[1]; v++)
    if (v%5 != 0) tics[n++] = v;
  mx = n-Mx;
  for (v = ceil(limits[2]); n < 100 && v < limits[3]; v++)
    if (v%5 == 0) tics[n++] = v;
  My = n-(Mx+mx);
  for (v = ceil(limits[2]); n < 100 && v < limits[3]; v++)
    if (v%5 != 0) tics[n++] = v;
  my = n-(My+Mx+mx);
  k = plot_add(stack);
  plot_grid(k,limits,Mx,mx,My,my,tics);
#endif
}
#endif

#ifdef TEST
/* Compile with -DTEST and link with -lglut for standalone demo. */
/* NB: by the time you read this, the standalone demo probably won't work. */
#ifdef OSX
# include <GLUT/glut.h>
#else
# include <GL/glut.h>
#endif

int stack[20];
double limits[6];
double tics[4];

void init(void) 
{
  plot_init();
  plot_clearstack(stack,sizeof(stack)/sizeof(int));
  plot_demo(limits,stack);
}

void display(void)
{
  //printf("display 1: error=%d\n",glGetError());
  plot_display(limits,stack);
  //printf("display 2: error=%d\n",glGetError());
  plot_grid(limits,tics);
  //printf("display 3: error=%d\n",glGetError());

#if 0
  glPushMatrix();
  glOrtho(limits[0],limits[1],limits[2],limits[3],-1.,1.);
  drawquadrants(limits,0);
  glPopMatrix();
#endif
  //printf("display 4: error=%d\n",glGetError());

#if PLOT_DOUBLE_BUFFER
  glutSwapBuffers();
#else
  glFlush();
#endif
}

void reshape(int w, int h)
{
  int xtics, ytics;
  xtics = (2*w)/100; /* 100 dpi */
  ytics = (2*h)/100; /* 100 dpi */
  plot_grid_tics(limits,tics,xtics,ytics);
  plot_reshape(w,h);
}


void keyboard(unsigned char key, int x, int y)
{
   switch (key) {
      case 27:
         exit(0);
         break;
   }
}

void drag(int x, int y)
{
  // printf("drag to %d %d\n", x, y);
}

void move(int x, int y)
{
  // printf("mouse at %d %d\n", x, y);
  //plot_pick(limits,stack,x,y);
}

void click(int button, int state, int x, int y)
{
  // printf("mouse %d %d at %d %d\n",button,state,x,y);
  if (button == 3 && state == GLUT_DOWN) {
    /* zoom in */
  } else if (button == 4 && state == GLUT_DOWN) {
    /* zoom out */
  } else if (button == 1 && state == GLUT_DOWN) {
    /* pan */
  } else if (button == 0 && state == GLUT_DOWN) {
    /* pick */
    printf("picking at %d,%d\n",x,y);
    plot_pick(limits,stack,x,y);
  }
}

int main(int argc, char** argv)
{
   glutInit(&argc, argv);
#if PLOT_DOUBLE_BUFFER
   glutInitDisplayMode (GLUT_DOUBLE | GLUT_RGBA);
#else
   glutInitDisplayMode (GLUT_RGBA);
#endif
   glutInitWindowSize (500, 500); 
   glutInitWindowPosition (100, 100);
   glutCreateWindow (argv[0]);
   glutDisplayFunc(display); 
   glutReshapeFunc(reshape);
   glutKeyboardFunc(keyboard);
   glutMouseFunc(click);
   glutMotionFunc(drag);
   glutPassiveMotionFunc(move);
   init ();
   glutMainLoop();
   return 0;
}

#endif
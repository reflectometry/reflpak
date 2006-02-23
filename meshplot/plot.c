#include <assert.h>
#include <stdlib.h>
#include <math.h>
#include <stdio.h>
#ifdef TEST
# ifdef OSX
#  include <OpenGL/gl.h>
#  include <OpenGL/glu.h>
# else
#  include <GL/gl.h>
#  include <GL/glu.h>
# endif
#else 
# include "togl.h"
# if defined(TOGL_AGL) || defined(TOGL_AGL_CLASSIC)
#  include <OpenGL/glu.h>
# else
#  include <GL/glu.h>
# endif
#endif
#define DEMO
#include "plot.h"

/* XXX FIXME XXX hopefully this won't be too confusing, but until
 * we have figured out the consequences we would like to delay
 * deciding on the representation for things like colors.
 */
#ifdef USE_DOUBLE
#define glVertex2 glVertex2d
#define glVertex3 glVertex3d
#define glVertex4 glVertex4d
#define glColor4v glColor4dv
#define REAL_TYPE GL_DOUBLE
#else
#define glVertex2 glVertex2f
#define glVertex3 glVertex3f
#define glVertex4 glVertex4f
#define glColor4v glColor4fv
#define REAL_TYPE GL_FLOAT
#endif

static double DPI = 80.;


#ifdef PLOT_AXES
#define PLOT_RBORDER 2.0
#define PLOT_LBORDER 0.5
#define PLOT_TBORDER 0.25
#define PLOT_BBORDER 0.5
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

static void hsv2rgb(PReal h, PReal s, PReal v, PReal *r, PReal *g, PReal *b)
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

void plot_graymap(int n, PReal *map)
{
  int i;
  for (i=0; i < n; i++) {
    map[4*i]=map[4*i+1]=map[4*i+2]=(PReal)i/(PReal)(n-1);
    map[4*i+3]=PLOT_COLORMAP_ALPHA;
  }
}
void plot_huemap(int n, PReal *map)
{
  int i;
  for (i=0; i < n; i++) {
    hsv2rgb(i/(n*1.1),1.,1.,map+4*i,map+4*i+1,map+4*i+2);
    map[4*i+3]=PLOT_COLORMAP_ALPHA;
  }
}
void plot_valmap(int n, PReal *map, PReal hue)
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
  PReal lo, hi, step;
  const PReal *sky, *ground;
  PReal *colors;
  int n, log;
} PlotColormap;
static PlotColormap plot_colormap;

#define PLOT_COLORMAP_LEN 64

const PReal plot_invisible[4] = {0.,0.,0.,0.};
const PReal plot_shadow[4] = {0.,0.,0.,0.1};
const PReal plot_black[4] = {0.,0.,0.,1.};
const PReal plot_white[4] = {1.,1.,1.,1.};
static PReal outline_color[4] = {0.,0.,0.,0.5};
static PReal grid_color[4] = {0.5,0.5,0.5,0.5};
static PReal plot_default_colors[4*PLOT_COLORMAP_LEN];
/* Min/max width for smoothed lines; without smoothing, lines must have
 * integer widths corresponding directly to pixels. */
PReal plot_min_line_width = 1.;
PReal plot_max_line_width = 1.;

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
static const PReal *mapcolor(PReal v)
{
  const PReal *c;
  int idx;
  if (isnan(v)) {
    c = plot_shadow;
  } else if (v < plot_colormap.lo) {
    c = plot_colormap.ground;
  } else if (v > plot_colormap.hi) {
    c = plot_colormap.sky;
  } else {
    if (plot_colormap.log) {
      idx = floor(plot_colormap.step*(log(v/plot_colormap.lo)));
    } else {
      idx = floor(plot_colormap.step*(v-plot_colormap.lo));
    }
    if (idx >= plot_colormap.n) idx = plot_colormap.n-1;
    c = plot_colormap.colors + 4*idx;
  }
  // printf("Painting %f as [%f,%f,%f]\n",z,c[0],c[1],c[2]);
  return c;
}

/* Set the line drawing parameters: width, stipple and color.
   If stipple is 0, then use solid lines, otherwise stipple is
   stored as factor<<16 + pattern.
   If width is positive, use antialiasing to draw line widths between
   plot_min_line_width and plot_max_line_width.
   If width is negative, then don't use antialiasing; widths in that
   case correspond to pixels rather than points.
   If width is 0., then the caller should avoid drawing the line.
   Color is RGBA.

   FIXME consider using negative widths for non-antialiased and
   positive widths for antialiased, and a constant for minimum
*/
static void format_line(PReal width, int stipple, const PReal* color)
{
  const int pattern=stipple&0xFFFF, factor=(stipple>>16);
  if (stipple) {
    /* Note: stipple is given in pixels, but I want points.  A crude
       approximation can be achieved by scaling by the screen resolution */
    glEnable(GL_LINE_STIPPLE);
    glLineStipple((int)floor(factor*DPI/72.+0.5),pattern);
  } else {
    glDisable(GL_LINE_STIPPLE);
  }
  if (width > 0.) {
    /* Anti-aliased line: scale from points to pixels using DPI. */
    glEnable(GL_LINE_SMOOTH);
    glHint(GL_LINE_SMOOTH_HINT,GL_NICEST);
    glLineWidth(width*DPI/72.);
  } else {
    /* Aliased line: use pixels directly. */
    glDisable(GL_LINE_SMOOTH);
    glLineWidth(-width);
  }
  glColor4v(color);
}

#if 0
static PlotSwapfn swapfn;
void plot_init(PlotSwapfn fn)
{
  float sizes[2];

  swapfn = fn;
  mapinit();
  glGetFloatv(GL_LINE_WIDTH_RANGE,sizes);
  plot_min_line_width = sizes[0];
  plot_max_line_width = sizes[1];
}
#else
void plot_init(void)
{
  float sizes[2];

  mapinit();
  glGetFloatv(GL_LINE_WIDTH_RANGE,sizes);
  plot_min_line_width = sizes[0];
  plot_max_line_width = sizes[1];
}
#endif
void plot_set_dpi(double dpi) 
{ 
  DPI = dpi; 
}
double plot_dpi(void)
{
  return DPI;
}


/* Set the range for the colormap, and whether it is log or linear */
void plot_vrange(int islog, PReal lo, PReal hi)
{
  plot_colormap.log = islog;
  if (islog && lo < hi*PLOT_LOGRANGE) lo = hi*PLOT_LOGRANGE;
  plot_colormap.lo = lo;
  plot_colormap.hi = hi;
  mapcalc();
}

/* Set the colors for the colormap */
void plot_colors(int n, PReal *colors)
{
  plot_colormap.colors = colors;
  plot_colormap.n = n;
  mapcalc();
}

#ifdef TEST
void drawquadrants(const PReal limits[], int pick)
{
  PReal xlo=limits[0],xhi=limits[1];
  PReal ylo=limits[2],yhi=limits[3];
  PReal xmid = (xhi+xlo)/2;
  PReal ymid = (yhi+ylo)/2;
  PReal c1[4], c2[4], c3[4], c4[4];
  
  hsv2rgb(0.,0.,0.2,c1+0,c1+1,c1+2);
  hsv2rgb(0.,0.,0.4,c2+0,c2+1,c2+2);
  hsv2rgb(0.,0.,0.6,c3+0,c3+1,c3+2);
  hsv2rgb(0.,0.,0.8,c4+0,c4+1,c4+2);
  c1[3]=c2[3]=c3[3]=c4[3] = 0.2;

  printf("drawquadrants\n");
  glPushName(111);
  glPushName(0);
  glBegin(GL_QUAD_STRIP);
  glVertex2(xlo,ylo);
  glVertex2(xlo,ymid);
  glVertex2(xmid,ylo);
  glColor4v(c1);
  glVertex2(xmid,ymid);
  glVertex2(xhi,ylo);
  glColor4v(c2);
  glVertex2(xhi,ymid);
  glEnd();
  //printf("strip error=%d\n",glGetError());
  
  glLoadName(3);
  glBegin(GL_QUAD_STRIP);
  glVertex2(xlo,ymid);
  glVertex2(xlo,yhi);
  glVertex2(xmid,ymid);
  glColor4v(c3);
  glVertex2(xmid,yhi);
  glVertex2(xhi,ymid);
  glColor4v(c4);
  glVertex2(xhi,yhi);
  glEnd();
  //printf("strip error=%d\n",glGetError());
  
  glPopName();
  glPopName();
  
}
#endif

/* Generate a line object in list k */
void plot_lines(int k, int n, const PReal x[], 
		PReal width, int stipple, const PReal* color)
{
  const PReal z=0;
  int i;

  if (k < 0) return;
  glNewList(k,GL_COMPILE);
  glPushName(k);
  format_line(width,stipple,color);
  glPushName(0);
  for (i=0; i < n; i++) {
    double x1=x[4*i],   y1=x[4*i+1];
    double x2=x[4*i+2], y2=x[4*i+3];
    glLoadName(i);
    if (x1==x2) {
      glBegin(GL_LINE_STRIP);
      glVertex4(0.,-1.,z,0.);
      glVertex4(x1,0.,z,1.);
      glVertex4(0.,1.,z,0.);
      glEnd();
    } else {
      double slope = (double)(y1-y2)/(double)(x1-x2);
      double intercept = (double)y1 - (double)x1*slope;

      /* Draw two semi-infinite lines joined at x=0.
       * 
       * Note: line width should be small.  Thick lines are not supported
       * on all implementations, and those that do support them render them
       * poorly.  In particular, the joint between the lines becomes visible,
       * and the edges are not handled correctly.  Apparently the line is 
       * clipped before drawing and so it does not extend all the way to the
       * edge of the clipping region across the width of the line.  Perhaps
       * another clipping technique such as scissor regions or stencil buffers
       * will render it properly.
       */
      /* FIXME this technique only works for limits in the range
       * [-1e5,1e5]; the only workable solution may be to handle this like
       * grid, and set the line limits explicitly when needed according to
       * the available window. This will also solve the problem of keeping
       * the lines on top of the meshes. */
      glBegin(GL_LINE_STRIP);
      glVertex4(-1.,-slope,z,0.);
      glVertex4(0.,intercept,z,1.);
      glVertex4(1.,slope,z,0.);
      glEnd();
    }
  }
  glPopName();
  glPopName();
  glEndList();
}

/* Generate a curve object in list k */
void plot_curve(int k, int n, const PReal x[], const PReal y[],
		PReal width, int stipple, const PReal* color)
{
  int i;

  if (k < 0) return;
  glNewList(k,GL_COMPILE);
  format_line(width,stipple,color);
  glPushName(k);
  glBegin(GL_LINE_STRIP);
  for (i=0; i < n; i++) glVertex2(x[i],y[i]);
  glEnd();
  glPopName();
  glEndList();
}

/* Generate a mesh object in list k */
void plot_mesh(int k, int m, int n, 
	       const PReal x[], const PReal y[], const PReal v[])
{
  int i, j;

  /* XXX FIXME XXX what to do when out of lists? */
  if (k < 0) return;

  glNewList(k,GL_COMPILE);

  /* Draw quad strips with pick names k,i for each strip */
  /* Note: triangle fans perform just as well as quad strips for me. */
  /* Note: Tried using individual quads with names k,i,j for picking
     but this was unreliable on my box. */
  glPushName(k);
  glPushName(0);
  for (i = 0; i < m; i++) {
    glLoadName(i);
    glBegin(GL_QUAD_STRIP);
    glVertex2(x[0],y[0]);
    glVertex2(x[n+1],y[n+1]);
    for (j = 1; j <= n; j++) {
      glVertex2(x[j],y[j]);
      glColor4v(mapcolor(v[j-1]));
      glVertex2(x[j+n+1],y[j+n+1]);
    }
    glEnd();
    x+=n+1; y+=n+1; v+=n;
  }
  glPopName();
  glPopName();

#if 0
  /* Draw an outline around each quadrilateral. */
  /* FIXME check if OpenGL supports this directly with PolygonMode */
  if (outline_width != 0.) {
    format_line(outline_width,outline_stipple,outline_color);
    /* Vertical lines */
    for (i = 0; i <= m; i++) {
      glBegin(GL_LINE_STRIP);
      for (j = 0; j <= n; j++) glVertex2(x[i*(n+1)+j],y[i*(n+1)+j]);
      glEnd();
    }
    /* Horizontal lines */
    for (j = 0; j <= n; j++) {
      glBegin(GL_LINE_STRIP);
      for (i = 0; i <= m; i++) glVertex2(x[i*(n+1)+j],y[i*(n+1)+j]);
      glEnd();
    }
  }
#endif

  glEndList();
}

/* Draw an outline around the entire mesh. */
void plot_outline(int k, int m, int n, const PReal x[], const PReal y[],
		  PReal width, int stipple, const PReal* color)
{
  int i;

  if (k < 0) return;
  glNewList(k,GL_COMPILE);
  format_line(width,stipple,color);
  glPushName(k);
  /* Buggy driver note: With GL_LINE_SMOOTH enabled on my Linux box there
     are occasional pixels showing through the outline.  This does not
     happen on my Windows box.  These can be eliminated by disabling
     GL_LINE_SMOOTH, but then the outlines are not antialiased.  Drawing
     points at every vertex looks better on my Linux box, but it looks bad 
     on my Windows.  For now, ignore the issue.  If it is a problem on too 
     many platforms, uncomment the following:

           glDisable(GL_LINE_SMOOTH);

     Another solution is to use a stippled line so the gaps are unnoticed.
  */
  glBegin(GL_LINE_STRIP);
  i = 0;
  while (i < n) { glVertex2(x[i],y[i]); i++; }
  while (i < m*(n+1)) { glVertex2(x[i],y[i]); i+=n+1; }
  while (i > m*(n+1)) { glVertex2(x[i],y[i]); i--; }
  while (i >= 0) { glVertex2(x[i],y[i]); i-=n+1; }
  glEnd();
  glPopName();
  glEndList();
}

static void 
linear_tics(const PReal limits[2], PReal tics[2], int steps)
{
  PReal range, d;

  /* XXX FIXME XXX what to do with invalid limits? */
  if (limits[0] >= limits[1]) range = 1.;
  else range = limits[1]-limits[0];
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
plot_grid_tics(const PReal limits[], PReal tics[], int numx, int numy)
{
  linear_tics(limits,tics,numx);
  linear_tics(limits+2,tics+2,numy);
}

/* This draws the grid as just another overlay object. */
#if 0
/* this code is superceded by the direct drawing code in plot_grid. */
void plot_grid_object(int k, const PReal limits[], 
		      int Mx, int mx, int My, int my, const PReal v[])
{
  int i,start,stop;

  glNewList(k,GL_COMPILE);

  /* Minor tics, 1 pixel wide and dotted */
  format_line(-1.,0x15555,grid_color);
  glBegin(GL_LINES);
  start = Mx; stop = Mx+mx;
  for (i = start; i < stop; i++) {
    glVertex3(v[i],limits[2],0.);
    glVertex3(v[i],limits[3],0.);
  }
  start = Mx+mx+My; stop = Mx+mx+My+my;
  for (i = start; i < stop; i++) {
    glVertex3(limits[0],v[i],0.);
    glVertex3(limits[1],v[i],0.);
  }
  glEnd();
  glDisable(GL_LINE_STIPPLE);

  /* Major tics, 1 point wide and solid */
  format_line(1.,0,grid_color);
  glBegin(GL_LINES);
  start = 0; stop = Mx;
  for (i = start; i < stop; i++) {
    glVertex3(v[i],limits[2],0.);
    glVertex3(v[i],limits[3],0.);
  }
  start = Mx+mx; stop = Mx+mx+My;
  for (i = start; i < stop; i++) {
    glVertex3(limits[0],v[i],0.);
    glVertex3(limits[1],v[i],0.);
  }    
  glEnd();

  glEndList();
}
#endif

void plot_grid(const PReal limits[], const PReal grid[])
{
  int i,start,stop;

  glPushMatrix();
  glOrtho(limits[0],limits[1],limits[2],limits[3],-1.,1.);

  /* Minor tics: 1 pixel wide and dotted */
  if (grid[1]>0. || grid[3]>0.) {
    format_line(-1.,0x15555,grid_color);
    glBegin(GL_LINES);
    if (grid[1]>0.) {
      int sub = grid[1];
      PReal d = grid[0]/sub;
      start = ceil(limits[0]/d);
      stop = floor(limits[1]/d);
      for (i = start; i <= stop; i++) {
	if (i%sub != 0) {
	  glVertex3(i*d,limits[2],0.);
	  glVertex3(i*d,limits[3],0.);
	}
      }
    }
    if (grid[3]>0.) {
      int sub = grid[3];
      PReal d = grid[2]/sub;
      start = ceil(limits[2]/d);
      stop = floor(limits[3]/d);
      for (i = start; i <= stop; i++) {
	if (i%sub != 0) {
	  glVertex3(limits[0],i*d,0.);
	  glVertex3(limits[1],i*d,0.);
	}
      }
    }
    glEnd();
  }

  /* Major tics; 1pt wide and solid */
  if (grid[0] > 0. || grid[2] > 0.) {
    format_line(1.,0,grid_color);
    glBegin(GL_LINES);
    if (grid[0] > 0.) {
      PReal d = grid[0];
      start = ceil(limits[0]/d);
      stop = floor(limits[1]/d);
      for (i = start; i <= stop; i++) {
	glVertex3(i*d,limits[2],0.);
	glVertex3(i*d,limits[3],0.);
      }
    }
    if (grid[2] > 0.) {
      PReal d = grid[2];
      start = ceil(limits[2]/d);
      stop = floor(limits[3]/d);
      for (i = start; i <= stop; i++) {
	glVertex3(limits[0],i*d,0.);
	glVertex3(limits[1],i*d,0.);
      }    
    }
    glEnd();
  }

  glPopMatrix();

}

void plot_display(const PReal limits[], const int stack[])
{
  int i;
  void qsdrawlist(void);

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
  qsdrawlist(); /* XXX FIXME XXX vertex array experiment */
  glPopMatrix();
#ifdef PLOT_AXES
  glDisable(GL_SCISSOR_TEST);
#endif
#endif

#if 0
  glColor3(1.0,1.0,0.0);
  glPointSize(5.0);
  glBegin(GL_POINTS);
  glVertex2( 1., 1.);
  glVertex2(-1., 1.);
  glVertex2( 1.,-1.);
  glVertex2(-1.,-1.);
  glVertex2( 0., 0.);
  glColor3(1.0,0.0,1.0);
  glVertex2( 1.1, 1.1);
  glVertex2(-1.1, 1.1);
  glVertex2( 1.1,-1.1);
  glVertex2(-1.1,-1.1);
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
  double R = PLOT_RBORDER*DPI;
  double T = PLOT_TBORDER*DPI;
  double B = PLOT_BBORDER*DPI;
  double L = PLOT_LBORDER*DPI;
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
	   (PReal)select[k+1]/4294967295.,
	   (PReal)select[k+2]/4294967295.);
    for (j=k+3; j<k+3+dims; j++) printf(" %5d",select[j]);
    k+=dims+3;
    printf("\n");
  }
}



/* XXX FIXME XXX This function:
 *  - reports a hit even if the thing it is hitting is invisible.
 *  - reports a hit even if the thing it is hitting is covered.
 *  - is not sensitive to line width.
 *  - cannot report individual array elements.
 * Rather than using the GL_SELECT mechanism, we can rerender the
 * scene using a unique color for each item drawn, then from the
 * color of the pixel we can determine which item was under the mouse.
 */
int pick_debug = 0;
void plot_pick(const PReal limits[], const int stack[], int x, int y)
{
#if 0  
	
  /* libGLU requires libstdc++ which is presently having versioning 
   * problems on some machines.  Suppress it for now.
   */
  GLuint select[SELECT_BUFFER_LENGTH];
  GLint hits;
  GLint viewport[4];
  double size=5.;
  int i;

  /* Prepare for selection mode */
  if (!pick_debug) {
    glInitNames();
    glSelectBuffer(SELECT_BUFFER_LENGTH, select);
    glRenderMode(GL_SELECT);
  } else {
    glClear(GL_COLOR_BUFFER_BIT);
  }

  /* Specify selection point and draw pick stack. The drawing needs to be in 
   * the same matrix as the pick matrix otherwise I get reports of -1 hits.
   * Use the center of pixel rather than the boundary, and use a very narrow
   * box to look for intercepts.
   */
  glPushMatrix();
  glGetIntegerv(GL_VIEWPORT, viewport);
  if (0 && pick_debug) size *= 10;
  gluPickMatrix((GLdouble)x+0.5, (GLdouble)(viewport[3]-y)-0.5, 
		size, size, viewport);
  glOrtho(limits[0],limits[1],limits[2],limits[3],-1.,1.);
  //drawquadrants(limits,1);
  for (i=PLOT_STACKOVERHEAD; i < stack[1]; i++) {
    if (stack[i] > 0) glCallList(stack[i]);
  }
  glPopMatrix();

  /* Render scene to find which quadrilaterals overlap the selection */
  if (!pick_debug) {
    glFlush();
    hits = glRenderMode (GL_RENDER);
    show_hits(hits,select);
  }
#endif
}

#if 0
/* ============================================= */
/* high-level plot functions */

/* Determine the data limits of the plotted objects
 */
static void defaultlimits(PReal limits[6])
{
  limits[0]=limits[2]=limits[4] = 0.;
  limits[1]=limits[3]=limits[5] = 1.;
}
static void copylimits(PReal to[6], const PReal from[6])
{
  int i;
  for (i=0; i < 6; i++) to[i] = from[i];
}
static void extendlimits(PReal to[6], const PReal from[6])
{
  int i;
  if (to[0] < from[0]) to[0] = from[0];
  if (to[1] > from[1]) to[1] = from[1];
  if (to[2] < from[2]) to[2] = from[2];
  if (to[3] > from[3]) to[3] = from[3];
  if (to[4] < from[4]) to[4] = from[4];
  if (to[5] > from[5]) to[5] = from[5];
}
void plot_limits(const PlotInfo *plot, PReal limits[6], int visible) 
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
static PReal vmin(int k, PReal x[])
{
  int i;
  PReal min;
  min = x[0];
  for (i=1; i < k; i++) if (min > x[i]) min = x[i];
  return min;
}
static PReal vmax(int k, PReal x[])
{
  int i;
  PReal max;
  max = x[0];
  for (i=1; i < k; i++) if (max < x[i]) max = x[i];
  return max;
}
static void drawmesh(PlotObject *V)
{
  PReal colors[4*PLOT_COLORMAP_LEN];

  plot_valmap(PLOT_COLORMAP_LEN, colors, V->color[0]);
  plot_colors(PLOT_COLORMAP_LEN, colors);
  plot_mesh(V->glid, m, n, x, y, v);
}
int plot_add_mesh(PlotInfo *plot, int m, int n, 
	PReal x[], PReal y[], PReal v[])
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


/* Support for mesh via vertex arrays.  This is now dead code since
 * vertex arrays don't save memory or make things faster.
 */ 

/* We start with measurements v at the centers of the pixels on
 * an m x n grid.  The corners of the pixels form an (m+1) x (n+1)
 * grid with the measurements still in the centers.
 *
 * To render this (m+1) x (n+1) mesh of x,y points it is converted
 * to a vertex array containing quad strips. Each strip has 2(n+1) 
 * vertices and there are m strips for a total of 2m(n+1) vertices.
 * To draw strip k use:
 *     glDrawArrays(GL_QUAD_STRIP,2*k*(n+1),2*(n+1))
 *
 * meshvertices(int m, int n)
 * mesh2vertex fills the array of vertex positions.  Each vertex
 * has 2 components so the total array size is:
 *     2*sizeof(PReal)*2*m*(n+1)
 *
 * mesh2color fills the array of colors.  Because we are using
 * flat colors, only the second
 */
#define QSVERTICES (2*m*(n+1))
int qsbytes(int m, int n) { return 6*sizeof(PReal)*QSVERTICES; }
PReal *qsnew(int m, int n) { return (PReal *)malloc(qsbytes(m,n)); }
void qsdelete(PReal *qs) { free(qs); }
void qscoords(int m, int n, const PReal *x, const PReal *y, PReal *qs)
{
  int i,j;
  
  if (qs == NULL) return;
  for (i=1; i <= m; i++) {
    for (j=0; j <= n; j++) {
      qs[0] = x[j];
      qs[1] = y[j];
      qs[2] = x[j+n];
      qs[3] = y[j+n];
      qs += 4;
    }
    x += n;
    y += n;
  }
}
void qscolor(int m, int n, const PReal *v, PReal *qs)
{
  PReal *c = qs + 2*QSVERTICES;
  int i, j;

  if (qs == NULL) return;
  for (i=0; i < 4*QSVERTICES; i++) c[i] = 0.5;
  for (i=0; i < m; i++) {
    /* Color of the first two vertices is ignored for GL_FLAT */
    c += 8;
    for (j=0; j < n; j++) {
      const PReal *color = mapcolor(v[j]);
      /* Only fill color for 1-origin index v[2*i+2] for GL_FLAT 
       * in GL_QUAD_STRIP */
      c[4] = color[0];
      c[5] = color[1];
      c[6] = color[2];
      c[7] = color[3];
      c += 8;
    }
    v += n;
  }
}
void qsdraw(int m, int n, const PReal *qs)
{
  int i;

  if (qs == NULL) return;
  glVertexPointer(2,REAL_TYPE,0,qs);
  glColorPointer(4,REAL_TYPE,0,qs+2*QSVERTICES);
  glEnableClientState (GL_VERTEX_ARRAY);
  glEnableClientState (GL_COLOR_ARRAY);
  glPushName(0);
  for (i = 0; i < m; i++) {
    glLoadName(i);
    glDrawArrays(GL_QUAD_STRIP, 2*i*(n+1), 2*(n+1));
  }
  glPopName();
  glDisableClientState (GL_VERTEX_ARRAY);
  glDisableClientState (GL_COLOR_ARRAY);
}
int qsnext=0;
struct QSLIST {
  int m, n;
  const PReal *qs;
} qslist[10];

void qsadd(int m, int n, const PReal *qs)
{
  qslist[qsnext].m = m;
  qslist[qsnext].n = n;
  qslist[qsnext].qs = qs;
  qsnext++;
}
void qsdrawlist(void)
{
  int i;
  for (i=0; i < qsnext; i++) qsdraw(qslist[i].m, qslist[i].n, qslist[i].qs);
}
void plot_qs(int k, int m, int n, const PReal *qs)
{

  /* XXX FIXME XXX what to do when out of lists? */
  if (k < 0 || qs == NULL) return;

  glNewList(k,GL_COMPILE);
  glPushName(k);
  qsdraw(m,n,qs);
  glPopName();
  glEndList();

}




/* ===================================================== */
/* Demo code */ 
#if defined(DEMO) || defined(TEST)

void drawsquares(int stack[])
{
  static PReal x[] = {0., 1., 2., 0., 1., 2., 0., 1., 2.};
  static PReal y[] = {0., 0., 0., 1., 1., 1., 2., 2., 2.};
  static PReal v[] = {.1, .2, .3, .4};
  static PReal map[4*PLOT_COLORMAP_LEN];
  int k = plot_add(stack);

  plot_valmap(PLOT_COLORMAP_LEN,map,0.);
  plot_colors(PLOT_COLORMAP_LEN,map);
  plot_mesh(k,2,2,x,y,v);
}

void buildwarp(int m, int n, PReal *x, PReal *y, PReal *v)
{
  int i,j;
  PReal p = 0.;
  for (i=0; i <= m; i++) {
    PReal angle = (i * M_PI)/m;
    for (j=0; j <= n; j++) {
      PReal distance = 1. + (9.*j)/n;
      *x++ = sin(angle)*distance;
      *y++ = cos(angle)*distance;
    }
  }
  for (i=0; i < m*n; i++) {
    *v++ = p; 
    p += (1./m)/n;
  }
}

void drawwarp(int stack[],int m, int n)
{
  static PReal Wmap[4*PLOT_COLORMAP_LEN];
  static int iter=-1;
  PReal *Wx, *Wy, *Wv;
#if 0 /* Use vertex arrays */
  PReal *qs;
#endif
  int numQ = m*n;
  int numQmesh = (m+1)*(n+1);
  int i,k;

  Wx = (PReal *)malloc(numQmesh * sizeof(PReal));
  if (Wx == NULL) return;
  Wy = (PReal *)malloc(numQmesh * sizeof(PReal));
  if (Wy == NULL) { free(Wx); return; }
  Wv = (PReal *)malloc(numQ * sizeof(PReal));
  if (Wv == NULL) { free(Wx); free(Wy); return; }

  iter++;
  buildwarp(m,n,Wx,Wy,Wv);
  for (i=0; i < numQmesh; i++) { Wx[i] += 3.1*iter; Wy[i] += 2*iter; }
  k = plot_add(stack);
  plot_valmap(PLOT_COLORMAP_LEN,Wmap,iter/10.);
  plot_colors(PLOT_COLORMAP_LEN,Wmap);

#if 0  /* Use vertex arrays */
  qs = qsnew(m,n);
  qscoords(m,n,Wx,Wy,qs);
  qscolor(m,n,Wv,qs);
# if 0 /* Use vertex arrays with display lists */
  plot_qs(k,m,n,qs);
  qsdelete(qs);
# else /* Use vertex arrays without display lists */
  qsadd(m,n,qs);
# endif
#else  /* Don't use vertex arrays */
  plot_mesh(k,m,n,Wx,Wy,Wv);
  k = plot_add(stack);
  plot_outline(k,m,n,Wx,Wy,-1.,0x27777,outline_color);
#endif
  free(Wx); free(Wy); free(Wv);
}

void drawcurve(int stack[], int n)
{
  static PReal color[4] = {0.0,0.8,0.0,1.};
  PReal *x, *y;
  int i,k;

  x = (PReal *)malloc(2*n*sizeof(*x));
  if (x == NULL) { return; }
  y = x+n;

  for (i=0; i < n; i++) {
    x[i] = 20.*(PReal)i/(PReal)n - 5.;
    y[i] = 10.*sin(x[i]);
  }
  k = plot_add(stack);
  plot_curve(k,n,x,y,0.5,0,color);
  free(x);
}

void drawline(int stack[])
{
  static PReal x[8]={1.,5.,10.,8.,2.,0.,2.,2.};
  int k;

  k=plot_add(stack);
  plot_lines(k,2,x,3.,0,plot_black);
}

void plot_demo(PReal limits[6], int stack[], int m, int n)
{
  // printf("entering plotdemo\n");
  limits[4] = 0.1;
  limits[5] = 0.9;
  plot_vrange(0,limits[4],limits[5]);
  drawsquares(stack);
  drawwarp(stack,m,n);
  drawwarp(stack,m,n);
  drawcurve(stack,n);
  drawline(stack);
  limits[0] = 0.;
  limits[1] = 15.;
  limits[2] = -3.;
  limits[3] = 12.;

#if 0
  PReal tics[100];
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
PReal limits[6];
PReal tics[4];
int force_redraw = 0;
int panning=0;
int pan_x, pan_y;
int pan_call=0;
int demo_m=86, demo_n=56;

void init(void) 
{
  plot_init();
  plot_clearstack(stack,sizeof(stack)/sizeof(int));
  plot_demo(limits,stack,demo_m,demo_n);
}

void display(void)
{
  force_redraw = 0;
  //printf("display 1: error=%d\n",glGetError());
  plot_display(limits,stack);
  //printf("display 2: error=%d\n",glGetError());
  plot_grid(limits,tics);
  //printf("display 3: error=%d\n",glGetError());

#if 0
  glPushMatrix();
  glOrtho((GLdouble)limits[0],(GLdouble)limits[1],
	  (GLdouble)limits[2],(GLdouble)limits[3],
	  (GLdouble)-1.,(GLdouble)1.);
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

void regrid(int w, int h)
{
  int xtics, ytics;
  xtics = (2*w)/100; /* 100 dpi */
  ytics = (2*h)/100; /* 100 dpi */
  plot_grid_tics(limits,tics,xtics,ytics);
}

void reshape(int w, int h)
{
  regrid(w,h);
  plot_reshape(w,h);
}


void keyboard(unsigned char key, int x, int y)
{
  /* printf("Shift state = %d\n",glutGetModifiers()); */
  if (force_redraw) display();
   switch (key) {
      case 27:
         exit(0);
         break;
   }
}

void show_pan(int call)
{
  if (pan_call == call) display();
}

void zoom(int x, int y, int step)
{
  int dims[4];
  double dx,dy,xbalance,ybalance;
  glGetIntegerv(GL_VIEWPORT, dims);

  xbalance = (double)x/(double)dims[2];
  ybalance = (double)(dims[3]-y)/(double)dims[3];
  if (step > 0) {
    dx = (limits[1]-limits[0])*step/100.;
    dy = (limits[3]-limits[2])*step/100.;
  } else {
    dx = (limits[1]-limits[0])*step/(100.-step);
    dy = (limits[3]-limits[2])*step/(100.-step);
  }

  limits[0] -= dx*xbalance;
  limits[1] += dx*(1-xbalance);
  limits[2] -= dy*ybalance;
  limits[3] += dy*(1-ybalance);

  regrid(dims[2],dims[3]);

  glutTimerFunc(25,show_pan,++pan_call);
}

void drag(int x, int y)
{
  // printf("drag to %d %d\n", x, y);
  if (panning) {
    int dims[4];
    double dx,dy;
    glGetIntegerv(GL_VIEWPORT, dims);
    dx = (pan_x-x)*(limits[1]-limits[0])/dims[2];
    dy = -(pan_y-y)*(limits[3]-limits[2])/dims[3];
    limits[0] += dx; limits[1] += dx;
    limits[2] += dy; limits[3] += dy;
    pan_x = x; pan_y = y;
    glutTimerFunc(25,show_pan,++pan_call);
  }
  else if (force_redraw) display();
}

void move(int x, int y)
{
  if (force_redraw) display();
  // printf("mouse at %d %d\n", x, y);
  //plot_pick(limits,stack,x,y,0);
}

void click(int button, int state, int x, int y)
{
  // printf("mouse %d %d at %d %d\n",button,state,x,y);
  panning = 0;
  if (button == 3 && state == GLUT_DOWN) {
    /* zoom in */
    zoom(x,y,5);
  } else if (button == 4 && state == GLUT_DOWN) {
    /* zoom out */
    zoom(x,y,-5);
  } else if (button == 1) {
    /* printf("button 1\n"); */
  } else if (button == 2 && state == GLUT_DOWN) {
    /* pan */
    /* printf("Shift state = %d\n",glutGetModifiers()); */
    panning = 1;
    pan_x = x;
    pan_y = y;
  } else if (button == 0 && state == GLUT_DOWN) {
    /* pick */
    printf("picking at %d,%d\n",x,y);
    plot_pick(limits,stack,x,y);
    pick_debug = 1;
    plot_pick(limits,stack,x,y);
    pick_debug = 0;
    force_redraw = 1;
#if PLOT_DOUBLE_BUFFER
    glutSwapBuffers();
#else
    glFlush();
#endif
  }
}

int unscheduled_exit = 0;
void idle(void)
{
  if (unscheduled_exit) exit(1);
}

int main(int argc, char** argv)
{
  if (argc > 1) demo_m = demo_n = atoi(argv[1]);
  if (argc > 2) demo_n = atoi(argv[2]);
  if (demo_m <= 0 || demo_n <= 0) {
    fprintf(stderr,"%s: expected dimensions m n\n",argv[0]);
    return 1;
  }

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
   /* glutIdleFunc(idle); */
   unscheduled_exit = 1;
   glutMainLoop();
   return 0;
}

#endif

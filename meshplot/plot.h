#ifndef _PLOT_H
#define _PLOT_H

#ifndef PRECISION
#define PRECISION float
#endif

#define PReal PRECISION

extern const PReal 
plot_black[4], plot_white[4], plot_shadow[4], plot_invisible[4];

/* void hsv2rgb(PReal h, PReal s, PReal v, PReal *r, PReal *g, PReal *b); */
void plot_graymap(int n, PReal *colors);
void plot_huemap(int n, PReal *colors);
void plot_valmap(int n, PReal *colors, PReal hue);

// typedef void (*PlotSwapfn)(void);
// void plot_init(PlotSwapfn fn);
void plot_init(void);
void plot_set_dpi(double dpi); /* default is 80 dots per inch */
double plot_dpi(void);
void plot_colors(int n, PReal *colors);
void plot_vrange(int islog, PReal lo, PReal hi);
void plot_mesh(int k, int m, int n, 
	       const PReal x[], const PReal y[], const PReal v[]);
void plot_lines(int k, int n, const PReal v[], PReal width, int stipple,
		const PReal color[]);
void plot_display(const PReal limits[], const int stack[]);
void plot_reshape (int w, int h);
void plot_grid_tics(const PReal limits[], PReal tics[], int numx, int numy);
void plot_grid(const PReal limits[], const PReal tics[]);

void plot_clearstack(int stack[], int n);
int plot_add(int stack[]);
int plot_delete(int stack[], int k);
int plot_hide(int stack[], int k);
int plot_show(int stack[], int k);
int plot_raise(int stack[], int k);
int plot_lower(int stack[], int k);
void plot_pick(const PReal limits[], const int stack[], int x, int y);

#define PLOT_STACKOVERHEAD 2
#if 0
#define PLOT_OBJECTS 64
typedef enum { PLOT_MESH } PlotType;
typedef struct PLOTMESH {
  int m, n;
  PReal *x, *y, *v;
} PlotMesh;
typedef struct PLOTOBJECT {
  PlotType type;
  int glid, visible;
  PReal limits[6];
  PReal color[4];
  union {
    PlotMesh mesh;
  } data;
} PlotObject;
typedef struct PLOTINFO {
  PReal limits[6];
  int stack[PLOT_OBJECTS+PLOT_STACKOVERHEAD];
  int num_objects;
  PlotObject V[PLOT_OBJECTS];
} PlotInfo;

void plot_limits(const PlotInfo *plot, PReal limits[6], int visible);
void meshinit(void);
void meshlimits(void);
void meshsetlimits(PReal xmin, PReal xmax, PReal ymin, PReal ymax);
int meshadd(int m, int n, PReal x[], PReal y[], PReal v[]);
int meshremove(int k);
int meshraise(int k);
int meshlower(int k);
void meshredraw(void);
#endif /* 0 */

#ifdef DEMO
void plot_demo(PReal limits[6], int stack[]);
#endif

#endif /* _PLOT_H */


typedef float PlotColor;

// void hsv2rgb(float h, float s, float v, float *r, float *g, float *b);
void plot_graymap(int n, float *colors);
void plot_huemap(int n, float *colors);
void plot_valmap(int n, float *colors, float hue);

// typedef void (*PlotSwapfn)(void);
// void plot_init(PlotSwapfn fn);
void plot_init(void);
void plot_colors(int n, PlotColor *colors);
void plot_mesh(int k, int m, int n, 
	       const double x[], const double y[], const double v[]);
void plot_display(const double limits[], const int stack[]);
void plot_reshape (int w, int h);
void plot_grid_tics(const double limits[], double tics[], int numx, int numy);
void plot_grid(const double limits[], const double tics[]);

void plot_clearstack(int stack[], int n);
int plot_add(int stack[]);
int plot_delete(int stack[], int k);
int plot_hide(int stack[], int k);
int plot_show(int stack[], int k);
int plot_raise(int stack[], int k);
int plot_lower(int stack[], int k);
void plot_pick(const double limits[], const int stack[], int x, int y);

#define PLOT_STACKOVERHEAD 2
#if 0
#define PLOT_OBJECTS 64
typedef enum { PLOT_MESH } PlotType;
typedef struct PLOTMESH {
  int m, n;
  double *x, *y, *v;
} PlotMesh;
typedef struct PLOTOBJECT {
  PlotType type;
  int glid, visible;
  double limits[6];
  float color[4];
  union {
    PlotMesh mesh;
  } data;
} PlotObject;
typedef struct PLOTINFO {
  double limits[6];
  int stack[PLOT_OBJECTS+PLOT_STACKOVERHEAD];
  int num_objects;
  PlotObject V[PLOT_OBJECTS];
} PlotInfo;

void plot_limits(const PlotInfo *plot, double limits[6], int visible);
void meshinit(void);
void meshlimits(void);
void meshsetlimits(double xmin, double xmax, double ymin, double ymax);
int meshadd(int m, int n, double x[], double y[], double v[]);
int meshremove(int k);
int meshraise(int k);
int meshlower(int k);
void meshredraw(void);
#endif /* 0 */

#ifdef DEMO
void plot_demo(double limits[6], int stack[]);
#endif
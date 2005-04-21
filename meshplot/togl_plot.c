#include <stdlib.h>
#include <string.h>
#include <tcl.h>
#include <tk.h>
#include "togl.h"
#define DEMO
#include "plot.h"

static double dpi;

#define STACK_SIZE 100
#define COLORMAP_LENGTH 64
typedef struct PLOTINFO {
  double limits[6];
  int stack[STACK_SIZE];
  double tics[4];
  int xtics, ytics;
  int grid;
  float colors[4*COLORMAP_LENGTH];
} PlotInfo;

/* New scene */
void tp_create( struct Togl *togl )
{
  Tcl_Interp *interp = Togl_Interp(togl);
  PlotInfo *plot = (PlotInfo*)malloc(sizeof(PlotInfo));
  // printf("creating plot=%p\n",plot);
  Togl_SetClientData(togl,(ClientData)plot);
  if (plot == NULL) {
    Tcl_SetResult (interp, "\"Cannot allocate client data for widget\"",
	TCL_STATIC );
    return;
  }
  plot_clearstack(plot->stack, STACK_SIZE);
  plot->limits[0] = plot->limits[2] = plot->limits[4] = 0.;
  plot->limits[1] = plot->limits[3] = plot->limits[5] = 1.;
  plot->grid = 0;
  plot_grid_tics(plot->limits,plot->tics,5,5);
  //  plot_demo(plot->limits, plot->stack);
}


/* Resize scene */
void tp_reshape( struct Togl *togl )
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  int w = Togl_Width( togl );
  int h = Togl_Height( togl );
  // printf("reshape to %d,%d\n",w,h);
  plot->xtics = (2*w)/dpi;
  plot->ytics = (2*h)/dpi;
  if (plot->xtics < 1) plot->xtics = 1;
  if (plot->ytics < 1) plot->ytics = 1;
  plot_grid_tics(plot->limits,plot->tics,plot->xtics,plot->ytics);
  plot_reshape(w,h);
}

/* Redraw scene */
void tp_display( struct Togl *togl )
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  // printf("display with plot=%p\n",plot);
  plot_display(plot->limits,plot->stack);
  if (plot->grid) plot_grid(plot->limits,plot->tics);
  Togl_SwapBuffers( togl );
}

/* Destroy scene */
void tp_destroy( struct Togl *togl )
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  // printf("display with plot=%p\n",plot);
  free(plot);
}

int tp_demo(struct Togl *togl, int argc, char *argv[])
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  // printf("demo with plot=%p\n",plot);
  Togl_MakeCurrent(togl);
  plot_demo(plot->limits, plot->stack);
  Togl_PostRedisplay(togl);
  return TCL_OK;
}

int tp_grid(struct Togl *togl, int argc, char *argv[] )
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  Tcl_Interp *interp = Togl_Interp(togl);

  if (argc != 3) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"pathName grid on|off\"",
		   TCL_STATIC );
    return TCL_ERROR;
  }
  plot->grid = (strcmp(argv[2],"on")==0);

  return TCL_OK;
}

int tp_valmap(struct Togl *togl, int argc, char *argv[])
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  Tcl_Interp *interp = Togl_Interp(togl);
  double hue;
  if (argc != 3) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"pathName valmap hue\"",
		   TCL_STATIC );
    return TCL_ERROR;
  }

  if (Tcl_GetDouble(interp,argv[2],&hue) != TCL_OK) {
    return TCL_ERROR;
  }

  plot_valmap(COLORMAP_LENGTH,plot->colors,hue);
  plot_colors(COLORMAP_LENGTH,plot->colors);
  return TCL_OK;
}

/* Remove an object from the plot */
int tp_delete(struct Togl *togl, int argc, char *argv[])
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  Tcl_Interp *interp = Togl_Interp(togl);
  int obj;
  if (argc != 3) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"pathName delete object\"",
		   TCL_STATIC );
    return TCL_ERROR;
  }

  if (Tcl_GetInt(interp,argv[2],&obj) != TCL_OK) {
    return TCL_ERROR;
  }

  if (plot_delete(plot->stack,obj) < 0) {
    Tcl_SetResult( interp, "invalid object", TCL_STATIC );
    return TCL_ERROR;
  }

  return TCL_OK;
}


/* Raise an object from the plot */
int tp_raise(struct Togl *togl, int argc, char *argv[])
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  Tcl_Interp *interp = Togl_Interp(togl);
  int obj;
  if (argc != 3) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"pathName raise object\"",
		   TCL_STATIC );
    return TCL_ERROR;
  }

  if (Tcl_GetInt(interp,argv[2],&obj) != TCL_OK) {
    return TCL_ERROR;
  }

  if (plot_raise(plot->stack,obj) < 0) {
    Tcl_SetResult( interp, "invalid object", TCL_STATIC );
    return TCL_ERROR;
  }

  return TCL_OK;
}


/* Lower an object from the plot */
int tp_lower(struct Togl *togl, int argc, char *argv[])
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  Tcl_Interp *interp = Togl_Interp(togl);
  int obj;
  if (argc != 3) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"pathName lower object\"",
		   TCL_STATIC );
    return TCL_ERROR;
  }

  if (Tcl_GetInt(interp,argv[2],&obj) != TCL_OK) {
    return TCL_ERROR;
  }

  if (plot_lower(plot->stack,obj) < 0) {
    Tcl_SetResult( interp, "invalid object", TCL_STATIC );
    return TCL_ERROR;
  }

  return TCL_OK;
}


/* Hide an object on the plot */
int tp_hide(struct Togl *togl, int argc, char *argv[])
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  Tcl_Interp *interp = Togl_Interp(togl);
  int obj;
  if (argc != 3) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"pathName hide object\"",
		   TCL_STATIC );
    return TCL_ERROR;
  }

  if (Tcl_GetInt(interp,argv[2],&obj) != TCL_OK) {
    return TCL_ERROR;
  }

  if (plot_hide(plot->stack,obj) < 0) {
    Tcl_SetResult( interp, "invalid object", TCL_STATIC );
    return TCL_ERROR;
  }

  return TCL_OK;
}


/* Show an object on the plot */
int tp_show(struct Togl *togl, int argc, char *argv[])
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  Tcl_Interp *interp = Togl_Interp(togl);
  int obj;
  if (argc != 3) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"pathName show object\"",
		   TCL_STATIC );
    return TCL_ERROR;
  }

  if (Tcl_GetInt(interp,argv[2],&obj) != TCL_OK) {
    return TCL_ERROR;
  }

  if (plot_show(plot->stack,obj) < 0) {
    Tcl_SetResult( interp, "invalid object", TCL_STATIC );
    return TCL_ERROR;
  }

  return TCL_OK;
}

/* Add a mesh object to the plot */
static double *
getvalue(Tcl_Interp *interp,const char *name,const char *dim,int size)
{
  unsigned char *data;
  int bytes;
  Tcl_Obj *obj = Tcl_GetVar2Ex(interp,name,NULL,0);
  if (obj == NULL) {
    Tcl_AppendResult( interp,
		      "expected variable name for data ",dim,
		      NULL);
    return NULL;
  }
  data = Tcl_GetByteArrayFromObj(obj,&bytes);
  if (data == NULL) {
    Tcl_AppendResult( interp,
		      "expected binary format d* for data ",name,
		      NULL);
    return NULL;
  } else if (bytes != size*sizeof(double)) {
    Tcl_AppendResult( interp,
		      "incorrect size for array ",name,
		      NULL);
    return NULL;
  }

  return (double *)data;
}

int tp_mesh(struct Togl *togl, int argc, char *argv[])
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  Tcl_Interp *interp = Togl_Interp(togl);
  int m,n;
  double *x,*y,*v;

  if (argc != 7) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"pathName mesh m n x y v\"",
		   TCL_STATIC);
    return TCL_ERROR;
  }
  if (Tcl_GetInt(interp,argv[2],&m) != TCL_OK 
      || Tcl_GetInt(interp,argv[3],&n) != TCL_OK) {
    return TCL_ERROR;
  }

  
  x = getvalue(interp,argv[4],"x",m*n);
  if (x == NULL) return TCL_ERROR;
  y = getvalue(interp,argv[5],"y",m*n);
  if (y == NULL) return TCL_ERROR;
  v = getvalue(interp,argv[6],"v",m*n);
  if (v == NULL) return TCL_ERROR;

  Togl_MakeCurrent(togl);
  plot_mesh(plot_add(plot->stack),m,n,x,y,v);

  return TCL_OK;
}

/* List all objects on the plot */
int tp_list(struct Togl *togl, int argc, char *argv[])
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  Tcl_Interp *interp = Togl_Interp(togl);
  int i;
  if (argc != 2) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"pathName list\"", 
		   TCL_STATIC);
  }

  /* XXX FIXME XXX hide details of stack implementation */
  for (i=2; i < plot->stack[1]; i++) {
    char number[20];
    sprintf(number,"%d",plot->stack[i]<0?-plot->stack[i]:plot->stack[i]);
    Tcl_AppendResult(interp,number,i<plot->stack[1]-1?" ":"",NULL);
  }

  return TCL_OK;
}


int tp_limits(struct Togl *togl, int argc, char *argv[])
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  Tcl_Interp *interp = Togl_Interp(togl);
  double xmin, xmax, ymin, ymax;

  // printf("limits with plot=%p\n",plot);
  if (argc != 6) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"pathName limits xmin xmax ymin ymax\"",
		   TCL_STATIC );
    return TCL_ERROR;
  }

  if (Tcl_GetDouble(interp,argv[2],&xmin) != TCL_OK
      || Tcl_GetDouble(interp,argv[3],&xmax) != TCL_OK
      || Tcl_GetDouble(interp,argv[4],&ymin) != TCL_OK
      || Tcl_GetDouble(interp,argv[5],&ymax) != TCL_OK) {
    return TCL_ERROR;
  }

  plot->limits[0] = xmin;
  plot->limits[1] = xmax;
  plot->limits[2] = ymin;
  plot->limits[3] = ymax;

  plot_grid_tics(plot->limits,plot->tics,plot->xtics,plot->ytics);
  return TCL_OK;
}


int tp_pick(struct Togl *togl, int argc, char *argv[])
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  Tcl_Interp *interp = Togl_Interp(togl);
  int x, y;

  // printf("limits with plot=%p\n",plot);
  if (argc != 4) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"pathName pick x y\"",
		   TCL_STATIC );
    return TCL_ERROR;
  }

  if (Tcl_GetInt(interp,argv[2],&x) != TCL_OK
      || Tcl_GetInt(interp,argv[3],&y) != TCL_OK) {
    return TCL_ERROR;
  }

  Togl_MakeCurrent(togl);
  plot_pick(plot->limits,plot->stack,x,y);

  return TCL_OK;
}

int tp_draw(struct Togl *togl, int argc, char *argv[] )
{
  Togl_PostRedisplay(togl);
  return TCL_OK;
}

/*
 * Called by Tk_Main() to let me initialize the modules (Togl) I will need.
 */
TOGL_EXTERN int Plot_Init( Tcl_Interp *interp )
{
#ifdef USE_TCL_STUBS
  if (Tcl_InitStubs(interp, "8.1", 0) == NULL) {return TCL_ERROR;}
#endif
#ifdef USE_TK_STUBS
  if (Tk_InitStubs(interp, "8.1", 0) == NULL) {return TCL_ERROR;}
#endif

  if (Togl_Init(interp) == TCL_ERROR) {
    return TCL_ERROR;
  }
   
#ifdef macintosh
  Togl_MacSetupMainInterp(interp);
#endif

  dpi = 100.;
  if (Tcl_Eval(interp,"expr {72.*[tk scaling]}") == TCL_OK) {
    double r;
    if (Tcl_GetDouble(interp,interp->result,&r) == TCL_OK) {
      dpi = r;
    }
    Tcl_ResetResult(interp);
  }
  // printf("dpi=%g\n",dpi);


  plot_init();

  /* Standard Togl operations */
  Togl_CreateFunc (tp_create);
  Togl_DestroyFunc (tp_destroy);
  Togl_DisplayFunc (tp_display);
  Togl_ReshapeFunc (tp_reshape);


  /* plot commands */
  Togl_CreateCommand( "limits", tp_limits );
  Togl_CreateCommand( "demo", tp_demo );
  Togl_CreateCommand( "grid", tp_grid );
  Togl_CreateCommand( "draw", tp_draw );
  Togl_CreateCommand( "valmap", tp_valmap );
  Togl_CreateCommand( "delete", tp_delete );
  Togl_CreateCommand( "mesh", tp_mesh );
  Togl_CreateCommand( "raise", tp_raise );
  Togl_CreateCommand( "lower", tp_lower );
  Togl_CreateCommand( "hide", tp_hide );
  Togl_CreateCommand( "show", tp_show );
  Togl_CreateCommand( "list", tp_list );
  Togl_CreateCommand( "pick", tp_pick );

  return TCL_OK;
}

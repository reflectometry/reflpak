#include <stdlib.h>
#include <string.h>
#include <tcl.h>
#include <tk.h>
#include "togl.h"
#define DEMO
#include "plot.h"


/* library functions which may go to a separate file */

static PReal *
get_vector_internal(Tcl_Interp *interp,
		    const char *name, const char *context, const char *role,
		    int size, int unshared)
{
  unsigned char *data;
  int bytes;

  /* Find the data object associated with the name */
  Tcl_Obj *obj = Tcl_GetVar2Ex(interp,name,NULL,0);
  if (obj == NULL) {
    Tcl_ResetResult(interp);
    Tcl_AppendResult( interp, context, ": ",
		      "expected variable name for ",role,
		      NULL);
    return NULL;
  }

  /* Get a private copy of the data if we need to modify it */
  if (Tcl_IsShared(obj) && unshared) {
    obj = Tcl_DuplicateObj(obj);
    Tcl_SetVar2Ex(interp,name,NULL,obj,0);
  }

  /* Make sure the object is a byte array */
  data = Tcl_GetByteArrayFromObj(obj,&bytes);
  if (data == NULL) {
    Tcl_ResetResult(interp);
    Tcl_AppendResult( interp, context, ": ",
		      "expected binary format array in ",
		      name,NULL);
    return NULL;
  }

  /* Check that the size is correct */
  if (bytes != size*sizeof(PReal)) {
    if (sizeof(PReal) == 4 && bytes == 8*size) {
      Tcl_ResetResult(interp);
      Tcl_AppendResult( interp, context, ": ",
			"wrong number of elements in ",name,
			"; try [binary format f* $data]",
			NULL);
    } else if (sizeof(PReal) == 8 && bytes == 4*size) {
      Tcl_ResetResult(interp);
      Tcl_AppendResult( interp, context, ": ",
			"wrong number of elements in ",name,
			"; try [binary format d* $data]",
			NULL);
    } else if ( (bytes%sizeof(PReal)) == 0) {
      Tcl_ResetResult(interp);
      Tcl_AppendResult( interp, context, ": ",
			"wrong number of elements in ",name,
			NULL);
    } else {
      Tcl_ResetResult(interp);
      Tcl_AppendResult( interp, context, ": ",
			"expected binary format in ",name,
			NULL);
    }
    return NULL;
  }

  /* Good: return a handle to the data */
  return (PReal *)data;
}


/* Return a pointer to a dense array of data.
 *
 * The data must be stored in a named variable, possibly constructed
 * with a binary format command, or perhaps obtained from some other
 * function.  The role of that variable in the command is reported
 * as part of the error message.  The size of the array expected
 * must be given explicitly so that the actual size can be checked.
 *
 * There are three different flavours:
 *
 * get_tcl_vector
 *   The returned data pointer will not be modified.
 *
 * get_unshared_tcl_vector 
 *   The returned data pointer may be modified, and the modifications
 *   will show up in the variable in the interpreter.
 *
 *   This routine creats a copy of the data if another variable
 *   references it.  For efficiency, be careful in the Tcl code to
 *   always pass by name rather than by value to keep the reference
 *   count to 1.
 *
 * get_private_tcl_vector
 *   The returned data pointer may be modified, but the modifications
 *   will not show up in the variable in the interpreter.  This routine 
 *   creates a private copy of the data which must be freed with 
 *   Tcl_Free, presumably on a later call to the C extension.
 */
const PReal *
get_tcl_vector(Tcl_Interp *interp, const char *name,
	       const char *context, const char *role,int size)
{
  return get_vector_internal(interp,name,context,role,size,0);
}
PReal *
get_unshared_tcl_vector(Tcl_Interp *interp, const char *name, 
			const char *context, const char *role, int size)
{
  return get_vector_internal(interp,name,context,role,size,1);
}
PReal *
get_private_tcl_vector(Tcl_Interp *interp, const char *name,
		       const char *context, const char *role, int size)
{
  PReal *data = get_vector_internal(interp,name,context,role,size,0);
  if (data) {
    PReal *copy = (PReal *)Tcl_Alloc(size*sizeof(PReal));
    memcpy(copy,data,size*sizeof(PReal));
    return copy;
  } else {
    return NULL;
  }
}

/* end lib */

#define STACK_SIZE 100
#define COLORMAP_LENGTH 64
typedef struct PLOTINFO {
  PReal limits[6];
  int stack[STACK_SIZE];
  PReal tics[4];
  int xtics, ytics;
  int grid, log;
  PReal colors[4*COLORMAP_LENGTH];
} PlotInfo;
PReal black[4] = { 0., 0., 0., 1.};

/* New scene */
void tp_create( Togl *togl )
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
  plot->log = 0;
  plot->grid = 0;
  plot_grid_tics(plot->limits,plot->tics,5,5);
  //  plot_demo(plot->limits, plot->stack);
}


/* Resize scene */
void tp_reshape( Togl *togl )
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  int w = Togl_Width( togl );
  int h = Togl_Height( togl );
  // printf("reshape to %d,%d\n",w,h);
  plot->xtics = (2*w)/plot_dpi();
  plot->ytics = (2*h)/plot_dpi();
  if (plot->xtics < 1) plot->xtics = 1;
  if (plot->ytics < 1) plot->ytics = 1;
  plot_grid_tics(plot->limits,plot->tics,plot->xtics,plot->ytics);
  plot_reshape(w,h);
}

/* Redraw scene */
void tp_display( Togl *togl )
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  // printf("display with plot=%p\n",plot);
  plot_display(plot->limits,plot->stack);
  if (plot->grid) plot_grid(plot->limits,plot->tics);
  Togl_SwapBuffers( togl );
}

/* Destroy scene */
void tp_destroy( Togl *togl )
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  // printf("display with plot=%p\n",plot);
  free(plot);
}

int tp_demo(Togl *togl, int argc, CONST84 char *argv[])
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  // printf("demo with plot=%p\n",plot);
  Togl_MakeCurrent(togl);
  plot_demo(plot->limits, plot->stack);
  Togl_PostRedisplay(togl);
  return TCL_OK;
}

int tp_grid(Togl *togl, int argc, CONST84 char *argv[] )
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

int tp_logdata(Togl *togl, int argc, CONST84 char *argv[] )
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  Tcl_Interp *interp = Togl_Interp(togl);

  if (argc != 3) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"pathName logdata on|off\"",
		   TCL_STATIC );
    return TCL_ERROR;
  }
  plot->log = (strcmp(argv[2],"on")==0);

  plot_vrange(plot->log,plot->limits[4],plot->limits[5]);
  return TCL_OK;
}

int tp_valmap(Togl *togl, int argc, CONST84 char *argv[])
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

int tp_colormap(Togl *togl, int argc, CONST84 char *argv[])
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  Tcl_Interp *interp = Togl_Interp(togl);
  const PReal *colors;

  if (argc != 3) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"pathName colormap map\"",
		   TCL_STATIC );
    return TCL_ERROR;
  }

  colors = get_tcl_vector(interp,argv[2],"colormap","map",4*COLORMAP_LENGTH);
  if (colors == NULL) return TCL_ERROR;

  memcpy(plot->colors,colors,4*COLORMAP_LENGTH*sizeof(PReal));
  plot_colors(COLORMAP_LENGTH,plot->colors);
  return TCL_OK;
}

/* Remove an object from the plot */
int tp_delete(Togl *togl, int argc, CONST84 char *argv[])
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
int tp_raise(Togl *togl, int argc, CONST84 char *argv[])
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
int tp_lower(Togl *togl, int argc, CONST84 char *argv[])
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
int tp_hide(Togl *togl, int argc, CONST84 char *argv[])
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
int tp_show(Togl *togl, int argc, CONST84 char *argv[])
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

/* Add a line object to the plot; use segment to add a line segment */
int tp_line(Togl *togl, int argc, CONST84 char *argv[])
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  Tcl_Interp *interp = Togl_Interp(togl);
  int id;
  double x1,y1,x2,y2,width;
  PReal x[4];
  

  if (argc != 7) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"pathName line x1 y1 x2 y2 width\"",
		   TCL_STATIC);
    return TCL_ERROR;
  }
  if (Tcl_GetDouble(interp,argv[2],&x1) != TCL_OK
      || Tcl_GetDouble(interp,argv[3],&y1) != TCL_OK
      || Tcl_GetDouble(interp,argv[4],&x2) != TCL_OK
      || Tcl_GetDouble(interp,argv[5],&y2) != TCL_OK
      || Tcl_GetDouble(interp,argv[6],&width) != TCL_OK) {
    return TCL_ERROR;
  }
  x[0]=x1; x[1]=y1; x[2]=x2; x[3]=y2;
  
  Togl_MakeCurrent(togl);
  id=plot_add(plot->stack);
  plot_lines(id,1,x,width,0,black);
  Tcl_SetObjResult (interp, Tcl_NewIntObj(id));

  return TCL_OK;
}

/* Add a mesh object to the plot */

int tp_mesh(Togl *togl, int argc, CONST84 char *argv[])
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  Tcl_Interp *interp = Togl_Interp(togl);
  int m,n,id;
  const PReal *x,*y,*v;

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

  
  x = get_tcl_vector(interp,argv[4],"mesh","x",(m+1)*(n+1));
  if (x == NULL) return TCL_ERROR;
  y = get_tcl_vector(interp,argv[5],"mesh","y",(m+1)*(n+1));
  if (y == NULL) return TCL_ERROR;
  v = get_tcl_vector(interp,argv[6],"mesh","v",m*n);
  if (v == NULL) return TCL_ERROR;

  Togl_MakeCurrent(togl);
  id=plot_add(plot->stack);
  plot_mesh(id,m,n,x,y,v);
  Tcl_SetObjResult (interp, Tcl_NewIntObj(id));

  return TCL_OK;
}

/* List all objects on the plot */
int tp_list(Togl *togl, int argc, CONST84 char *argv[])
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
  Tcl_ResetResult(interp);
  for (i=2; i < plot->stack[1]; i++) {
    char number[20];
    sprintf(number,"%d",plot->stack[i]<0?-plot->stack[i]:plot->stack[i]);
    Tcl_AppendResult(interp,number,i<plot->stack[1]-1?" ":"",NULL);
  }

  return TCL_OK;
}


int tp_vrange(Togl *togl, int argc, CONST84 char *argv[])
{
  PlotInfo *plot = (PlotInfo *)Togl_GetClientData(togl);
  Tcl_Interp *interp = Togl_Interp(togl);
  double vmin, vmax;

  // printf("vlimits with plot=%p\n",plot);
  if (argc != 4) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"pathName vrange min max\"",
		   TCL_STATIC );
    return TCL_ERROR;
  }

  if (Tcl_GetDouble(interp,argv[2],&vmin) != TCL_OK
      || Tcl_GetDouble(interp,argv[3],&vmax) != TCL_OK) {
    return TCL_ERROR;
  }

  plot->limits[4] = (PReal)vmin;
  plot->limits[5] = (PReal)vmax;

  plot_vrange(plot->log,plot->limits[4],plot->limits[5]);
  return TCL_OK;
}

int tp_limits(Togl *togl, int argc, CONST84 char *argv[])
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

  plot->limits[0] = (PReal)xmin;
  plot->limits[1] = (PReal)xmax;
  plot->limits[2] = (PReal)ymin;
  plot->limits[3] = (PReal)ymax;

  plot_grid_tics(plot->limits,plot->tics,plot->xtics,plot->ytics);
  return TCL_OK;
}


int tp_pick(Togl *togl, int argc, CONST84 char *argv[])
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

int tp_draw(Togl *togl, int argc, CONST84 char *argv[] )
{
  Togl_PostRedisplay(togl);
  return TCL_OK;
}

#include "refl.c"
#include "fvector.c"


/*
 * Called by Tk_Main() to let me initialize the modules (Togl) I will need.
 */
TOGL_EXTERN int Plot_Init( Tcl_Interp *interp )
{
  double dpi;

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


  plot_init();

  /* Ask Tk for the screen resolution */
  dpi = 100.;
  if (Tcl_Eval(interp,"expr {72.*[tk scaling]}") == TCL_OK) {
    double r;
    if (Tcl_GetDouble(interp,interp->result,&r) == TCL_OK) {
      dpi = r;
    }
    Tcl_ResetResult(interp);
  }
  /* printf("DPI=%g\n",dpi); */
  plot_set_dpi(dpi);


  /* Standard Togl operations */
  Togl_CreateFunc (tp_create);
  Togl_DestroyFunc (tp_destroy);
  Togl_DisplayFunc (tp_display);
  Togl_ReshapeFunc (tp_reshape);


  /* plot commands */
  Togl_CreateCommand( "limits", tp_limits );
  Togl_CreateCommand( "vrange", tp_vrange );
  Togl_CreateCommand( "demo", tp_demo );
  Togl_CreateCommand( "grid", tp_grid );
  Togl_CreateCommand( "logdata", tp_logdata );
  Togl_CreateCommand( "draw", tp_draw );
  Togl_CreateCommand( "valmap", tp_valmap );
  Togl_CreateCommand( "colormap", tp_colormap );
  Togl_CreateCommand( "delete", tp_delete );
  Togl_CreateCommand( "mesh", tp_mesh );
  Togl_CreateCommand( "line", tp_line );
  Togl_CreateCommand( "raise", tp_raise );
  Togl_CreateCommand( "lower", tp_lower );
  Togl_CreateCommand( "hide", tp_hide );
  Togl_CreateCommand( "show", tp_show );
  Togl_CreateCommand( "list", tp_list );
  Togl_CreateCommand( "pick", tp_pick );

  fvector_init(interp);
  refl_init(interp);

  return TCL_OK;
}

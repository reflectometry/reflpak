#include <tcl.h>
#include "mx.h"

/* Some basic matrix operations which don't belong in a generic
 * plotting tool, but which I don't want to create a separate DLL
 * just to handle them because I'm not going to create a complete
 * package.
 */

/* ================================================================ */

static int
fdivide(ClientData junk, Tcl_Interp *interp, 
	 int argc, Tcl_Obj *CONST argv[])
{
  int m,n;
  const mxtype *y;
  mxtype *M;
  const char *name;

  /* Interpret args */
  if (argc != 5) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"fdivide m n M y\"",
		   TCL_STATIC);
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp,argv[1],&m) != TCL_OK 
      || Tcl_GetIntFromObj(interp,argv[2],&n) != TCL_OK) {
    return TCL_ERROR;
  }

  /* Get data vector */
  name = Tcl_GetString(argv[3]);
  M = get_unshared_tcl_vector(interp,name,"fdivide","M",m*n);
  if (M == NULL) return TCL_ERROR;

  name = Tcl_GetString(argv[4]);
  y = get_tcl_vector(interp,name,"fdivide","y",m);
  if (y == NULL) return TCL_ERROR;

  /* Extract data */
  mx_divide_columns(m,n,M,y);

  return TCL_OK;
}

static int
fextract(ClientData junk, Tcl_Interp *interp, 
	 int argc, Tcl_Obj *CONST argv[])
{
  int m,n,column,width=1;
  const mxtype *x;
  mxtype *y;
  Tcl_Obj *yobj;
  const char *name;

  /* Interpret args */
  if (argc != 5 && argc != 6) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"fextract m n x column ?width\"",
		   TCL_STATIC);
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp,argv[1],&m) != TCL_OK 
      || Tcl_GetIntFromObj(interp,argv[2],&n) != TCL_OK
      || Tcl_GetIntFromObj(interp,argv[4],&column) != TCL_OK
      || (argc==6 && Tcl_GetIntFromObj(interp,argv[5],&width) != TCL_OK)) {
    return TCL_ERROR;
  }

  if (column+width > n || column < 0 || width < 1) {
    Tcl_SetResult( interp,
		   "fextract: requesting columns outside matrix",
		   TCL_STATIC);
    return TCL_ERROR;
  }


  /* Get data vector */
  name = Tcl_GetString(argv[3]);
  x = get_tcl_vector(interp,name,"fextract","x",m*n);
  if (x == NULL) return TCL_ERROR;

  /* Build return vector */
  yobj = Tcl_NewByteArrayObj(NULL,0);
  if (!yobj) return TCL_ERROR;
  Tcl_SetObjResult(interp,yobj);
  y = (mxtype *)Tcl_SetByteArrayLength(yobj,m*width*sizeof(mxtype));
  if (!y) return TCL_ERROR;

  /* Extract data */
  mx_extract_columns(m,n,x,column,width,y);

  return TCL_OK;
}

/* wrap in-place transpose function */
static int 
ftranspose(ClientData junk, Tcl_Interp *interp, 
	   int argc, Tcl_Obj *CONST argv[])
{
  int m,n;
  mxtype *x;
  const char *name;

  /* Interpret args */
  if (argc != 4) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"ftranspose m n x\"",
		   TCL_STATIC);
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp,argv[1],&m) != TCL_OK 
      || Tcl_GetIntFromObj(interp,argv[2],&n) != TCL_OK) {
    return TCL_ERROR;
  }

  /* Get data vector */
  name = Tcl_GetString(argv[3]);
  x = get_unshared_tcl_vector(interp,name,"ftranspose","x",m*n);
  if (x == NULL) return TCL_ERROR;

  /* Perform in-place transpose */
  mx_transpose(m,n,x,x);

  return TCL_OK;
}

/* Grab a 1-D slice through a 2-D structured grid */
static int 
fslice(ClientData junk, Tcl_Interp *interp, 
	   int argc, Tcl_Obj *CONST argv[])
{
  int m,n;
  mxtype *x;
  const char *name;

  /* Interpret args */
  if (argc != 4) {
    Tcl_SetResult( interp,
		   "wrong # args: should be \"ftranspose m n x\"",
		   TCL_STATIC);
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp,argv[1],&m) != TCL_OK 
      || Tcl_GetIntFromObj(interp,argv[2],&n) != TCL_OK) {
    return TCL_ERROR;
  }

  /* Get data vector */
  name = Tcl_GetString(argv[3]);
  x = get_unshared_tcl_vector(interp,name,"ftranspose","x",m*n);
  if (x == NULL) return TCL_ERROR;

  /* Perform in-place transpose */
  mx_transpose(m,n,x,x);

  return TCL_OK;
}

static int 
fprecision(ClientData junk, Tcl_Interp *interp, 
	   int argc, Tcl_Obj *CONST argv[])
{
  Tcl_SetObjResult(interp,Tcl_NewIntObj(sizeof(mxtype)));
  return TCL_OK;
}

void mx_init(Tcl_Interp *interp)
{
  Tcl_CreateObjCommand( interp, "ftranspose", ftranspose, NULL, NULL );
  Tcl_CreateObjCommand( interp, "fextract", fextract, NULL, NULL );
  Tcl_CreateObjCommand( interp, "fdivide", fdivide, NULL, NULL );
  Tcl_CreateObjCommand( interp, "fprecision", fprecision, NULL, NULL );
  Tcl_CreateObjCommand( interp, "fslice", fslice, NULL, NULL );
}

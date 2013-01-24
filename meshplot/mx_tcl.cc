#include <stdlib.h>
#include <string.h>
#include <tcl.h>
#include "mx.h"
#include "rebin.h"
#include "rebin2D.h"
#include "tclvector.h"

/* Some basic matrix operations which don't belong in a generic
 * plotting tool, but which I don't want to create a separate DLL
 * just to handle them because I'm not going to create a complete
 * package.
 */

/* ================================================================ */

static void
set_error(Tcl_Interp *interp, const char*s)
{
  Tcl_SetObjResult(interp, Tcl_NewStringObj(s,-1));
}

static int
fdivide(ClientData junk, Tcl_Interp *interp, 
	 int argc, Tcl_Obj *CONST argv[])
{
  int m,n,action,size;
  mxtype *M;
  const char *name, *action_string;

  /* Interpret args */
  if (argc != 6) {
    set_error ( interp,
		   "wrong # args: should be \"fdivide [rows|columns|elements|scalar] m n M y\"");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp,argv[2],&m) != TCL_OK 
      || Tcl_GetIntFromObj(interp,argv[3],&n) != TCL_OK) {
    return TCL_ERROR;
  }

  
  action_string = Tcl_GetString(argv[1]);
  if (strcmp(action_string,"rows") == 0) {
    action = 1;
    size = n;
  } else if (strcmp(action_string,"columns") == 0) {
    action = 2;
    size = m;
  } else if (strcmp(action_string,"elements") == 0) {
    action = 3;
    size = m*n;
  } else if (strcmp(action_string,"scalar") == 0) {
    action = 0;
    size = 1;
  } else {
    set_error ( interp,
		   "fdivide action: should be rows,columns,elements or scalar"
		   );
    return TCL_ERROR;
  }

  /* Get data vector */
  name = Tcl_GetString(argv[4]);
  M = get_unshared_tcl_vector(interp,name,"fdivide","M",m*n);
  if (M == NULL) return TCL_ERROR;

  /* Process data */
  if (action > 0) {
    const mxtype *y;

    /* Interpret vector */
    name = Tcl_GetString(argv[5]);
    y = get_tcl_vector(interp,name,"fdivide","y",size);
    if (y == NULL) return TCL_ERROR;

    /* Process vector */
    if (action == 1) {
      mx_divide_rows(m,n,M,y);
    } else if (action == 2) {
      mx_divide_columns(m,n,M,y);
    } else {
      mx_divide_elements(m,n,M,y);
    }

  } else {
    double v;

    /* Interpret scalar */
    if (Tcl_GetDoubleFromObj(interp,argv[5],&v) != TCL_OK) return TCL_ERROR;

    /* Process scalar */
    mx_divide_scalar(m,n,M,v);
  }


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
    set_error( interp,
		   "wrong # args: should be \"fextract m n x column ?width\""
		   );
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp,argv[1],&m) != TCL_OK 
      || Tcl_GetIntFromObj(interp,argv[2],&n) != TCL_OK
      || Tcl_GetIntFromObj(interp,argv[4],&column) != TCL_OK
      || (argc==6 && Tcl_GetIntFromObj(interp,argv[5],&width) != TCL_OK)) {
    return TCL_ERROR;
  }

  if (column+width > n || column < 0 || width < 1) {
    set_error( interp,
	"fextract: requesting columns outside matrix"
		   );
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


static int
fslice(ClientData junk, Tcl_Interp *interp, 
       int argc, Tcl_Obj *CONST argv[])
{
  int m,n;
  double x1,x2,y1,y2;
  const mxtype *x,*y,*z,*dz;
  const char *name;

  /* Interpret args */
  if (argc != 11) {
    set_error ( interp,
		   "wrong # args: should be \"fslice m n x y z dz x1 x2 y1 y2\"");

    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp,argv[1],&m) != TCL_OK 
      || Tcl_GetIntFromObj(interp,argv[2],&n) != TCL_OK
      || Tcl_GetDoubleFromObj(interp,argv[7],&x1) != TCL_OK
      || Tcl_GetDoubleFromObj(interp,argv[8],&y1) != TCL_OK
      || Tcl_GetDoubleFromObj(interp,argv[9],&x2) != TCL_OK
      || Tcl_GetDoubleFromObj(interp,argv[10],&y2) != TCL_OK) {
    return TCL_ERROR;
  }

  /* Get data vector */
  name = Tcl_GetString(argv[3]);
  x = get_tcl_vector(interp,name,"fslice","x",(m+1)*(n+1));
  if (x == NULL) return TCL_ERROR;
  name = Tcl_GetString(argv[4]);
  y = get_tcl_vector(interp,name,"fslice","y",(m+1)*(n+1));
  if (y == NULL) return TCL_ERROR;
  name = Tcl_GetString(argv[5]);
  z = get_tcl_vector(interp,name,"fslice","z", m*n);
  if (z == NULL) return TCL_ERROR;
  name = Tcl_GetString(argv[6]);
  dz = get_tcl_vector(interp,name,"fslice","dz", m*n);
  if (dz == NULL) return TCL_ERROR;


  /* Count indices */
  int *idx = (int *)malloc(sizeof(int)*m*n);
  if (idx == NULL) {
    set_error ( interp, 
		   "fslice: could not allocate memory for indices");
    return TCL_ERROR;
  }
  int nidx = mx_slice_find(n+1,m+1,x,y,x1,y1,x2,y2,m*n,idx);

  /* Build return vector */
  Tcl_Obj *robj = Tcl_NewByteArrayObj(NULL,0);
  if (!robj) { free(idx); return TCL_ERROR; }
  Tcl_SetObjResult(interp,robj);
  mxtype *r = (mxtype *)Tcl_SetByteArrayLength(robj,4*nidx*sizeof(mxtype));
  if (!r) { free(idx); return TCL_ERROR; }

  /* Fill with interpolated values */
  int interpolate = 0;
  mx_slice_interp(n+1,m+1,x,y,z,dz,x1,y1,x2,y2,nidx,idx,r,interpolate);

  free(idx); return TCL_OK;
}


static int
fintegrate(ClientData junk, Tcl_Interp *interp, 
	 int argc, Tcl_Obj *CONST argv[])
{
  int m,n,dim,return_length;
  const mxtype *x;
  mxtype *y;
  Tcl_Obj *yobj;
  const char *name;

  /* Interpret args */
  if (argc != 5) {
    set_error ( interp,
		   "wrong # args: should be \"fintegrate m n x dim\"");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp,argv[1],&m) != TCL_OK 
      || Tcl_GetIntFromObj(interp,argv[2],&n) != TCL_OK
      || Tcl_GetIntFromObj(interp,argv[4],&dim) != TCL_OK) {
    return TCL_ERROR;
  }


  /* Get data vector */
  name = Tcl_GetString(argv[3]);
  x = get_tcl_vector(interp,name,"fintegrate","x",m*n);
  if (x == NULL) return TCL_ERROR;

  /* Build return vector */
  return_length = (dim == 1 ? n : m);
  yobj = Tcl_NewByteArrayObj(NULL,0);
  if (!yobj) return TCL_ERROR;
  Tcl_SetObjResult(interp,yobj);
  y = (mxtype *)Tcl_SetByteArrayLength(yobj,return_length*sizeof(mxtype));
  if (!y) return TCL_ERROR;

  /* Extract data */
  mx_integrate(m,n,x,dim,y);

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
    set_error( interp,
		   "wrong # args: should be \"ftranspose m n x\"");
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

static int
fhsv2rgb(ClientData junk, Tcl_Interp *interp,
	 int argc, Tcl_Obj *CONST argv[])
{
  const char *name;
  mxtype *map;
  int n;

  /* Process args */
  if (argc != 3) {
    set_error ( interp,
		   "wrong # args: should be \"fhsv2rgb n map\"");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp,argv[1],&n) != TCL_OK) {
    return TCL_ERROR;
  }
  name = Tcl_GetString(argv[2]);
  map = get_unshared_tcl_vector(interp,name,"fhsv2rgb","map",4*n);
  if (map == NULL) return TCL_ERROR;

  /* Transform map */
  mx_hsv2rgb(n,map);

  return TCL_OK;
}

static int
frebin(ClientData junk, Tcl_Interp *interp, 
       int argc, Tcl_Obj *CONST argv[])
{
  int mi,mo;
  const mxtype *xi,*xo,*Ii;
  mxtype *Io;
  Tcl_Obj *Iobj;
  const char *name;

  /* Interpret args */
  if (argc != 6) {
    set_error( interp,
		   "wrong # args: should be \"frebin mi xi Ii mo xo\"");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp,argv[1],&mi) != TCL_OK 
      || Tcl_GetIntFromObj(interp,argv[4],&mo) != TCL_OK) {
    return TCL_ERROR;
  }


  /* Get data vectors */
  name = Tcl_GetString(argv[2]);
  xi = get_tcl_vector(interp,name,"frebin","xi",mi+1);
  if (xi == NULL) return TCL_ERROR;
  name = Tcl_GetString(argv[5]);
  xo = get_tcl_vector(interp,name,"frebin","xo",mo+1);
  if (xo == NULL) return TCL_ERROR;
  name = Tcl_GetString(argv[3]);
  Ii = get_tcl_vector(interp,name,"frebin","Ii",mi);
  if (Ii == NULL) return TCL_ERROR;

  /* Build return vector */
  Iobj = Tcl_NewByteArrayObj(NULL,0);
  if (!Iobj) return TCL_ERROR;
  Tcl_SetObjResult(interp,Iobj);
  Io = (mxtype *)Tcl_SetByteArrayLength(Iobj,mo*sizeof(mxtype));
  if (!Io) return TCL_ERROR;

  /* Process data */
  rebin_counts(mi,xi,Ii,mo,xo,Io);

  return TCL_OK;
}

static int
frebin2D(ClientData junk, Tcl_Interp *interp, 
	 int argc, Tcl_Obj *CONST argv[])
{
  int mi,mo,ni,no;
  const mxtype *xi,*xo, *yi, *yo, *Ii;
  mxtype *Io;
  Tcl_Obj *Iobj;
  const char *name;

  /* Interpret args */
  if (argc != 10) {
    set_error( interp,
	   "wrong # args: should be \"frebin2D mi ni xi yi Ii mo no xo yo\"");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp,argv[1],&mi) != TCL_OK 
      || Tcl_GetIntFromObj(interp,argv[2],&ni) != TCL_OK
      || Tcl_GetIntFromObj(interp,argv[6],&mo) != TCL_OK
      || Tcl_GetIntFromObj(interp,argv[7],&no) != TCL_OK
      ) {
    return TCL_ERROR;
  }


  /* Get data vectors */
  name = Tcl_GetString(argv[3]);
  xi = get_tcl_vector(interp,name,"frebin","xi",mi+1);
  if (xi == NULL) return TCL_ERROR;
  name = Tcl_GetString(argv[4]);
  yi = get_tcl_vector(interp,name,"frebin","yi",mi+1);
  if (xi == NULL) return TCL_ERROR;
  name = Tcl_GetString(argv[8]);
  xo = get_tcl_vector(interp,name,"frebin","xo",mi+1);
  if (xi == NULL) return TCL_ERROR;
  name = Tcl_GetString(argv[9]);
  yo = get_tcl_vector(interp,name,"frebin","yo",mo+1);
  if (xo == NULL) return TCL_ERROR;
  name = Tcl_GetString(argv[5]);
  Ii = get_tcl_vector(interp,name,"frebin","Ii",mi);
  if (Ii == NULL) return TCL_ERROR;

  /* Build return vector */
  Iobj = Tcl_NewByteArrayObj(NULL,0);
  if (!Iobj) return TCL_ERROR;
  Tcl_SetObjResult(interp,Iobj);
  Io = (mxtype *)Tcl_SetByteArrayLength(Iobj,mo*no*sizeof(mxtype));
  if (!Io) return TCL_ERROR;

  /* Process data */
  rebin_counts_2D(mi,xi,ni,yi,Ii,mo,xo,no,yo,Io);

  return TCL_OK;
}


extern "C" void mx_init(Tcl_Interp *interp)
{
  Tcl_CreateObjCommand( interp, "ftranspose", ftranspose, NULL, NULL );
  Tcl_CreateObjCommand( interp, "fextract", fextract, NULL, NULL );
  Tcl_CreateObjCommand( interp, "fintegrate", fintegrate, NULL, NULL );
  Tcl_CreateObjCommand( interp, "fdivide", fdivide, NULL, NULL );
  Tcl_CreateObjCommand( interp, "fprecision", fprecision, NULL, NULL );
  Tcl_CreateObjCommand( interp, "fslice", fslice, NULL, NULL );
  Tcl_CreateObjCommand( interp, "frebin", frebin, NULL, NULL );
  Tcl_CreateObjCommand( interp, "frebin2D", frebin2D, NULL, NULL );
  Tcl_CreateObjCommand( interp, "fhsv2rgb", fhsv2rgb, NULL, NULL );
}

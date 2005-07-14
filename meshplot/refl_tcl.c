#include <math.h>
#include <tcl.h>
#include "refl.h"

/* ================================================================ */
/* wrap mesh function */
static int 
buildmesh(ClientData junk, Tcl_Interp *interp, int argc, 
	  Tcl_Obj *CONST argv[])
{
  int m,n;
  Tcl_Obj *xobj, *yobj, *result;
  mxtype *x, *y;
  const char *name, *style = "  ";
  double lambda;
  int idx;

  /* Determine mesh type and size, and for -Q, find lambda */
  if (argc > 5) {
    style = Tcl_GetString(argv[1]);
    if (!style || (style[1]!='Q' && style[1]!='f' && style[1]!='d')) {
      Tcl_SetResult( interp,
		     "buildmesh: expected style -Q lambda, -f, or -d",
		     TCL_STATIC);
      return TCL_ERROR;
    }
    if (style[1] == 'Q') {
      if (Tcl_GetDoubleFromObj(interp,argv[2],&lambda) != TCL_OK) 
	return TCL_ERROR;
      idx = 2;
    } else {
      idx = 1;
    }
  } else {
    idx = 0;
  }

  /* Interpret args */
  if (! (argc==5 || (argc==7 && style[1]!='Q') || (argc==8 && style[1]=='Q'))){
    Tcl_SetResult( interp,
		   "wrong # args: should be \"buildmesh -Q lambda|-f|-d m n alpha beta dtheta\"",
		   TCL_STATIC);
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj(interp,argv[idx+1],&m) != TCL_OK 
      || Tcl_GetIntFromObj(interp,argv[idx+2],&n) != TCL_OK) {
    return TCL_ERROR;
  }

  /* Construct return list. */
  result = Tcl_NewListObj(0,NULL);
  if (!result) return TCL_ERROR;
  Tcl_SetObjResult(interp,result);

  xobj = Tcl_NewByteArrayObj(NULL,0);
  if (!xobj) return TCL_ERROR;
  Tcl_ListObjAppendElement(interp,result,xobj);
  x = (mxtype *)Tcl_SetByteArrayLength(xobj,(m+1)*(n+1)*sizeof(mxtype));
  if (!x) return TCL_ERROR;

  yobj = Tcl_NewByteArrayObj(NULL,0);
  if (!yobj) return TCL_ERROR;
  Tcl_ListObjAppendElement(interp,result,yobj);
  y = (mxtype *)Tcl_SetByteArrayLength(yobj,(m+1)*(n+1)*sizeof(mxtype));
  if (!y) return TCL_ERROR;

  /* Fill in the x and y arrays for the return list */
  if (argc >= 7) {
    const mxtype *alpha, *beta, *dtheta;
  
    /* Get data vectors */
    name = Tcl_GetString(argv[idx+3]);
    alpha = get_tcl_vector(interp,name,"buildmesh","alpha",m+1);
    if (alpha == NULL) return TCL_ERROR;

    name = Tcl_GetString(argv[idx+4]);
    beta = get_tcl_vector(interp,name,"buildmesh","beta",m+1);
    if (beta == NULL) return TCL_ERROR;

    name = Tcl_GetString(argv[idx+5]);
    dtheta = get_tcl_vector(interp,name,"buildmesh","dtheta",n+1);
    if (dtheta == NULL) return TCL_ERROR;

    switch (style[1]) {
    case 'Q': build_Qmesh(m,n,lambda,alpha,beta,dtheta,x,y); break;
    case 'd': build_dmesh(m,n,alpha,beta,dtheta,x,y); break;
    case 'f': build_fmesh(m,n,alpha,beta,dtheta,x,y); break;
    }
  } else {
    const mxtype *xin, *yin;

    /* Get data vectors */
    name = Tcl_GetString(argv[idx+3]);
    xin = get_tcl_vector(interp,name,"buildmesh","xin",m+1);
    if (xin == NULL) return TCL_ERROR;

    name = Tcl_GetString(argv[idx+4]);
    yin = get_tcl_vector(interp,name,"buildmesh","yin",n+1);
    if (yin == NULL) return TCL_ERROR;

    build_mesh(m,n,xin,yin,x,y);
  }

  return TCL_OK;
}


void refl_init(Tcl_Interp *interp)
{
  Tcl_CreateObjCommand( interp, "buildmesh", buildmesh, NULL, NULL );
}

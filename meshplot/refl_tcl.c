#include <math.h>
#include <tcl.h>
#include "tclvector.h"
#include "refl.h"

/* ================================================================ */
/* build a mesh from reflectometry measurement points               */
/* The following meshes are supported:

  TOF->Q  buildmesh -L lambda $frames $pixels $A $B dtheta
  mono->Q buildmesh -Q $lambda $frames $pixels A B dtheta
  Ti-dT   buildmesh -d $frames $pixels A B dtheta
  Ti-Tf   buildmesh -f $frames $pixels A B dtheta
  Ti-B    buildmesh -b $frames $pixels A B dtheta
  L-dT    buildmesh $frames $pixels lambda dtheta
  slits   buildmesh $frames $pixels slit1 dtheta
  pixels  buildmesh $frames $pixels pixeledges frameedges
  frame   buildmesh $nx $ny xedges yedges

*/
static int 
buildmesh(ClientData junk, Tcl_Interp *interp, int argc, 
	  Tcl_Obj *CONST argv[])
{
  int m,n;
  Tcl_Obj *xobj, *yobj, *result;
  mxtype *x, *y;
  const char *name, *style = "  ";
  int idx;
  int need_lambda=0; /* True if need an additional arg for lambda */

  /* Determine mesh type and size, and for -Q, find lambda */
  if (argc > 5) {
    style = Tcl_GetString(argv[1]);
    if (!style || (style[1]!='Q' && style[1]!='L' && style[1]!='f' && 
		   style[1]!='d' && style[1]!='b')) {
      Tcl_SetResult( interp,
		     "buildmesh: expected style -Q lambda, -L lambda, -f, -b or -d",
		     TCL_STATIC);
      return TCL_ERROR;
    }
    if (style[1] == 'Q' || style[1] == 'L') {
      /* Skip arg for 'lambda' parameter */
      need_lambda=1;
      idx = 2;
    } else {
      idx = 1;
    }
  } else {
    idx = 0;
  }

  /* Interpret args */
  if (! (argc==5 || (argc==7 && !need_lambda) || (argc==8 && need_lambda))){
    Tcl_SetResult( interp,
		   "wrong # args: should be \"buildmesh [-Q lambda|-L lambda|-f|-b|-d] m n alpha beta dtheta\"",
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

    /* Get data values */
    if (style[1] == 'L') {
      double A,B;
      const mxtype *dtheta, *lambda;

      name = Tcl_GetString(argv[2]);
      lambda = get_tcl_vector(interp,name,"buildmesh","lambda",m+1);
      if (lambda == NULL) return TCL_ERROR;

      if (Tcl_GetDoubleFromObj(interp,argv[idx+3],&A) != TCL_OK) 
	return TCL_ERROR;
      if (Tcl_GetDoubleFromObj(interp,argv[idx+4],&B) != TCL_OK) 
	return TCL_ERROR;

      name = Tcl_GetString(argv[idx+5]);
      dtheta = get_tcl_vector(interp,name,"buildmesh","dtheta",n+1);
      if (dtheta == NULL) return TCL_ERROR;
      build_Lmesh(m,n,A,B,dtheta,lambda,x,y);
    } else {
      double L;
      const mxtype *alpha, *beta, *dtheta;

      name = Tcl_GetString(argv[idx+3]);
      alpha = get_tcl_vector(interp,name,"buildmesh","alpha",m+1);
      if (alpha == NULL) return TCL_ERROR;

      name = Tcl_GetString(argv[idx+4]);
      beta = get_tcl_vector(interp,name,"buildmesh","beta",m+1);
      if (beta == NULL) return TCL_ERROR;

      name = Tcl_GetString(argv[idx+5]);
      dtheta = get_tcl_vector(interp,name,"buildmesh","dtheta",n+1);
      if (dtheta == NULL) return TCL_ERROR;

      if (need_lambda) {
	if (Tcl_GetDoubleFromObj(interp,argv[2],&L) != TCL_OK) 
	  return TCL_ERROR;
      }
      switch (style[1]) {
      case 'Q': build_Qmesh(m,n,alpha,beta,dtheta,L,x,y); break;
      case 'd': build_dmesh(m,n,alpha,beta,dtheta,x,y); break;
      case 'f': build_fmesh(m,n,alpha,beta,dtheta,x,y); break;
      case 'b': build_abmesh(m,n,alpha,beta,dtheta,x,y); break;
      }
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


/* ================================================================ */
/* find scale factor for mesh density                               */
/* The following meshes are supported:

  TOF->Q  scalemesh -L lambda $frames $pixels $A $B dtheta
  mono->Q scalemesh -Q $lambda $frames $pixels A B dtheta

*/
static int 
scalemesh(ClientData junk, Tcl_Interp *interp, int argc, 
	  Tcl_Obj *CONST argv[])
{
  int m,n;
  Tcl_Obj *result;
  mxtype *scale;
  const char *name, *style = "  ";

  /* Determine mesh type and size, and for -Q, find lambda */
  if (argc == 8) {
    style = Tcl_GetString(argv[1]);
    if (!style || (style[1]!='Q' && style[1]!='L')) {
      Tcl_SetResult( interp,
		     "scalemesh: expected style -Q lambda or -L lambda",
		     TCL_STATIC);
      return TCL_ERROR;
    }
  }

  /* Interpret args */
  if (! (argc==8) ){
    Tcl_SetResult( interp,
		   "wrong # args: should be \"scalemesh [-Q lambda|-L lambda] m n alpha beta dtheta\"",
		   TCL_STATIC);
    return TCL_ERROR;
  }

  if (Tcl_GetIntFromObj(interp,argv[3],&m) != TCL_OK 
      || Tcl_GetIntFromObj(interp,argv[4],&n) != TCL_OK) {
    return TCL_ERROR;
  }

  /* Construct return list. */
  result = Tcl_NewListObj(0,NULL);
  if (!result) return TCL_ERROR;

  result = Tcl_NewByteArrayObj(NULL,0);
  if (!result) return TCL_ERROR;
  Tcl_SetObjResult(interp,result);
  scale = (mxtype *)Tcl_SetByteArrayLength(result,m*n*sizeof(mxtype));
  if (!scale) return TCL_ERROR;

  /* Get data values */
  if (style[1] == 'L') {
    double A,B;
    const mxtype *dtheta, *lambda;
    
    name = Tcl_GetString(argv[2]);
    lambda = get_tcl_vector(interp,name,"buildmesh","lambda",m);
    if (lambda == NULL) return TCL_ERROR;
    
    if (Tcl_GetDoubleFromObj(interp,argv[5],&A) != TCL_OK) 
      return TCL_ERROR;
    if (Tcl_GetDoubleFromObj(interp,argv[6],&B) != TCL_OK) 
      return TCL_ERROR;
    
    name = Tcl_GetString(argv[7]);
    dtheta = get_tcl_vector(interp,name,"buildmesh","dtheta",n);
    if (dtheta == NULL) return TCL_ERROR;
    scale_Lmesh(m,n,A,B,dtheta,lambda,scale);
  } else {
    double L;
    const mxtype *alpha, *beta, *dtheta;
    
    if (Tcl_GetDoubleFromObj(interp,argv[2],&L) != TCL_OK) 
      return TCL_ERROR;

    name = Tcl_GetString(argv[5]);
    alpha = get_tcl_vector(interp,name,"buildmesh","alpha",m);
    if (alpha == NULL) return TCL_ERROR;
    
    name = Tcl_GetString(argv[6]);
    beta = get_tcl_vector(interp,name,"buildmesh","beta",m);
    if (beta == NULL) return TCL_ERROR;
    
    name = Tcl_GetString(argv[7]);
    dtheta = get_tcl_vector(interp,name,"buildmesh","dtheta",n);
    if (dtheta == NULL) return TCL_ERROR;
    
    scale_Qmesh(m,n,alpha,beta,dtheta,L,scale);
  }

  return TCL_OK;
}


/* ================================================================ */
/* find the measurement associated with a point in a mesh           */
static int 
findmesh(ClientData junk, Tcl_Interp *interp, int argc, 
	  Tcl_Obj *CONST argv[])
{
  Tcl_Obj *result;
  int m,n;
  double x, y;
  const char *name, *style = "  ";
  int idx, id, have_dtheta;
  int need_lambda=0; /* True if need an additional arg for lambda */

  /* Determine mesh type and size, and for -Q, find lambda */
  if (argc > 7) {
    style = Tcl_GetString(argv[1]);
    if (!style || (style[1]!='Q' && style[1]!='L' && style[1]!='f' && 
		   style[1]!='d' && style[1]!='b')) {
      Tcl_SetResult( interp,
		     "findmesh: expected style -Q lambda, -L lambda, -f, -b or -d",
		     TCL_STATIC);
      return TCL_ERROR;
    }
    if (style[1] == 'Q' || style[1] == 'L') {
      /* Skip arg for 'lambda' parameter */
      need_lambda=1;
      idx = 2;
    } else {
      idx = 1;
    }
  } else {
    idx = 0;
  }

  /* Interpret args */
  if (! (argc==7 || (argc==9 && !need_lambda) || (argc==10 && need_lambda))){
    Tcl_SetResult( interp,
		   "wrong # args: should be \"findmesh [-Q lambda|-L lambda|-f|-b|-d] m n alpha beta dtheta x y\"",
		   TCL_STATIC);
    return TCL_ERROR;
  }

  have_dtheta = (argc == 7 ? 0 : 1);
  if (Tcl_GetIntFromObj(interp,argv[idx+1],&m) != TCL_OK 
      || Tcl_GetIntFromObj(interp,argv[idx+2],&n) != TCL_OK
      || Tcl_GetDoubleFromObj(interp,argv[idx+5+have_dtheta],&x) != TCL_OK
      || Tcl_GetDoubleFromObj(interp,argv[idx+6+have_dtheta],&y) != TCL_OK
			      ) {
    return TCL_ERROR;
  }

  /* Find quad containing the point */
  id = -1;
  if (argc >= 9) {

    /* Get data values */
    if (style[1] == 'L') {
      double A,B;
      const mxtype *dtheta, *lambda;

      name = Tcl_GetString(argv[2]);
      lambda = get_tcl_vector(interp,name,"findmesh","lambda",m+1);
      if (lambda == NULL) return TCL_ERROR;

      if (Tcl_GetDoubleFromObj(interp,argv[idx+3],&A) != TCL_OK) 
	return TCL_ERROR;
      if (Tcl_GetDoubleFromObj(interp,argv[idx+4],&B) != TCL_OK) 
	return TCL_ERROR;

      name = Tcl_GetString(argv[idx+5]);
      dtheta = get_tcl_vector(interp,name,"findmesh","dtheta",n+1);
      if (dtheta == NULL) return TCL_ERROR;
      id = find_in_Lmesh(m,n,A,B,dtheta,lambda,x,y);
    } else {
      double L;
      const mxtype *alpha, *beta, *dtheta;

      name = Tcl_GetString(argv[idx+3]);
      alpha = get_tcl_vector(interp,name,"findmesh","alpha",m+1);
      if (alpha == NULL) return TCL_ERROR;

      name = Tcl_GetString(argv[idx+4]);
      beta = get_tcl_vector(interp,name,"findmesh","beta",m+1);
      if (beta == NULL) return TCL_ERROR;

      name = Tcl_GetString(argv[idx+5]);
      dtheta = get_tcl_vector(interp,name,"findmesh","dtheta",n+1);
      if (dtheta == NULL) return TCL_ERROR;

      if (need_lambda) {
	if (Tcl_GetDoubleFromObj(interp,argv[2],&L) != TCL_OK) 
	  return TCL_ERROR;
      }
      switch (style[1]) {
      case 'Q': id = find_in_Qmesh(m,n,alpha,beta,dtheta,L,x,y); break;
      case 'd': id = find_in_dmesh(m,n,alpha,beta,dtheta,x,y); break;
      case 'f': id = find_in_fmesh(m,n,alpha,beta,dtheta,x,y); break;
      case 'b': id = find_in_abmesh(m,n,alpha,beta,dtheta,x,y); break;
      }
    }

  } else {
    const mxtype *xin, *yin;

    /* Get data vectors */
    name = Tcl_GetString(argv[idx+3]);
    xin = get_tcl_vector(interp,name,"findmesh","xin",m+1);
    if (xin == NULL) return TCL_ERROR;

    name = Tcl_GetString(argv[idx+4]);
    yin = get_tcl_vector(interp,name,"findmesh","yin",n+1);
    if (yin == NULL) return TCL_ERROR;

    id = find_in_mesh(m,n,xin,yin,x,y);
  }

  result = Tcl_GetObjResult(interp);
  Tcl_SetIntObj(result, id);
  return TCL_OK;
}


void refl_init(Tcl_Interp *interp)
{
  Tcl_CreateObjCommand( interp, "buildmesh", buildmesh, NULL, NULL );
  Tcl_CreateObjCommand( interp, "scalemesh", scalemesh, NULL, NULL );
  Tcl_CreateObjCommand( interp, "findmesh", findmesh, NULL, NULL );
}

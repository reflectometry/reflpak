#include <math.h>

/* Some basic matrix operations which don't belong in a generic
 * plotting tool, but which I don't want to create a separate DLL
 * just to handle them because I'm not going to create a complete
 * package.
 */

/* From Robin Becker <robin@jessikat.fsnet.co.uk>
 * Posted to sci.math.num-analysis on Dec 6 2003, 2:24 pm
 * He does not remember who is the original author.
 */
typedef PReal mxtype;
void mx_transpose(int n, int m, mxtype *a, mxtype *b)
{
  int size = m*n;
  if(b!=a){ /* out of place transpose */
    mxtype *bmn, *aij, *anm;
    bmn = b + size; /*b+n*m*/
    anm = a + size;
    while(b<bmn) for(aij=a++;aij<anm; aij+=n ) *b++ = *aij;
  }
  else if(n!=1 && m!=1){ /* in place transpose */
    /* PAK: use (n!=1&&m!=1) instead of (size!=3) to avoid vector transpose */
    int i,row,column,current;
    for(i=1, size -= 2;i<size;i++){
      current = i;
      do {
	/*current = row+n*column*/
	column = current/m;
	row = current%m;
	current = n*row + column;
      } while(current < i);

      if (current>i) {
	mxtype temp = a[i];
	a[i] = a[current];
	a[current] = temp;
      }
    }
  }
}

/* 0-origin dense column extraction */
void mx_extract_columns(int m, int n, const mxtype *a,
			int column, int width, mxtype *b)
{
  int i, j;
  int idx = 0;
  a += column;
  for (i=0; i < m; i++) {
    for (j=0; j < width; j++) b[idx++] = a[j];
    a += n;
  }
}

void mx_divide_columns(int m, int n, mxtype *M, const mxtype *y)
{
  int i, j;
  for (i=0; i < m; i++) {
    for (j=0; j < n; j++) M[j] /= y[i];
    M += n;
  }
}


/* Build a mesh from the scan of linear detector readings.
 *
 * Values for the scan are stored as a dense vector, point by point:
 *
 *   bin_1 bin_2 ... bin_m bin_1 bin_2 ... bin_m ... bin_1 bin_2 ... bin_m
 *   \------point 1------/ \------point 1------/ ... \------point n------/
 *
 * The values are assumed to be at the centers of the pixels, and the mesh
 * will be built up from the bin edges, and from the alpha and beta angles
 * of the detector.  The resulting grid will be complete but not 
 * necessarily rectilinear.
 *
 * The angle alpha, also known as theta or as A3, is the angle of the beam 
 * with respect to the surface of the sample.   The angle beta, also known 
 * as two-theta or as A4, is the angle of the detector with respect to the
 * beam.
 *
 * There a few different scans we want to be able to support:
 *
 *   point vs. bin
 *   theta_i vs. bin
 *   theta_i vs. dtheta
 *   theta_i vs. theta_f
 *   theta_i vs. theta_f-theta_i
 *   Qz vs. Qx
 *
 * We have specialized functions to construct the meshes for each scan:
 *
 *   build_fmesh (n, m, alpha, beta, dtheta, x, y)
 *     Contructs indices for theta_i vs. theta_f.
 *   build_dmesh (n, m, alpha, beta, dtheta, x, y)
 *     Constructs theta_i vs. theta_f-theta_i.
 *   build_Qmesh (n, m, alpha, beta, dtheta, x, y)
 *     Constructs Qz vs. Qx.
 *   build_mesh (n, m, points, bins, x, y)
 *     Constructs point vs. bin.  Using alpha instead of points and
 *     dtheta instead of bins we can construct theta_i vs. bin and
 *     theta_i vs. dtheta.
 * 
 * Creating the set of bin edges is an easy enough problem that it
 * can be done in a script.

proc edges {centers} {
  if { [llength $centers] == 1 } {
    if { $centers == 0. } {
      set e {-1. 1}
    } elseif { $centers < 0. } {
      set e [list [expr {2.*$centers}] 0.]
    } else {
      set e [list 0 [expr {2.*$centers}]]
    }
  } else {
    set l [lindex $centers 0]
    set r [lindex $centers 1]
    set e [expr {$l - 0.5*($r-$l)}]
    foreach r [lrange $centers 1 end] {
      lappend e [expr {0.5*($l+$r)}]
      set l $r
    }
    set l [lindex $centers end-2]
    lappend e [expr {$r + 0.5*($r-$l)}]
  }
  return $e
}

proc bin_edges {pixels} {
  set edges {}
  for {set p 0} {$p <= $pixels} {incr p} {
    lappend edges [expr {$p+0.5}]
  }
  return $edges
}

proc dtheta_edges {pixels pixelwidth distance centerpixel} {
  set edges {}
  for {set p 0} {$p <= $pixels} {incr p} {
    lappend edges [expr {atan2(($centerpixel-$p)*$pixelwidth, $distance)}]
  }
  return $edges
}

 */

void 
build_mesh(int m, int n, const PReal xin[], const PReal yin[],
	   PReal x[], PReal y[])
{
  int idx = 0;
  int j, k;
  for (j=0; j <= n; j++) {
    for (k=0; k <= m; k++) {
      y[idx] = yin[j];
      x[idx] = xin[k];
      idx++;
    }
  }
}

void 
build_fmesh(int n, int m, 
	    const PReal alpha[], const PReal beta[], const PReal dtheta[],
	    PReal x[], PReal y[])
{
  int idx = 0;
  int j, k;
  for (j=0; j <= n; j++) {
    for (k=0; k <= m; k++) {
      y[idx] = alpha[j];
      x[idx] = 0.5*beta[j] + dtheta[k];
      idx++;
    }
  }
}

void 
build_dmesh(int n, int m,
	    const PReal alpha[], const PReal beta[], const PReal dtheta[],
	    PReal x[], PReal y[])
{
  int idx = 0;
  int j, k;
  for (j=0; j <= n; j++) {
    for (k=0; k <= m; k++) {
      y[idx] = alpha[j];
      x[idx] = 0.5*beta[j] - alpha[j] + dtheta[k];
      idx++;
    }
  }
}

void
build_Qmesh(int n, int m, PReal lambda,
	    const PReal alpha[], const PReal beta[], const PReal dtheta[],
	    PReal Qx[], PReal Qz[])
{
  const PReal two_pi_over_lambda = 2.*M_PI/lambda;
  int idx = 0;
  int j,k;
  for (j=0; j <= n; j++) {
    const PReal in = alpha[j]*(M_PI/180.);
    for (k=0; k <= m; k++) {
      const PReal out = (0.5*beta[j]+dtheta[k])*(M_PI/180.);
      Qz[idx] = two_pi_over_lambda*(sin(in)+sin(out));
      Qx[idx] = two_pi_over_lambda*(cos(in)-cos(out));
      idx++;
    }
  }
}


/* ================================================================ */

static int
fdivide(ClientData junk, Tcl_Interp *interp, 
	 int argc, Tcl_Obj *CONST argv[])
{
  int m,n;
  const PReal *y;
  PReal *M;
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
  const PReal *x;
  PReal *y;
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
  y = (PReal *)Tcl_SetByteArrayLength(yobj,m*width*sizeof(PReal));
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
  PReal *x;
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
  Tcl_SetObjResult(interp,Tcl_NewIntObj(sizeof(PReal)));
  return TCL_OK;
}

/* wrap mesh function */
static int 
buildmesh(ClientData junk, Tcl_Interp *interp, int argc, 
	  Tcl_Obj *CONST argv[])
{
  int m,n;
  Tcl_Obj *xobj, *yobj, *result;
  PReal *x, *y;
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
  x = (PReal *)Tcl_SetByteArrayLength(xobj,(m+1)*(n+1)*sizeof(PReal));
  if (!x) return TCL_ERROR;

  yobj = Tcl_NewByteArrayObj(NULL,0);
  if (!yobj) return TCL_ERROR;
  Tcl_ListObjAppendElement(interp,result,yobj);
  y = (PReal *)Tcl_SetByteArrayLength(yobj,(m+1)*(n+1)*sizeof(PReal));
  if (!y) return TCL_ERROR;

  /* Fill in the x and y arrays for the return list */
  if (argc >= 7) {
    const PReal *alpha, *beta, *dtheta;
  
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
    const PReal *xin, *yin;

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

static void refl_init(Tcl_Interp *interp)
{
  Tcl_CreateObjCommand( interp, "ftranspose", ftranspose, NULL, NULL );
  Tcl_CreateObjCommand( interp, "fextract", fextract, NULL, NULL );
  Tcl_CreateObjCommand( interp, "fdivide", fdivide, NULL, NULL );
  Tcl_CreateObjCommand( interp, "fprecision", fprecision, NULL, NULL );
  Tcl_CreateObjCommand( interp, "buildmesh", buildmesh, NULL, NULL );
}

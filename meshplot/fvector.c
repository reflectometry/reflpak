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

static void fvector_init(Tcl_Interp *interp)
{
  Tcl_CreateObjCommand( interp, "ftranspose", ftranspose, NULL, NULL );
  Tcl_CreateObjCommand( interp, "fextract", fextract, NULL, NULL );
  Tcl_CreateObjCommand( interp, "fdivide", fdivide, NULL, NULL );
  Tcl_CreateObjCommand( interp, "fprecision", fprecision, NULL, NULL );
}

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


/* wrap in-place transpose function */
static int 
refl_transpose(ClientData junk, Tcl_Interp *interp, int argc, 
	       Tcl_Obj *CONST argv[])
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
  name = Tcl_GetString(argv[3]);

  /* Get data vector */
  x = get_unshared_tcl_vector(interp,name,"ftranspose","x",m*n);
  if (x == NULL) return TCL_ERROR;

  /* Perform in-place transpose */
  mx_transpose(m,n,x,x);

  return TCL_OK;
}

static void refl_init(Tcl_Interp *interp)
{
  Tcl_CreateObjCommand( interp, "ftranspose", refl_transpose, NULL, NULL );
}

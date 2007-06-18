/* library functions which may go to a separate file */

#include <string.h>
#include "tclvector.h"

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

PReal* build_return_vector(Tcl_Interp *interp, size_t n)
{
  Tcl_Obj *xobj = Tcl_NewByteArrayObj(NULL,0);
  if (!xobj) return NULL;
  else {
    PReal *x = (PReal *)Tcl_SetByteArrayLength(xobj,n*sizeof(PReal));
    if (!x) Tcl_SetObjResult(interp,xobj);
    return x;
  }
}


/* Helper functions to build return values */
int int_result(Tcl_Interp *interp, int k)
{
  Tcl_Obj *result = Tcl_GetObjResult(interp);
  Tcl_SetIntObj(result, k);
  return TCL_OK;
}

int real_result(Tcl_Interp *interp, double v)
{
  Tcl_Obj *result = Tcl_GetObjResult(interp);
  Tcl_SetDoubleObj(result, v);
  return TCL_OK;
}

int real_vector_result(Tcl_Interp *interp, size_t n, const PReal v[])
{
  size_t i;

  PReal *x = build_return_vector(interp, n); 
  if (x == 0) return TCL_ERROR;
  for (i=0; i < n; i++) x[i] = v[i];
  return TCL_OK;
}

/* end lib */

/* This program is public domain */

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
 *
 *
 * Returning values to the Tcl interpreter:
 *
 * v[] = build_return_vector(interp, n)
 *   Create storage for a vector to be returned to the Tcl interpreter.
 *   This is not normally used directly.  Instead vector_result builds
 *   the return vector and copies the content of the vector managed
 *   elsewhere in your program.
 *
 *
 * status = vector_result(interp, n, v[])
 *   Return the vector v of length n to the interpreter.
 *
 * status = real_result(interp, v)
 *   Return v to the Tcl interpreter
 *
 * status = int_result(interp, i)
 *   Return i to the Tcl interpreter
 *
 */

#ifndef _TCLVECTOR_H
#define _TCLVECTOR_H

#include <tcl.h>
#ifdef USE_DOUBLE
#define PReal double
#else
#define PReal float
#endif

#ifdef __cplusplus
# define EXPORT extern "C"
#else
# define EXPORT extern
#endif


EXPORT const PReal *
get_tcl_vector(Tcl_Interp *interp, const char *name,
	       const char *context, const char *role,int size);

EXPORT PReal *
get_unshared_tcl_vector(Tcl_Interp *interp, const char *name, 
			const char *context, const char *role, int size);

EXPORT PReal *
get_private_tcl_vector(Tcl_Interp *interp, const char *name,
		       const char *context, const char *role, int size);


EXPORT PReal* 
build_return_vector(Tcl_Interp *interp, size_t n);


EXPORT int
int_result(Tcl_Interp *interp, int k);

EXPORT int 
real_result(Tcl_Interp *interp, double v);

EXPORT int 
real_vector_result(Tcl_Interp *interp, size_t n, const PReal v[]);


#ifdef __cplusplus
#include <vector>
template <class T> int
vector_result(Tcl_Interp *interp, size_t n, const T v[])
{
  PReal *x = build_return_vector(interp, n); 
  if (x == 0) return TCL_ERROR;
  for (size_t i=0; i < n; i++) x[i] = v[i];
  return TCL_OK;
}

template <class T> inline int
vector_result(Tcl_Interp *interp, const std::vector<T>& v)
{
  return vector_result(interp, v.size(), &v[0]);
}
#endif


#endif /* _TCLVECTOR_H */

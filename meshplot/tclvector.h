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

#include <tcl.h>
#ifdef USE_DOUBLE
#define PReal double
#else
#define PReal float
#endif

extern const PReal *
get_tcl_vector(Tcl_Interp *interp, const char *name,
	       const char *context, const char *role,int size);

extern PReal *
get_unshared_tcl_vector(Tcl_Interp *interp, const char *name, 
			const char *context, const char *role, int size);

extern PReal *
get_private_tcl_vector(Tcl_Interp *interp, const char *name,
		       const char *context, const char *role, int size);

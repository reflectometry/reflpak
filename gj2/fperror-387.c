/* This code is in the public domain.

C usage:
 
    int fperror();
    ...
    clear_fp_error();
    ...
    if (fperror()) { 
       printf("there has been an error since fp_error_clear()\n"); 
    }

FORTRAN usage:

    INTEGER FP_ERROR
    EXTERNAL FP_ERROR
    ...
    CALL FP_ERROR_CLEAR
    ...
    IF (FP_ERROR() .NE. 0) THEN
       WRITE (*,*) "There has been an error since FP_ERROR_CLEAR"
    ENDIF

This code has been tested gcc in linux running on intel hardware.
It certainly will not work on non-intel compatible floating point
hardware since it uses explicit intel fp instructions.  It probably
will not work without gcc and may not work under cygwin (due to the
missing fpu_control.h).

Your standard libc startup code may or may not generate SIGFPE signals
when it encounters arithmetic exceptions. If you find that your program
is terminating on division by zero, etc., then compile with

          gcc -c -DCLEARTRAP fperror-387.c

This includes startup code which avoids exception trapping.  You do
not need to change the calling code for this to work, but it will only
work with the gcc compiler.

*/

#ifdef HAVE_FPU_CONTROL_H

#include <fpu_control.h>

#else /* !HAVE_FPU_CONTROL_H */

/* The following is cribbed fpu_control.h.  You may need to change it
   if you are using a different version of gcc */

typedef unsigned int fpu_control_t __attribute__ ((__mode__ (__HI__)));

/* IEEE default fp behaviour */
#define _FPU_DEFAULT  0x037f

/* IM: invalid operation
   DM: denormalized
   ZM: divide by zero
   OM: overflow
   UM: underflow
   PM: loss of precision  */
#define _FPU_MASK_IM  0x01
#define _FPU_MASK_DM  0x02
#define _FPU_MASK_ZM  0x04
#define _FPU_MASK_OM  0x08
#define _FPU_MASK_UM  0x10
#define _FPU_MASK_PM  0x20

#define _FPU_SETCW(cw) __asm__ ("fldcw %0" : : "m" (*&cw))

#endif /* !HAVE_FPU_CONTROL_H */

/* The following should be in fpu_control.h but aren't. */
#define _FPU_GETSW(sw) __asm__ ("fstsw %0" : "=m" (*&sw))
#define _FPU_CLEX      __asm__ ("fclex")

/* Don't trap any exceptions */
#define MASK (_FPU_MASK_IM|_FPU_MASK_DM|_FPU_MASK_OM|_FPU_MASK_UM|_FPU_MASK_ZM)

#if defined(CLEARTRAP)

/* Avoid exception trapping.
   The "constructor" attribute means that this function will 
   be called before main(), so you don't need to call it directly. */
static void __attribute__ ((constructor))
cleartrapfpe ()
{
  fpu_control_t flags = _FPU_DEFAULT | MASK;
  _FPU_SETCW(flags);
}

#endif /* CLEARTRAP */

/* Test the sticky bits. */
int fp_error(void)
{
  fpu_control_t flags;
  _FPU_GETSW(flags);
  return (flags&MASK) != 0;
}
int fp_error__(void)
{
  fpu_control_t flags;
  _FPU_GETSW(flags);
  return (flags&MASK) != 0;
}

/* Clear the sticky bits. */
void fp_error_clear(void)
{
  _FPU_CLEX;
}
void fp_error_clear__(void)
{
  _FPU_CLEX;
}

/* This code is in the public domain.

Remove error traps, and provide simple access to floating point sticky
bits.

C usage:
 
    fpreset();
    ...
    if (fperror()) { 
       printf("there has been an error since the last call to fperror()\n"); 
    }

FORTRAN usage:

    EXTERNAL FPERROR
    INTEGER FPERROR
    CALL FPRESET
    ...
  
    IF (FPERROR() .NE. 0) THEN
       WRITE (*,*) "There has been an error since the last call to FPERROR"
    ENDIF

*/

#include <fenv.h>

/* Define C and fortran variants. */

#ifndef F77_FUNC
#ifdef sgi
#define F77_FUNC(lower,upper) lower ## _
#else
#define F77_FUNC(lower,upper) lower ## __
#endif
#endif

#define fperrorF77 F77_FUNC(fperror,FPERROR)
#define fpresetF77 F77_FUNC(fpreset,FPRESET)

void fpreset (void) 
{ 
  fenv_t env; 
  feholdexcept(&env); 
}
void fpresetF77 (void) 
{ 
  fenv_t env; 
  feholdexcept(&env); 
}

int fperror (void) 
{
  int flags = fetestexcept(FE_ALL_EXCEPT);
  feclearexcept(FE_ALL_EXCEPT);
  return flags != 0;
}
int fperrorF77 (void) 
{
  int flags = fetestexcept(FE_ALL_EXCEPT);
  feclearexcept(FE_ALL_EXCEPT);
  return flags != 0;
}

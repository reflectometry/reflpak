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
/* IRIX and linux use a lowercase name followed by an _ */
#define F77_FUNC(lower,upper) lower ## _
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

#define USEFUL_FLAGS FE_DIVBYZERO|FE_UNDERFLOW|FE_OVERFLOW|FE_INVALID
int fperror (void) 
{
  int flags = fetestexcept(USEFUL_FLAGS);
  feclearexcept(USEFUL_FLAGS);
  return flags != 0;
}
int fperrorF77 (void) 
{
  int flags = fetestexcept(USEFUL_FLAGS);
  feclearexcept(USEFUL_FLAGS);
  return flags != 0;
}

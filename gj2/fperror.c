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

#define USEFUL_FLAGS FE_DIVBYZERO|FE_UNDERFLOW|FE_OVERFLOW|FE_INVALID
void fpreset (void) 
{ 
  fenv_t env; 
  feholdexcept(&env); 
  feclearexcept(USEFUL_FLAGS);
}
void fpresetF77 (void) 
{ 
  fenv_t env; 
  feholdexcept(&env); 
  feclearexcept(USEFUL_FLAGS);
}

#if 0
void fpreport (int flags)
{
  if (flags != 0) {
    if (flags&FE_DIVBYZERO) printf("DIVBYZERO\n");
    flags &= ~FE_DIVBYZERO;
    if (flags&FE_UNDERFLOW) printf("UNDERFLOW\n");
    flags &= ~FE_UNDERFLOW;
    if (flags&FE_OVERFLOW) printf("OVERFLOW\n");
    flags &= ~FE_OVERFLOW;
    if (flags&FE_INVALID) printf("INVALID\n");
    flags &= ~FE_INVALID;
    if (flags != 0) printf("flags still contains %x\n",flags);
  }
}
#endif

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

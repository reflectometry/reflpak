/* This code is in the public domain.

C usage:
 
    fpreset();
    ...
    if (fpreset()) { 
       printf("there has been an error since the last call to fperror()\n"); 
    }

FORTRAN usage:

    INTEGER FPERROR
    EXTERNAL FPERROR
    CALL FPCLEAR
    ...
  
    IF (FPERROR() .NE. 0) THEN
       WRITE (*,*) "There has been an error since the last call to FP_ERROR"
    ENDIF

*/

#include <fenv.h>

/* Define C and fortran variants. */

#ifndef F77_FUNC
#define F77_FUNC(lower,upper) lower ## __
#endif

void fpreset (void) 
{ 
  fenv_t env; 
  feholdexcept(&env); 
}
void F77_FUNC(fpreset,FPRESET) (void) 
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

int F77_FUNC(fperror,FPERROR) (void) 
{
  int flags = fetestexcept(FE_ALL_EXCEPT);
  feclearexcept(FE_ALL_EXCEPT);
  return flags != 0;
}

/* Subroutine FGENM4 calculates the log(reflectivity) and derivatives */
/* of magnetic profiles to be used by fit routine MRQMIN */
/* John Ankner 21 September 1992 */

#ifndef _FGENM4_H
#define _FGENM4_H

void fgenm4(double q[], double *a, double *yfit, double *dyda, int ndata,
   int ma);

#endif /* _FGENM4_H */


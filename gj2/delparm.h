/* Subroutine makes a small increment in fit parameter A(NPARM) to be
   used when evaluating a numerical derivative
   John Ankner 27 February 1991 */

#ifndef _DELPARM_H
#define _DELPARM_H

void delparm(int nparm, int plus, double *delP);

#endif /* _DELPARM_H */


/* Subroutine generates substrate tail of layer profile
   John Ankner 5 December 1990 */

#ifndef _GENSUB_H
#define _GENSUB_H

void gensub(double qcsq[], double d[], double rough[], double mu[],
            int nlayer, double zint[], double rufint[], int nrough);

#endif /* _GENSUB_H */


/* Subroutine generates vacuum tail of layer profile
   John Ankner 5 December 1990 */

#ifndef _GENVAC_H
#define _GENVAC_H

void genvac(double qcsq[], double d[], double rough[], double mu[],
            int nlayer, double zint[], double rufint[], int nrough);
double vacThick(double rough[], double zint[], int nrough);

#endif /* _GENVAC_H */


/* Generate error function of ordinate steps based on those of the hyperbolic
   tangent (since cannot find inverse erf) given the
   number of points in said profile
   John Ankner 8 November 1990 */

#ifndef _GENERF_H
#define _GENERF_H

void generf(int nrough, double zint[], double rufint[]);

#endif /* _GENERF_H */


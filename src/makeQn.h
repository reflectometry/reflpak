/* Calculates normal component of momentum transfer for layer N
   for use in GREFAMP and GREFINT */

#ifndef _MAKEQN_H
#define _MAKEQN_H

#include <complex.h>

complex makeQn(double qi, double gqcsq, double beta_n);

#endif /* _MAKEQN_H */


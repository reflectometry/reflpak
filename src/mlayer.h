/* To use GNUPLOT from a kermit - based PC:  Type 'setenv GNUTERM kc' before
   running gmlayer!!!!!

  Program fits up to 9 layer reflectivity using algorithm of
  L.G. Parratt, Phys. Rev. 95, 359 (1954) to calculate reflectivity and
  Levenberg - Marquardt non - linear least squares fit routines from
  William H. Press, Brian P. Flannery, Saul A. Teukolsky, and William T.
  Vetterling, Numerical Recipes (Cambridge University Press, Cambridge,
  1986), ch. 14.
  John Ankner 3 January 1989 */

#ifndef _MLAYER_H
#define _MLAYER_H

void mlayer(void);

#endif /* _MLAYER_H */


/* Subroutine calculates reflectivity of multilayer by calling
   GENMLAYERS to evaluate the cap layers, looping over the
   multilayer, evaluating the buffer and substrate layers, and
   combining it all into one profile
   John Ankner 26-June-1990 */


#ifndef _GENMULTI_H
#define _GENMULTI_H

void genmulti(double tqcsq[], double mqcsq[], double bqcsq[], double tqcmsq[],
              double mqcmsq[], double bqcmsq[],
              double td[], double md[], double bd[],
              double trough[], double mrough[], double brough[], double tmu[],
              double mmu[], double bmu[],
              int nrough, int ntlayer, int nmlayer, int nblayer, int nrepeat,
              char *proftyp);

#endif /* _GENMULTI_H */


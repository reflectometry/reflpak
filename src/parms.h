/*-new parameter file in ASCII form*****/

#ifndef _PARMS_H
#define _PARMS_H

#define NOPARMFILE 1
#define BADPARMDATA 2
#define NOPARMSCRIPT 3

int parms(double tqcsq[], double mqcsq[], double bqcsq[], double tqcmsq[],
          double mqcmsq[], double bqcmsq[],
          double td[], double md[], double bd[],
          double trough[], double mrough[], double brough[],
          double tmu[], double mmu[], double bmu[],
          int maxlay, double *lambda,
          double *lamdel, double *thedel,
          int *ntlayer, int *nmlayer, int *nblayer, int *nrepeat,
          double *qmin, double *qmax, int *npnts,
          char *infile, char *outfile,
          double *bmintns, double *bki, int lista[], int *mfit,
          int na, int *nrough, char *proftyp,
          double *unc, char *scriptfile, char *parfile,
          int store);

#endif /* _PARMS_H */


/* Subroutine retrieves and stores parameters from and to disk */

#ifndef _PARMS_H
#define _PARMS_H

#define NOPARMFILE 1
#define BADPARMDATA 2
#define NOPARMSCRIPT 3

int parms(double *qcsq, double *qcmsq, double *d, double *dm, double *rough,
   double *mrough, double *mu, double *the, int maxlay,
   double *lambda, double *lamdel, double *thedel, int *nlayer,
   double *qmina, double *qmaxa, int *npntsa,
   double *qminb, double *qmaxb, int *npntsb,
   double *qminc, double *qmaxc, int *npntsc,
   double *qmind, double *qmaxd, int *npntsd,
   char *infile, char *outfile, double *bmintns, double *bki,
   int lista[], int *mfit, int na, int *nrough, char *proftyp,
   char *polstat, double *unc, char *scriptfile, char *parfile, int store);

#endif /* _PARMS_H */


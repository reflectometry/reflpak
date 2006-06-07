/* Fetches parameters from command line */

#ifndef _SETPARAMS_H
#define _SETPARAMS_H

int setVQCSQ(double *qcsq);
int setVMU(double *mu);
int setQCSQ(int n, double *qcsq, double *unc);
int setMU(int n, double *mu, double *unc);
int setD(int n, double *d, double *unc);
int setRO(int n, double *rough, double *unc);
int setWavelength(double *lambda);
int setThetaoffset(double *theta_offset);
int setNLayer(int *nlayer);
int setNRough(int *nrough);
int setProfile(char *proftype, int proftyplen);
int setNrepeat(int *nrepeat);
int setQrange(double *qmin, double *qmax);
int setNpnts(void);
int setFilename(char *file, int namelen);
int setLamdel(double *lamdel);
int setThedel(double *thedel);
int setBeamIntens(double *bmintns, double *unc);
int setBackground(double *bki, double *unc);
int fetchLayParam(char *command, char *paramcom, double *top, double *mid,
   double *bot, double *Dtop, double *Dmid, double *Dbot,
   int (*store)(int, double *, double *));
int modifyLayers(char *command);
int copyLayer(char *command);

#endif /* _SETPARAMS_H */


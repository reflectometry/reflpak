/* Fetches parameters from command line */

#ifndef _GETPARAMS_H
#define _GETPARAMS_H

int setVQCSQ(double *qcsq);
int setVMQCSQ(double *qcmsq);
int setVMU(double *mu);
int setLamdel(double *lamdel);
int setThedel(double *thedel);
int setWavelength(double *lambda);
int setNrough(int *nrough);
int setNpnts(int *npnts);
int setBeamIntens(double *bmintns, double *unc);
int setBackground(double *bki, double *unc);
int setQCSQ(char *command, double *qcsq, double *unc);
int setMQCSQ(char *command, double *mqcsq, double *unc);
int setMU(char *command, double *mu, double *unc);
int setDM(char *command, double *dm, double *unc);
int setD(char *command, double *d, double *unc);
int setRO(char *command, double *rough, double *unc);
int setMRO(char *command, double *mrough, double *unc);
int setTHE(char *command, double *the, double *unc);
int setNlayer(int *nlayer);
int setProfile(char *proftyp, int proftyplen);
int setQrange(double *qmin, double *qmax);
int setFilename(char *file, int namelen);
int setPolstat(char *polstat, int polstatlen);
int modifyLayers(char *command);
int copyLayer(char *command);
int superLayer(char *command);

#endif /* _GETPARAMS_H */


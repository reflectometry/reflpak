/* Generates output */

#ifndef _PRINTINFO_H
#define _PRINTINFO_H

int printLayers(char *command);
int listData(void);
int genReflect(char *command);
int genProfile(char *command);
int saveTemps(char *outfile, int xspin[4], void *fit, int npnts, int complex);
int printDerivs(char *command, int npnts);

#endif /* _PRINTINFO_H */


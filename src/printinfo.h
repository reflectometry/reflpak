/* Generates output */

#ifndef _PRINTINFO_H
#define _PRINTINFO_H

int printLayers(char *command);
int listData(void);
int genReflect(char *command);
int genProfile(void);
int saveProfile(char *command);
int saveTemps(char *outfile);
int printDerivs(char *command);

#endif /* _PRINTINFO_H */


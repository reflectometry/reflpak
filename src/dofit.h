/* Fitting routine preparation and execution */

#ifndef _DOFIT_H
#define _DOFIT_H

int clearLista(int lista[]);
int varyParm(char *command);
int printChiSq(char *command);
double calcChiSq(int n, double *fit, double *data, double *error);
int fitReflec(char *command);

#endif /* _DOFIT_H */

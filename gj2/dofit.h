/* Fitting routine preparation and execution */

#ifndef _DOFIT_H
#define _DOFIT_H

int clearLista(int lista[]);
int varyParm(char *command);
int calcChiSq(char *command);
int fitReflec(char *command);
int calcExtend(int xspin[4]);
#if 0
int calcConvolve(char *polstat);
#endif

#endif /* _DOFIT_H */


/* Plots data with gnuplot */

#ifndef _PLOTIT_H
#define _PLOTIT_H

int plotfit(char *command, int xspin[4]);
int plotprofile(char *command, int xspin[4]);
int movie(char *command, int xspin[4], const char *frameFile);
int oneParmMovie(char *command, int xspin[4]);
int fitMovie(char *command, int xspin[4], double *preFit);
int arbitraryMovie(char *command, int xspin[4]);
void preFitFrame(char *command, FILE *gnuPipe, int xspin[4], double chisq);
void fitFrame(FILE *gnuPipe, int xspin[4], double chisq);


#endif /* _PLOTIT_H */


/* Plots data with gnuplot */

#ifndef _PLOTIT_H
#define _PLOTIT_H

int plotfit(char *command);
int plotprofile(char *command);
int movie(char *command, const char *frameFile);
int oneParmMovie(char *command);
int fitMovie(char *command, double *preFit);
int arbitraryMovie(char *command);
void preFitFrame(char *command, FILE *gnuPipe, int npnts, double chisq);
void fitFrame(FILE *gnuPipe, int npnts, double chisq);

#endif /* _PLOTIT_H */


/* Plots data with gnuplot */

#ifndef _GNUPLOT_H
#define _GNUPLOT_H

#include <stdio.h>

FILE *openGnufile(const char *xlabel, const char *ylabel);
void closeGnufile(FILE *gnufile);
int runGnufile(char *command);
void addLinePlot(FILE *gnufile, char *filename, char *axes, int nplots);
double addThickLabels(FILE *gnufile, char *tag, double y, double deep[],
   double thick, int nlayer);

#endif /* _GNUPLOT_H */


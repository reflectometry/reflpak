/* Plots data with gnuplot */

#include <sys/types.h>
#include <unistd.h>
#include <stdlib.h>
#include <gnuPlot.h>
#include <cparms.h>

/* Module variables */
static const char gnuBinary[] = "gnuplot";
static const char gnuFile[] = "mltmp.gnu";
static char gnuCommand[sizeof(gnuBinary) + 10 + 3 + 29 + (COMMANDLEN + 2) + sizeof(gnuFile)];
static unsigned short int plotNumber = 0;
static pid_t me = 0;

FILE *openGnufile(const char *xlabel, const char *ylabel)
{
   FILE *gnufile;

   gnufile = fopen(gnuFile, "w");
   if (gnufile != NULL) {
      if (xlabel != NULL) fprintf(gnufile, "set xlabel \"%s\"\n", xlabel);
      if (ylabel != NULL) fprintf(gnufile, "set ylabel \"%s\"\n", ylabel);
   }
   return gnufile;
}


void closeGnufile(FILE *gnufile)
{
   if (gnufile) {
      /* fputs("pause -1\n\n", gnufile); */
      fprintf(gnufile, "!rm -f %s\n", gnuFile);
      fclose(gnufile);
   }
}


int runGnufile(char *command)
{
   int retvalue;

   if (me == 0) me = getpid();
   plotNumber++;
   
   sprintf(gnuCommand, "%s -persist -title \"GJ2 %ld (%hd) %s\" %s", 
      gnuBinary, (long) me, plotNumber, command, gnuFile);
   retvalue = system(gnuCommand);

/*   sprintf(gnuCommand, "rm -f %s", gnuFile); */
/*   system(gnuCommand); */

   return retvalue;
}


void addLinePlot(FILE *gnufile, char *filename, char *axes, int nplots)
{
   #define defaultAxes ""

   if (axes == NULL) axes = defaultAxes;
   if (nplots > 0) fputs("re", gnufile);
   fprintf(gnufile, "plot \"%s\" %s w line\n", filename, axes);
}


double addThickLabels(FILE *gnufile, char *tag, double y, double d[],
   double thick, int nlayer)
{
   register int j;

   for (j = 1; j <= nlayer; j++) {
      thick += d[j] / 2;
      fprintf(gnufile, "set label \"%s%d\" at %f, graph %f center\n",
         tag, j, thick, y);
      thick += d[j] / 2;
   }
   return thick;
}


/* Plots data with gnuplot */

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <ctype.h>
#include <math.h>
#include <signal.h>
#include <sys/time.h>
#include <limits.h>
#include <string.h>
#include <linebuf.h>
#include <plotit.h>
#include <loadData.h>
#include <extres.h>
#include <gnuPlot.h>
#include <genlayers.h>
#include <ngenlayers.h>
#include <mgenlayers.h>
#include <gmagpro4.h>
#include <parseva.h>
#include <caps.h>
#include <badInput.h>
#include <setLayerParam.h>
#include <queryString.h>
#include <genderiv4.h>
#include <noFile.h>
#include <genva.h>
#include <stopMovie.h>
#include <dlconstrain.h>

#include <cdata.h>
#include <glayd.h>
#include <glayi.h>
#include <mglayd.h>
#include <glayim.h>
#include <nglayd.h>
#include <glayin.h>
#include <genpsc.h>
#include <genpsr.h>
#include <genpsi.h>
#include <genpsl.h>
#include <genpsd.h>

/* Local function prototypes */
#include <static.h>
#include "error.h"

#define LINEAR_DATA 1
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

STATIC char *dumpReflecData(char xsec, int npnts, int noff);
STATIC char *dumpReflecFit(char xsec, int noffx);
STATIC void dumpReflec(char xsec, int npnts, int noff, int noffx, int nplots,
   FILE *gnuFile);
STATIC void setPspin(int pspin[4], int xspin[4], char *command);
STATIC void dumpProfile(char xsec, int nglay, double gqcsq[], double gd[]);
STATIC char *dumpSDensity(char xsec);
STATIC long locateHeader(LINEBUF *data);
STATIC char *loadFieldPart(LINEBUF *data, char *field);
STATIC char *nextField(LINEBUF *data, char *field);
STATIC int loadFields(LINEBUF *data, char *field);
STATIC int frameRange(double *low, double *high, double orig);
STATIC void firstReflecFrame(FILE *gnuPipe, int xspin[4], int pspin[4]);
#if 0
STATIC int loadFrame(LINEBUF *data, int numFields);
STATIC int framePause(double delay, struct timeval *then);
STATIC void reflecFrame(FILE *gnuPipe, int xspin[4], int pspin[4]);
STATIC void firstProfileFrame(FILE *gnuPipe, int xspin[4], int pspin[4]);
STATIC void profileFrame(FILE *gnuPipe, int xspin[4], int pspin[4]);
STATIC void firstSDensityFrame(FILE *gnuPipe, int xspin[4], int pspin[4]);
STATIC void sDensityFrame(FILE *gnuPipe, int xspin[4], int pspin[4]);
#endif


/* Module variables */
static int pspin[4]; /* May request only some of the PS xsecs */
static int fields[NA];
static double orig[NA];

static const char movfile[] = "mltmp.mov";
static char profile[] = "mltmp.pr ";

static const char zlabel[] = "Z (Angstroms)";
static const char dlabel[] = "16*pi*rho (Angstroms**(-2))";
static const char tlabel[] = "Theta (degrees)";
static const char qlabel[] = "Q (inv. Angstroms)";
static const char rlabel[] = "Log10 Reflectivity";
static const char title[] = "set title \"%s = %#15.7G\"\n";

static const char threefloats[] = "%#15.7G%#15.7G%#15.7G\n";
#define twofloats (threefloats + 7)
#define onefloat (twofloats + 7)

static char fieldData[32];

STATIC char *dumpReflecData(char xsec, int npnts, int noff)
{
   static char datfile[] = "mltmp.da ";
   FILE *unit34;
   register int n;

   datfile[sizeof(datfile) - 2] = xsec;
   unit34 = fopen(datfile, "w");
   for (n = 0; n < npnts; n++)
      fprintf(
         unit34, threefloats,
         xdat[n + noff],
         ydat[n + noff],
         srvar[n + noff]
      );
   fclose(unit34);
   return datfile;
}


STATIC char *dumpReflecFit(char xsec, int noffx)
{
   static char fitfile[] = "mltmp.fi ";
   FILE *unit35;
   register int n;

   fitfile[sizeof(fitfile) - 2] = xsec;
   unit35 = fopen(fitfile, "w");
   for (n = 0; n < n4x; n++) {
      if (isnan(y4x[noffx + n]))
         fputs("\n#", unit35);
      fprintf(
         unit35, twofloats,
/*        q4x[nq[n]], y4x[noffx + nq[n]] */
        q4x[n], y4x[noffx + n]
      );
   }
   fclose(unit35);
   return fitfile;
}


STATIC void dumpReflec(char xsec, int npnts, int noff, int noffx, int nplots,
   FILE *gnuFile)
{
   if (nplots > 0) fputs("re", gnuFile);
   else fputs("set bar small\n", gnuFile);
   fprintf(
      gnuFile, "plot \"%s\" w line, "
                    "\"%s\" w errorbars\n",
      dumpReflecFit(xsec, noffx),
      dumpReflecData(xsec, npnts, noff)
   );
}


STATIC void setPspin(int pspin[4], int xspin[4], char *command)
{

   /* Determine reflectivities to print */
   pspin[0] = (*command == 0);
   pspin[1] = pspin[0];
   pspin[2] = pspin[0];
   pspin[3] = pspin[0];

   for (; *command != 0; command++)
      if (*command >= 'A' && *command <= 'D')
         pspin[(int) (*command) - 'A'] = TRUE;
}


int plotfit(char *command, int xspin[4])
{
   int failed;
   FILE *unit33;

   failed = loadData(infile, xspin);
   if (failed) {
      return failed;
   }

   if (extend(q4x, n4x, lambda, lamdel, thedel) == NULL) {
      failed = TRUE;
      return failed;
   }

   /* Open gnu file and load with plot commands */
   unit33 = openGnufile(qlabel, rlabel);

   /* Determine reflectivities to print */
   setPspin(pspin, xspin, command + 3);

   /* Calculate reflectivities and package for gnuplot */
   firstReflecFrame(unit33, xspin, pspin);

   /* Call plot subroutine */
   closeGnufile(unit33);
   runGnufile(command);

   return failed;
}


STATIC void dumpProfile(char xsec, int nglay, double gqcsq[], double gd[])
{
   register int n;
   register double thick;
   FILE *unit34;

   profile[sizeof(profile) - 2] = xsec;
   unit34 = fopen(profile, "w");
   thick = 0.;
   for (n = 0; n <= nglay; n++) {
      fprintf(unit34, twofloats, thick, gqcsq[n]);
      thick += gd[n];
      fprintf(unit34, twofloats, thick, gqcsq[n]);
   }
   fclose(unit34);
}


STATIC char *dumpSDensity(char xsec)
{
   register int n;
   register double thick, density;
   FILE *unit34;

   profile[sizeof(profile) - 2] = xsec;
   thick = 0.;
   unit34 = fopen(profile, "w");
   switch (xsec) {
      case 'a':
         for (n = 0; n <= nglay; n++) {
            density = gqcsq[n] + gqmsq[n] * sin(M_PI / 180. * gthe[n]);
            fprintf(unit34, twofloats, thick, density);
            thick += gd[n];
            fprintf(unit34, twofloats, thick, density);
         }
         break;
      case 'b':
      case 'c':
         for (n = 0; n <= nglay; n++) {
            density = gqmsq[n] * cos(M_PI / 180. * gthe[n]);
            fprintf(unit34, twofloats, thick, density);
            thick += gd[n];
            fprintf(unit34, twofloats, thick, density);
         }
         break;
      case 'd':
         for (n = 0; n <= nglay; n++) {
            density = gqcsq[n] - gqmsq[n] * sin(M_PI / 180. * gthe[n]);
            fprintf(unit34, twofloats, thick, density);
            thick += gd[n];
            fprintf(unit34, twofloats, thick, density);
         }
         break;
   }
   fclose(unit34);
   return profile;
}


int plotprofile(char *command, int xspin[4])
{
   int nplots = 0;
   FILE *unit33;

   /* Open gnu file and load with plot commands */
   unit33 = openGnufile(zlabel, dlabel);

   /* Generate nuclear, magnetic, or spin profiles */
   if (command[3] == 0 || command[3] == 'N') {
      /* Generate nuclear profile and place in plot array */
      ngenlayers(qcsq, d, rough, mu, nlayer, zint, rufint, nrough, proftyp);
      dumpProfile('n', nglayn, gqcnsq, gdn);
      addThickLabels(unit33, "N", .05, d, vacThick(rough, zint, nrough), nlayer);
      addLinePlot(unit33, profile, NULL, nplots++);
   }
   if (
      command[3] == 0 ||
      command[3] == 'M' ||
      command[3] == 'T'
   ) {
      char xsec;

      /* Generate magnetic profile and save in plot array */
      xsec = (command[3] == 0) ? 'm' : tolower(command[3]);
      mgenlayers(qcmsq, dm, mrough, the, nlayer, zint, rufint, nrough, proftyp);
      dumpProfile(xsec, nglaym, (xsec == 'm' ? gqcmsq : gthem), gdm);
      addThickLabels(unit33, "M", .10, dm, vacThick(mrough, zint, nrough), nlayer);
      addLinePlot(unit33, profile, NULL, nplots++);
   }
   if (command[3] == 'S' || (command[3] >= 'A' && command[3] <= 'D')) {
      int n;

      addThickLabels(unit33, "N", .05, d, vacThick(rough, zint, nrough), nlayer);
      addThickLabels(unit33, "M", .10, dm, vacThick(mrough, zint, nrough), nlayer);
      ngenlayers(qcsq, d, rough, mu, nlayer, zint, rufint, nrough, proftyp);
      mgenlayers(qcmsq, dm, mrough, the, nlayer, zint, rufint, nrough, proftyp);
      gmagpro4();
   /* Read in data */
      if (command[3] == 'S') {
         for (n = 0; n < 4; n++)
            if (xspin[n])
               addLinePlot(unit33, dumpSDensity((char) n + 'a'), NULL,
                  nplots++);
      } else {
         for (n = 3; command[n] >= 'A' && command[n] <= 'D'; n++)
            addLinePlot(unit33, dumpSDensity(tolower(command[n])), NULL,
               nplots++);
      }
   }
   closeGnufile(unit33);
   runGnufile(command);
   return FALSE;
}


STATIC long locateHeader(LINEBUF *data)
{
   long headerOffset = -1;

   /* Find last explicit comment line */
   rewindBuf(data);
   for (;
      getNextLine(data) != NULL && data->isComment;
      flushLine(data, NULL)
   ) {
      if (*(data->buffer) == data->commentChar)
         headerOffset = data->bufferOffset;
   }
   return headerOffset;
}


STATIC char *loadFieldPart(LINEBUF *data, char *field)
{
   while (field != NULL) {
      while (isspace(*field))
         field++;
      if (*field != 0)
         break;
      field = (data->fullLineRead ? NULL : getNextLine(data));
   }
   return field;
}


STATIC char *nextField(LINEBUF *data, char *field)
{
   char *fieldStart, *nameEnd, stopChar;

   nameEnd = fieldData;
   fieldData[0] = 0;

   /* Returns NULL when last field is read */
   /* Returns non-NULL and fieldData is null string if name too long */
   do {
      /* Find next non-white space char on line */
      field = loadFieldPart(data, field);
      if (field == NULL)
         break;

      /* Check if last field actually ended at end of data buffer */
      if (nameEnd != fieldData && field != data->buffer)
         break;

      fieldStart = field;
      /* Find end of non-white space chars */
      while(*field != 0 && !isspace(*field))
         field++;
      if ((field - fieldStart) + (nameEnd - fieldData) > sizeof(fieldData)) {
         /* Error: Name too big for string */
         fieldData[0] = 0;
         break;
      } else {
         /* Save stopping char to see if name continues past buffer end */
         stopChar = *field;
         *field = 0;
         strcpy(nameEnd, fieldStart);
         nameEnd += field - fieldStart;
         if (stopChar != 0)
            field++;
      }
   } while (stopChar == 0);

   return field;
}


STATIC int loadFields(LINEBUF *data, char *field)
{
   int numFields = 0, nc;

   for (
      field = nextField(data, field);
      field != NULL;
      field = nextField(data, field)
   ) {
      if (fieldData[0] == 0) {
         puts("/* Field name too large on header line */");
         numFields = -1;
         break;
      }
      if (numFields == NA) {
         numFields = -1;
         break;
      }
      nc = parseva(caps(fieldData));
      if (nc < 0 || nc >= NA) {
         badInput(fieldData);
         numFields = -1;
         break;
      } else
        fields[numFields++] = nc;
   }
   return numFields;
}


#if 0
STATIC int loadFrame(LINEBUF *data, int numFields)
{
   register int nc;
   char *field, *stopChar;

   nc = -1;

   for (field = getNextLine(data);
      field != NULL && data->isComment;
      field = getNextLine(data)
   ) flushLine(data, NULL);

   if (field != NULL) {
      nc = 0;
      for (
         field = nextField(data, field);
         field != NULL;
         field = nextField(data, field)
      ) {
         if (nc == numFields) {
            nc = 0;
            break;
         }
         A[fields[nc]] = strtod(fieldData, &stopChar);
         if (stopChar == fieldData ||
            (*stopChar != 0 && !isspace(*stopChar))) {
            nc = 0;
            break;
         }
         nc++;
      }
   }
   return nc;
}
#endif


STATIC int frameRange(double *low, double *high, double orig)
{
   int frames = 0;
   char *string;
   double dummyUnc;

   *low = orig;
   if (setLayerParam(low, &dummyUnc, "starting value"))
      /* Invalid response, use original value */
      *low = orig;

   *high = orig;
   if (setLayerParam(high, &dummyUnc, "ending value"))
      /* Invalid response, use original value */
      *high = orig;

   string = queryString("Number of frames: ", NULL, 0);
   if (string) sscanf(string, "%d", &frames);
   frames++;

   return frames;
}


#ifdef SGI
#define NAPTIME ((CLK_TCK >> 4) | 1)
#else
#define NAPTIME 20L
#endif
#if 0
/* Pause for the given portion of a second after the initial time "then".
   Return immediately if interrupted. */
STATIC int framePause(double delay, struct timeval *then)
{
   int retvalue = 0;
   struct timeval now;
   double delta;

   /* XXX FIXME XXX gettimeofday has resolution of 1 s. on some sysV */
   gettimeofday(&now, NULL);
   delta = (double) (now.tv_sec - then->tv_sec) +
           (double) (now.tv_usec - then->tv_usec) * 1.e-6;

   if (delta > delay)
      retvalue = 1;
   else {
#if defined(SGI)
      /* Note: on some systems usleep returns immediately after SIGINT
         is handled even if the full delay hasn't expired, but others
         do not, so we have to sleep for short intervals */
      while (delta < delay) {
         if (sginap(NAPTIME)) {
            retvalue = -1;
            break;
         }
         gettimeofday(&now, NULL);
         delta = (double) (now.tv_sec - then->tv_sec) +
                 (double) (now.tv_usec - then->tv_usec) * 1.e-6;
      }
#else
      usleep((unsigned long)(1e6*(delay-delta)));
#endif
   }

   return retvalue;
}
#endif


void preFitFrame(char *command, FILE *gnuPipe, int xspin[4], double chisq)
{
   /* Determine reflectivities to print */
   setPspin(pspin, xspin, command + 3);

#if LINEAR_DATA
   fputs("set logscale y\n", gnuPipe);
#endif
   fputs("set bar small\n", gnuPipe);
   fitFrame(gnuPipe, xspin, chisq);

   queryString("Wait for first frame, then press enter to commence fitting. ",
      NULL, 0);
}


void fitFrame(FILE *gnuPipe, int xspin[4], double chisq)
{
   int xsec, ntot, ntotx;

   ntot = 0;
   ntotx = 0;

   for (xsec = 0; xsec < 4; xsec++) {
      if (xspin[xsec]) {
         if (pspin[xsec]) {
            fprintf(gnuPipe, "set terminal x11 %d\n"
                             "set xlabel \"%s\"\n"
                             "set ylabel \"%s\"\n",
               xsec - (xsec == 2), qlabel, rlabel);
            fprintf(gnuPipe, title, "Chisq", chisq);
            /* Send spin data and reflectivity */
            dumpReflec((char) xsec + 'a', npntsx[xsec], ntot, ntotx,
               (xsec == 2 && pspin[1]), gnuPipe);
            fflush(gnuPipe);
         }
         ntot += npntsx[xsec];
         ntotx += n4x;
      }
   }
}


STATIC void firstReflecFrame(FILE *gnuPipe, int xspin[4], int pspin[4])
{
   int xsec, ntot, ntotx, nplots;

   ntot = 0;
   ntotx = 0;
   nplots = 0;
   genderiv4(q4x, y4x, n4x, 0);
#if LINEAR_DATA
   fputs("set logscale y\n",gnuPipe);
#endif
   for (xsec = 0; xsec < 4; xsec++) {
      if (xspin[xsec]) {
         if (pspin[xsec]) {
            /* Send spin data and reflectivity */
            dumpReflec((char) xsec + 'a', npntsx[xsec], ntot, ntotx, nplots++,
               gnuPipe);
         }
         ntot += npntsx[xsec];
         ntotx += n4x;
      }
   }
}


#if 0
STATIC void reflecFrame(FILE *gnuPipe, int xspin[4], int pspin[4])
{
   int xsec, ntotx;

   ntotx = 0;
   for (xsec = 0; xsec < 4; xsec++) {
      if (xspin[xsec]) {
         if (pspin[xsec]) {
            /* Send spin reflectivity */
            dumpReflecFit((char) xsec + 'a', ntotx);
         }
         ntotx += n4x;
      }
   }
}
#endif

#if 0
STATIC void firstProfileFrame(FILE *gnuPipe, int xspin[4], int pspin[4])
{
   ngenlayers(qcsq, d, rough, mu, nlayer, zint, rufint, nrough, proftyp);
   mgenlayers(qcmsq, dm, mrough, the, nlayer, zint, rufint, nrough, proftyp);

   addThickLabels(gnuPipe, "N", .05, d, vacThick(rough, zint, nrough), nlayer);
   addThickLabels(gnuPipe, "M", .10, dm, vacThick(mrough, zint, nrough), nlayer);
   fputs("set ytics nomirror; set y2tics\n", gnuPipe);
/*   fputs("set y2range [0:360]\n", gnuPipe); */

   dumpProfile('n', nglayn, gqcnsq, gdn);
   addLinePlot(gnuPipe, profile, "axes x1y1", 0);

   dumpProfile('m', nglaym, gqcmsq, gdm);
   addLinePlot(gnuPipe, profile, "axes x1y1", 1);

   dumpProfile('t', nglaym, gthem,  gdm);
   addLinePlot(gnuPipe, profile, "axes x1y2", 1);
}
#endif


#if 0
STATIC void profileFrame(FILE *gnuPipe, int xspin[4], int pspin[4])
{
   dumpProfile('n', nglayn, gqcnsq, gdn);
   dumpProfile('m', nglaym, gqcmsq, gdm);
   dumpProfile('t', nglaym, gthem,  gdm);
}
#endif


#if 0
STATIC void firstSDensityFrame(FILE *gnuPipe, int xspin[4], int pspin[4])
{
   register int xsec, nplots = 0;

   addThickLabels(gnuPipe, "N", .05, d, vacThick(rough, zint, nrough), nlayer);
   addThickLabels(gnuPipe, "M", .10, dm, vacThick(mrough, zint, nrough), nlayer);

   ngenlayers(qcsq, d, rough, mu, nlayer, zint, rufint, nrough, proftyp);
   mgenlayers(qcmsq, dm, mrough, the, nlayer, zint, rufint, nrough, proftyp);
   gmagpro4();

   for (xsec = 0; xsec < 4; xsec ++)
      if (pspin[xsec] && xspin[xsec])
         addLinePlot(gnuPipe, dumpSDensity((char) xsec + 'a'), NULL, nplots++);
}
#endif


#if 0
STATIC void sDensityFrame(FILE *gnuPipe, int xspin[4], int pspin[4])
{
   register int xsec;

   for (xsec = 0; xsec < 4; xsec ++)
      if (pspin[xsec] && xspin[xsec]) dumpSDensity((char) xsec + 'a');
}
#endif


STATIC int runMovie(int frames, int numFields, LINEBUF *frameData, FILE *gnuPipe, char *command)
{
#if 0
   register int j;
   int replay = TRUE, failed = FALSE, frame, nc;
   const char *xlabel, *ylabel;
   char *string;
   void (*oldhandler)(int);
   void (*nextFrame)(FILE *, int [4], int [4]);
   FILE *oldConsole;

   /* Steal the complex data space for our own devices */
   double *yinitx = (double *)(yfita);

   /* Save original values */
   for (j = 0; j < NA; j++)
     orig[j] = A[j];

   while (replay) {
      double *yvalues;

      frame = 0;
      rewindBuf(frameData);

      do {
         nc = loadFrame(frameData, numFields);
         frame++;
      } while (nc != -1 && nc != numFields);

      if (nc == -1) {
         /* No files matched field specification */
         printf("/** No frames found with %d variables **/\n", numFields);
         failed = TRUE;
         break;
      }

      if (numFields == 1)
         fprintf(gnuPipe, title, fitlist, A[fields[0]]);
      else
         fprintf(gnuPipe, "set title \"Frame %d of %d\"\n", frame, frames);

      /* Calculate reflectivities and package for gnuplot */
      (*Constrain)(FALSE, A, nlayer);

      switch (*command) {
         case 'P':
            xlabel = zlabel;
            ylabel = dlabel;
            firstProfileFrame(gnuPipe, xspin, pspin);
            nextFrame = profileFrame;
            break;
         case 'D':
         case 'I':
         case 'R':
            yvalues = y4x;
            xlabel = qlabel;
            ylabel = rlabel;
            firstReflecFrame(gnuPipe, xspin, pspin);
            nextFrame = reflecFrame;
            if (*command == 'D')
               memcpy(yinitx, y4x, sizeof(double) * n4x * ncross);
            if (*command == 'I')
               yvalues = yinitx;
            break;
         default:
         case 'S':
            xlabel = zlabel;
            ylabel = dlabel;
            firstSDensityFrame(gnuPipe, xspin, pspin);
            nextFrame = sDensityFrame;
            break;

      }
      string = queryString("Specify an optional y range in format ymin:ymax ",
         NULL, 0); 
      if (string != NULL) fprintf(gnuPipe, "set yrange [%s]\n", string);
      if (nextFrame == profileFrame) {
         string = queryString("Specify an optional theta range in format ymin:ymax ",
            NULL, 0); 
         if (string != NULL) fprintf(gnuPipe, "set y2range [%s]\n", string);
      }
      fprintf(gnuPipe, "set xlabel \"%s\"\n", xlabel);
      fprintf(gnuPipe, "set ylabel \"%s\"\n", ylabel);
      fputs("replot\n", gnuPipe);
      fflush(gnuPipe);

#ifndef DEBUGMALLOC
      oldhandler = signal(SIGINT, stopMovie);
#endif
      abortMovie = FALSE;
      queryString("Wait for first frame, then press enter to start movie. ",
         NULL, 0);

      while (!abortMovie) {
         struct timeval now;

         gettimeofday(&now, NULL);
         do {
            nc = loadFrame(frameData, numFields);
            frame++;
         } while (nc != -1 && nc != numFields);

         if (nc == -1)
            /* No more frames */
            break;
 
         (*Constrain)(FALSE, A, nlayer);
         if (nextFrame == reflecFrame) {
            genderiv4(q4x, yvalues, n4x, 0);
            if (*command == 'D') {
               register int n;

               for (n = 0; n < n4x * ncross; n++)
#ifdef LINEAR_DATA
                  y4x[n] /= yinitx[n];
#else
                  y4x[n] -= yinitx[n];
#endif
            } else if (*command == 'I') {
               register int n;

               for (n = 0; n < n4x * ncross; n++)
#ifdef LINEAR_DATA
                  y4x[n] = yinitx[n] / y4x[n];
#else
                  y4x[n] = yinitx[n] - y4x[n];
#endif
            }
         } else {
            ngenlayers(qcsq, d, rough, mu, nlayer, zint, rufint, nrough,
               proftyp);
            mgenlayers(qcmsq, dm, mrough, the, nlayer, zint, rufint, nrough,
               proftyp);
            gmagpro4();
         }
         framePause(0.125, &now);
         (*nextFrame)(gnuPipe, xspin, pspin);
         if (numFields == 1)
            fprintf(gnuPipe, title, fitlist, A[fields[0]]);
         else
            fprintf(gnuPipe, "set title \"Frame %d of %d\"\n", frame, frames);

         fputs("replot\n", gnuPipe);
         fflush(gnuPipe);

         if (*command == 'I')
            memcpy(y4x, yinitx, sizeof(double) * n4x * ncross);
      }
      if (abortMovie) puts("Stopping the movie.");

#ifndef DEBUGMALLOC
      /* Restore signal handlers */
      signal(SIGINT, oldhandler);
#endif

      string = queryString("Input \"R\" to replay. ", NULL, 0);
      if (!string || (*string != 'r' && *string != 'R')) replay = FALSE;
   }
   fputs("quit\n", gnuPipe);

   /* Restore original values */
   for (j = 0; j < NA; j++)
     A[j] = orig[j];

   /* (*Constrain)(FALSE, A, nlayer); */
   return failed;
#else
   return 0;
#endif
}


int movie(char *command, int xspin[4], const char *frameFile)
{
   int failed = TRUE;
   LINEBUF frameData[1];
   static const char noDataMsg[] = "/** Data file does not define any fields **/";

   /* Determine reflectivities to print */
   setPspin(pspin, xspin, command + 1);

   if ((*command == 'R' || *command == 'D' || *command == 'I') && (
         loadData(infile, xspin) ||
         extend(q4x, n4x, lambda, lamdel, thedel) == NULL
      )
   ) return TRUE;

   if (openBuf(frameFile, "r", frameData, FBUFFLEN) == NULL)
      noFile(frameFile);
   else {
      int frames;
      long headerOffset;

      frames = countData(frameData);
      headerOffset = locateHeader(frameData);
      if (headerOffset == -1)
         puts(noDataMsg);
      else {
         int numFields;

         setNextLine(frameData, headerOffset);
         getNextLine(frameData);
         numFields = loadFields(frameData, frameData->buffer + 1);
         if (numFields == 0)
            puts(noDataMsg);
         else if (numFields > 0) {
            FILE *gnuPipe;

            genva(fields, 1, fitlist);
            gnuPipe = popen("gnuplot", "w");
            if (gnuPipe != NULL) {
               failed = runMovie(frames, numFields, frameData, gnuPipe, command);
               pclose(gnuPipe);
            }
         }
      }
      closeBuf(frameData, 0);
   }
   return failed;
}


int oneParmMovie(char *command, int xspin[4])
{
   int failed = FALSE;
   int nc = -1, frames, j;
   double low, high, step;
   char *string;
   FILE *moviefile;

   string = queryString("Parameter to watch: ", NULL, 0);
   if (string) nc = parseva(caps(string)); 
   if (nc < 0 || nc >= NA) {
      ERROR("/** Invalid fit parameter number: %s **/\n", string);
      failed = TRUE;
      return failed;
   }
   /* Valid parameter number */
   moviefile = fopen(movfile, "w");

   frames = frameRange(&low, &high, A[nc]);
   step = (frames == 1) ? 0 : (high - low) / (double) (frames - 1);

   genva(&nc, 1, fitlist);
   fprintf(moviefile, "#%s\n", fitlist);

   for (j = 0; j < frames; j++) {
      fprintf(moviefile, "%15.6G\n", low);
      low += step;
   }
   fclose(moviefile);

   return movie(command + 2, xspin, movfile);
}


int fitMovie(char *command, int xspin[4], double preFit[NA])
{
   char *string;
   int frames = 0, numFields = 0;
   register int j, nc;
   FILE *moviefile;

   moviefile = fopen(movfile, "w");
   string = queryString("Number of frames: ", NULL, 0);
   if (string) sscanf(string, "%d", &frames);

   /* Find parameters which changed */
   for (j = 0; j < NA; j++) {
      if (A[j] != preFit[j])
         fields[numFields++] = j;
   }

   /* List parameters that changed in header */
   fputc('#', moviefile);
   for (j = 0; j < numFields; j++) {
      nc = fields[j];
      orig[nc] = preFit[nc];
      genva(fields + j, 1, fitlist);
      fprintf(moviefile, " %s", fitlist);
   }
   fputc('\n', moviefile);

   /* Print parameters before fit */
   for (j = 0; j < numFields; j++)
      fprintf(moviefile, "%15.6G", orig[fields[j]]);
   fputc('\n', moviefile);

   /* Print remaining frames */
   while(frames > 0) {
      for (j = 0; j < numFields; j++) {
         nc = fields[j];
         orig[nc] += (A[nc] - orig[nc]) / (double) frames;
         fprintf(moviefile, "%15.6G", orig[nc]);
      }
      fputc('\n', moviefile);
      frames--;
   }
   fclose(moviefile);

   return movie(command + 3, xspin, movfile);
}


int arbitraryMovie(char *command, int xspin[4])
{
   char *string;

   string = queryString("File to play: ", NULL, 0);
   return (string ? movie(command + 3, xspin, string) : TRUE);
}


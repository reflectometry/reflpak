/* Plots data with gnuplot */

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/time.h>
#include <string.h>
#include <ctype.h>
#include <signal.h>
#include <math.h>

#include <linebuf.h>
#include <plotit.h>
#include <gnuPlot.h>
#include <loadData.h>
#include <extres.h>
#include <parseva.h>
#include <caps.h>
#include <badInput.h>
#include <setLayerParam.h>
#include <queryString.h>
#include <genderiv.h>
#include <genvac.h>
#include <genmulti.h>
#include <stopMovie.h>
#include <noFile.h>
#include <genva.h>
#include <dlconstrain.h>

#include <parameters.h>
#include <cparms.h>
#include <cdata.h>
#include <glayd.h>
#include <glayi.h>
#include <genmem.h>
#include <genpsl.h>
#include <genpsc.h>
#include <genpsr.h>
#include <genpsi.h>
#include <genpsd.h>

/* Local function prototypes */
#include <static.h>
#include "error.h"

STATIC long locateHeader(LINEBUF *data);
STATIC char *loadFieldPart(LINEBUF *data, char *field);
STATIC char *nextField(LINEBUF *data, char *field);
STATIC int loadFields(LINEBUF *data, char *field);
STATIC int loadFrame(LINEBUF *data, int numFields);
STATIC int frameRange(double *low, double *high, double orig);
#if 0
STATIC int framePause(double delay, struct timeval *then);
#endif
STATIC void firstReflecFrame(FILE *gnuPipe, int npnts);
STATIC void reflecFrame(FILE *gnuPipe, int npnts);
STATIC void firstProfileFrame(FILE *gnuPipe, int npnts);
STATIC void profileFrame(FILE *gnuPipe, int npnts);
STATIC int runMovie(int npnts, int frames, int numFields, LINEBUF *frameData,
   FILE *gnuPipe, char *command);


/* Module variables */
static int fields[NA];
static double orig[NA];

static const char zlabel[] = "z (Angstroms)";
static const char dlabel[] = "16*pi*rho (Angstroms**(-2))";
static const char qlabel[] = "Q (inv. Angstroms)";
static const char rlabel[] = "Log10 Reflectivity";
static const char title[] = "set title \"%s = %#15.7G\"\n";

static const char fitfile[] = "mltmp.fit";
static const char profile[] = "mltmp.pro";
static const char movfile[] = "mltmp.mov";

static char fieldData[32];


int plotfit(char *command)
{
   int failed = FALSE;
   FILE *gnufile;
   double qstep;
   register int j;

   gnufile = openGnufile(qlabel, rlabel);

   if (command[3] == 'D') {
      /* Plot just the raw data without fit */
      fprintf(gnufile, "plot \"%s\" w errorbars\n", infile);
   }
   else {
      /* Plot both data and fit */

      /* First: Calculate reflectivity at equally spaced points. */
      loadData(infile);
      if (npnts < 0) {
         fclose(gnufile);
         failed = TRUE;
         return failed;
      }

      qstep = (qmax - qmin) / (double) (npnts - 1);
      for (j = 0; j < npnts; j++)
         xtemp[j] = (double) j * qstep + qmin;

      if (extend(xtemp, npnts, lambda, lamdel, thedel) == NULL) {
         fclose(gnufile);
         failed = TRUE;
         return failed;
      }

      reflec = TRUE;
      firstReflecFrame(gnufile, npnts);
   }

   closeGnufile(gnufile);
   runGnufile(command);

   return FALSE;
}


int plotprofile(char *command)
{
   FILE *gnufile;

   /* Open gnu file and load with plot commands */
   gnufile = openGnufile(zlabel, dlabel);
   firstProfileFrame(gnufile, 0);
   closeGnufile(gnufile);
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


void preFitFrame(char *command, FILE *gnuPipe, int npnts, double chisq)
{
   fprintf(gnuPipe, "set logscale y\n"
	            "set bar small\n"
                    "set xlabel \"%s\"\n"
                    "set ylabel \"%s\"\n"
                    "plot \"%s\" w errorbars, \"%s\" w line\n",
                    qlabel, rlabel, infile, fitfile);
   fitFrame(gnuPipe, npnts, chisq);

   queryString("Wait for first frame, then press enter to commence fitting. ",
      NULL, 0);
}


void fitFrame(FILE *gnuPipe, int npnts, double chisq)
{
   register int j;
   FILE *tempfile;

   /* Send spin data and reflectivity */
   tempfile = fopen(fitfile, "w");
   for (j = 0; j < npnts; j++)
      fprintf(tempfile, "%#G %#G\n", xdat[j], ymod[j]);
   fclose(tempfile);

   fprintf(gnuPipe, "set title \"Chisq = %#15.7G\";replot\n", chisq);
   fflush(gnuPipe);
}


STATIC void firstReflecFrame(FILE *gnuPipe, int npnts)
{
   fprintf(gnuPipe, "set logscale y\n"
	            "set bar small\n"
                    "plot \"%s\" w errorbars, \"%s\" w line\n",
      infile, fitfile);
   genderiv(xtemp, yfit, npnts, 0);
   reflecFrame(gnuPipe, npnts);
}


STATIC void reflecFrame(FILE *gnuPipe, int npnts)
{
   register int j;
   FILE *tempfile;

   tempfile = fopen(fitfile, "w");
   /* XXX FIXME XXX don't want to abort program */
   if (tempfile == NULL) {
     perror(fitfile);
     exit(1);
   }
   for (j = 0; j < npnts; j++) {
      if (isnan(yfit[j]))
         fputs("\n#", tempfile);
      fprintf(tempfile, "%#G %#G\n", xtemp[j], yfit[j]);
   }
   fclose(tempfile);
}


STATIC void firstProfileFrame(FILE *gnuPipe, int npnts)
{
   double thick, slthick;

   profileFrame(gnuPipe, npnts);
   thick = vacThick(trough, zint, nrough);
   thick = addThickLabels(gnuPipe,"T", .05, td, thick, ntlayer);
   slthick = addThickLabels(gnuPipe,"M", .05, md, thick, nmlayer) - thick;
   thick += slthick * nrepeat;
   addThickLabels(gnuPipe,"B", .05, bd, thick, nblayer);
   fprintf(gnuPipe, "plot \"%s\" w line\n", profile);
}


STATIC void profileFrame(FILE *gnuPipe, int npnts)
{
   register int j;
   register double thick;
   FILE *tempfile;

   /* Generate profile */
   genmulti(tqcsq, mqcsq, bqcsq, tqcmsq, mqcmsq, bqcmsq,
            td, md, bd,
            trough, mrough, brough, tmu, mmu, bmu,
            nrough, ntlayer, nmlayer, nblayer, nrepeat, proftyp);

   tempfile = fopen(profile, "w");
   thick = 0.;
   for (j = 0; j <= nglay; j++) {
      fprintf(tempfile, "%#G %#G\n%#G %#G\n", thick, gqcsq[j],
         thick + gd[j], gqcsq[j]);
      thick += gd[j];
   }
   fclose(tempfile);
}


STATIC int runMovie(int npnts, int frames, int numFields, LINEBUF *frameData, FILE *gnuPipe, char *command)
{
#if 0
   register int j;
   int replay = TRUE, failed = FALSE, frame, nc;
   const char *xlabel, *ylabel;
   char *string;
   void (*oldhandler)(int);
   void (*nextFrame)(FILE *, int);

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
         ERROR("/** No frames found with %d variables **/\n", numFields);
         failed = TRUE;
         break;
      }

      if (numFields == 1)
         fprintf(gnuPipe, title, fitlist, A[fields[0]]);
      else
         fprintf(gnuPipe, "set title \"Frame %d of %d\"\n", frame, frames);

      /* Calculate reflectivities and package for gnuplot */
      (*Constrain)(FALSE, A, ntlayer, nmlayer, nrepeat, nblayer);

      switch (*command) {
         default:
         case 'P':
            xlabel = zlabel;
            ylabel = dlabel;
            firstProfileFrame(gnuPipe, 0);
            nextFrame = profileFrame;
            break;
         case 'D':
         case 'I':
         case 'R':
            yvalues = yfit;
            xlabel = qlabel;
            ylabel = rlabel;
            firstReflecFrame(gnuPipe, npnts);
            nextFrame = reflecFrame;
            if (*command == 'D')
               memcpy(ytemp, yfit, sizeof(double) * npnts);
            if (*command == 'I')
               yvalues = ytemp;
            break;

      }
      string = queryString("Specify an optional y range in format ymin:ymax ",
         NULL, 0);
      if (string != NULL) fprintf(gnuPipe, "set yrange [%s]\n", string);
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

         (*Constrain)(FALSE, A, ntlayer, nmlayer, nrepeat, nblayer);
         if (nextFrame == reflecFrame) {
            genderiv(xtemp, yvalues, npnts, 0);
            if (*command == 'D') {
               register int n;

               for (n = 0; n < npnts; n++)
                  yfit[n] /= ytemp[n];
            } else if (*command == 'I') {
               register int n;

               for (n = 0; n < npnts; n++)
                  yfit[n] = ytemp[n] / yfit[n];
            }
         }
         framePause(0.125, &now);
         (*nextFrame)(gnuPipe, npnts);
         if (numFields == 1)
            fprintf(gnuPipe, title, fitlist, A[fields[0]]);
         else
            fprintf(gnuPipe, "set title \"Frame %d of %d\"\n", frame, frames);

         fputs("replot\n", gnuPipe);
         fflush(gnuPipe);

         if (*command == 'I')
            memcpy(yfit, ytemp, sizeof(double) * npnts);
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

   /* (*Constrain)(FALSE, A, ntlayer, nmlayer, nrepeat, nblayer); */
   return failed;
#else
   return 0;
#endif
}


int movie(char *command, const char *frameFile)
{
   int failed = TRUE;
   double step;
   LINEBUF frameData[1];
   register int j;
   static const char noDataMsg[] = "/** Data file does not define any fields **/";

   if (*command == 'R' || *command == 'D' || *command == 'I') {
      loadData(infile);
      if (npnts < 1) return TRUE;

      step = (qmax - qmin) / (double) (npnts - 1);
      for (j = 0; j < npnts; j++)
         xtemp[j] = (double) j * step + qmin;

      if (extend(xtemp, npnts, lambda, lamdel, thedel) == NULL)
         return TRUE;
   }
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
         numFields = loadFields(frameData, frameData->buffer+1);
         if (numFields == 0)
            puts(noDataMsg);
         else if (numFields > 0) {
            FILE *gnuPipe;

            genva(fields, 1, fitlist);
            gnuPipe = popen("gnuplot", "w");
            if (gnuPipe != NULL) {
               failed = runMovie(npnts, frames, numFields, frameData, gnuPipe, command);
               pclose(gnuPipe);
            }
         }
      }
      closeBuf(frameData, 0);
   }
   return failed;
}


int oneParmMovie(char *command)
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

   return movie(command + 2, movfile);
}


int fitMovie(char *command, double preFit[NA])
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

   return movie(command + 3, movfile);
}


int arbitraryMovie(char *command)
{
   char *string;

   string = queryString("File to play: ", NULL, 0);
   return (string ? movie(command + 3, string) : TRUE);
}


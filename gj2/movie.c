#include <stdlib.h>
#include <stdio.h>
#include <signal.h>
#include <sys/time.h>
#include <ctype.h>
#include <linebuf.h>
#include <parseva.h>
#include <caps.h>
#include <badInput.h>
#include <noFile.h>
#include <genva.h>
#include <loadData.h>
#include <extres.h>
#include <queryString.h>
#include <genderiv4.h>
#include <ngenlayers.h>
#include <mgenlayers.h>
#include <gmagpro4.h>

#include <cparms.h>
#include <parameters.h>
#include <cdata.h>
#include <genpsr.h>
#include <genpsc.h>
#include <genpsi.h>
#include <genpsd.h>

/* Local function prototypes */
#include <static.h>

STATIC long locateHeader(LINEBUF *data);
STATIC char *loadFieldPart(LINEBUF *data, char *field);
STATIC char *nextField(LINEBUF *data, char *field);
STATIC int loadFields(LINEBUF *data, char *field);


/* Module variables */
static int fields[NA];
static double orig[NA];
static char fieldData[32];
static const char movieFile[] = "mltmp.mov";


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
      if (*field == 0)
         field = (data->fullLineRead) ? NULL : getNextLine(data);
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
         strcpy(nameEnd, field);
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
      if (nc < 0 && nc >= NA) {
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


#define NAPTIME ((CLK_TCK >> 4) | 1)

STATIC int framePause(double delay, struct timeval *then)
{
   int retvalue = 0;
   struct timeval now;
   double delta;

   gettimeofday(&now);
   delta = (double) (now.tv_sec - then->tv_sec) +
           (double) (now.tv_usec - then->tv_usec) * 1.e-6;

   if (delta > delay)
      retvalue = 1;
   else 
      while (delta < delay) {
         if (sginap(NAPTIME)) {
            retvalue = -1;
            break;
         }
         gettimeofday(&now);
         delta = (double) (now.tv_sec - then->tv_sec) +
                 (double) (now.tv_usec - then->tv_usec) * 1.e-6;
      }

   return retvalue;
}


STATIC void firstReflecFrame(FILE *gnuPipe, int xspin[4], int pspin[4])
{
   int xsec, ntot, ntotx, nplots;

   ntot = 0;
   ntotx = 0;
   nplots = 0;
   genderiv4(q4x, y4x, n4x, 0);
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


STATIC void profileFrame(FILE *gnuPipe, int xspin[4], int pspin[4])
{
   dumpProfile('n', nglayn, gqcnsq, gdn);
   dumpProfile('m', nglaym, gqcmsq, gdm);
   dumpProfile('t', nglaym, gthem,  gdm);
}


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


STATIC void sDensityFrame(FILE *gnuPipe, int xspin[4], int pspin[4])
{
   register int xsec;

   for (xsec = 0; xsec < 4; xsec ++)
      if (pspin[xsec] && xspin[xsec]) dumpSDensity((char) xsec + 'a');
}




int movie(char *command, int xspin[4], char *frameFile)
{
   int frames, nc, numFields;
   int failed = FALSE;
   int replay = TRUE;
   FILE *gnuPipe;
   LINEBUF frameData[1];
   long headerOffset;
   register int j;
   char *string;
   static const char noDataMsg[] = "/** Data file does not define fields **/";

   /* Determine reflectivities to print */
   setPspin(pspin, xspin, command + 1);

   if (openBuf(frameFile, "r", frameData, FBUFFLEN) == NULL) {
      noFile(frameFile);
      failed = TRUE;
      return failed;
   }

   frames = countData(frameData);
   headerOffset = locateHeader(frameData);
   if (headerOffset == -1) {
      puts(noDataMsg);
      closeBuf(frameData, 0);
      failed = TRUE;
      return failed;
   }

   setNextLine(frameData, headerOffset);
   numFields = loadFields(frameData, frameData->buffer+1);
   if (numFields < 1) {
      if (numFields == 0)
         puts(noDataMsg);
      failed = TRUE;
      return failed;
   }
   genva(fields, 1, fitlist);

   if (*command == 'R' || *command == 'D') {
      failed = loadData(infile, xspin);
      if (failed) {
         return failed;
      }
      if (extend(q4x, n4x, lambda, lamdel, thedel) == NULL) {
         failed = TRUE;
         return failed;
      }
   }

   gnuPipe = popen("gnuplot", "w");
   if (gnuPipe == NULL) {
      failed = TRUE;
      return failed;
   }

   /* Save original values */
   for (j = 0; j < NA; j++)
     orig[j] = A[j];

   while (replay) {
      void (*oldhandler)(void);
      void (*nextFrame)(FILE *, int [4], int [4]);
      const char *xlabel, *ylabel;
      /* Steal the complex data space for our own devices */
      double *yinitx = (double *)(yfita);
      int frame;

      string = queryString("Specify an optional y range in format ymin:ymax ",
         NULL, 0); 
      if (string != NULL) fprintf(gnuPipe, "set yrange [%s]\n", string);

      frame = 0;
      rewindBuf(frameData);

      do {
         nc = loadFrame(frameData, numFields);
         frame++;
      } while (nc != -1 && nc != numFields);

      if (nc == -1) {
         /* No files matched field specification */
         printf("/** No frames found with %d variables **/\n", frames);
         failed = TRUE;
         break;
      }

      if (numFields == 1)
         fprintf(gnuPipe, "set title \"%s = %15.6f\"\n", fitlist, A[fields[0]]);
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
         case 'R':
            xlabel = qlabel;
            ylabel = rlabel;
            firstReflecFrame(gnuPipe, xspin, pspin);
            nextFrame = reflecFrame;
            if (*command == 'D')
               memcpy(yinitx, y4x, sizeof(double) * n4x * ncross);
            break;
         default:
         case 'S':
            xlabel = zlabel;
            ylabel = dlabel;
            firstSDensityFrame(gnuPipe, xspin, pspin);
            nextFrame = sDensityFrame;
            break;

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

         do {
            nc = loadFrame(frameData, numFields);
            frame++;
         } while (nc != -1 && nc != numFields);

         if (nc == -1)
            /* No more frames */
            break;
 
         gettimeofday(&now);
         (*Constrain)(FALSE, A, nlayer);
         if (nextFrame == reflecFrame) {
            genderiv4(q4x, y4x, n4x, 0);
            if (*command == 'D') {
               register int n;

               for (n = 0; n < n4x * ncross; n++)
                  y4x[n] -= yinitx[n];
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
            fprintf(gnuPipe, "set title \"%s = %15.6f\"\n", fitlist, A[fields[0]]);
         else
            fprintf(gnuPipe, "set title \"Frame %d of %d\"\n", frame, frames);

         fputs("replot\n", gnuPipe);
         fflush(gnuPipe);
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
   pclose(gnuPipe);

   /* Restore original values */
   for (j = 0; j < NA; j++)
     A[j] = orig[j];

   /* (*Constrain)(FALSE, A, nlayer); */
   closeBuf(frameData, 0);

   return failed;
}


int oneParmMovie(char *command, int xspin[4])
{
   int failed = FALSE;
   int nc = -1, frames, j;
   double low, high, step;
   char *string;
   FILE *movfile;

   string = queryString("Parameter to watch: ", NULL, 0);
   if (string) nc = parseva(caps(string)); 
   if (nc < 0 || nc >= NA) {
      printf("/** Invalid fit parameter number: %s **/\n", string);
      failed = TRUE;
      return failed;
   }
   /* Valid parameter number */
   movfile = fopen(movieFile, "w");

   frames = frameRange(&low, &high, orig);
   step = (frames == 1) ? 0 : (high - low) / (double) (frames - 1);

   genva(&nc, 1, fitlist);
   fprintf(movfile, "#%s\n", fitlist);

   for (j = 0; j < frames; j++) {
      fprintf(movfile, "%15.6G\n", low);
      low += step;
   }
   fclose(movfile);

   return movie(command + 2, xspin, movieFile);
}


int fitInterpMovie(char *command, int xspin[4], double preFit[NA])
{
   char *string;
   int frames = 0, numFields = 0;
   register int j, nc;
   FILE *movfile;

   movfile = fopen(movieFile, "w");
   string = queryString("Number of frames: ", NULL, 0);
   if (string) sscanf(string, "%d", &frames);

   /* Find parameters which changed */
   for (j = 0; j < NA; j++) {
      if (orig[j] != preFit[j])
         fields[numFields++] = j;
   }

   /* List parameters that changed in header */
   fputc('#', movfile);
   for (j = 0; j < numFields; j++) {
      nc = fields[j];
      orig[nc] = preFit[nc];
      genva(fields + j, 1, fitlist);
      fprintf(movfile, " %s", fitlist);
   }
   fputc('\n', movfile);

   /* Print parameters before fit */
   for (j = 0; j < numFields; j++)
      fprintf(movfile, "%15.6G", orig[fields[j]]);
   fputc('\n', movfile);

   /* Print remaining frames */
   while(frames > 0) {
      for (j = 0; j < numFields; j++) {
         nc = fields[j];
         orig[nc] += (A[nc] - orig[nc]) / (double) frames;
         fprintf(movfile, "%15.6G", orig[nc]);
      }
      fputc('\n', movfile);
      frames--;
   }
   fclose(movfile);

   return movie(command + 3, xspin, movieFile);
}


int arbitraryMovie(char *command, int xspin[4])
{
   char *string;

   string = queryString("File to play: ", NULL, 0);

   return (string ? movie(command + 3, xspin, string) : TRUE);
}
------------------------------

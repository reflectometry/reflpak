/* Subroutine retrieves and stores parameters from and to disk */

#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <parms.h>
#include <generf.h>
#include <gentanh.h>

#include <parameters.h>
#include <cparms.h>
#include <genpsr.h>

/* Local function prototypes */
#include <static.h>
#include "error.h"
#include "genpsc.h"
#include "cleanFree.h"

STATIC void parmFileError(char *parfile, int line);
STATIC int loadFilename(FILE *file, char *filename, int namelength);


/* Module variables */
static char filebuf[FBUFFLEN + 1];

int parms(double *qcsq, double *qcmsq, double *d, double *dm, double *rough,
   double *mrough, double *mu, double *the, int maxlay,
   double *lambda, double *lamdel, double *thedel, int *nlayer,
   double *qmina, double *qmaxa, int *npntsa,
   double *qminb, double *qmaxb, int *npntsb,
   double *qminc, double *qmaxc, int *npntsc,
   double *qmind, double *qmaxd, int *npntsd,
   char *infile, char *outfile, double *bmintns, double *bki,
   int lista[], int *mfit, int na, int *nrough, char *proftyp,
   char *polstat, double *unc, char *scriptfile, char *parfile, int store)
/* double qcsq[MAXLAY], qcmsq[MAXLAY], d[MAXLAY], dm[MAXLAY]; */
/* double rough[MAXLAY], mrough[MAXLAY], mu[MAXLAY]; */
/* double the[MAXLAY]; */
/* char infile[INFILELEN], outfile[OUTFILELEN], proftyp[PROFTYPLEN]; */
/* char polstat[POLSTATLEN], parfile[PARFILELEN]; */
/* int lista[MFIT]; */
{
   int i, line, retValue = 0;
   FILE *unit1;

   static const char *writefourfloats = "%#15.6G%#15.6G%#15.6G%#15.6G\n";
   #define WRITEFLOATLENGTH 7
   #define writethreefloats (writefourfloats + WRITEFLOATLENGTH)
   #define writetwofloats (writethreefloats + WRITEFLOATLENGTH)
   #define writeonefloat (writetwofloats + WRITEFLOATLENGTH)
   static const char *writeTwoFloatsOneInt = "%#15.6G%#15.6G%15d\n";

   static const char *readfourfloats = "%lf %lf %lf %lf";
   #define READFLOATLENGTH 4
   #define readthreefloats (readfourfloats + READFLOATLENGTH)
   #define readtwofloats (readthreefloats + READFLOATLENGTH)
   #define readonefloat (readtwofloats + READFLOATLENGTH)
   static const char *readTwoFloatsOneInt = "%lf %lf %d";

   if (store) {
      unit1 = fopen (parfile, "w");
      fprintf(unit1, writethreefloats, *lambda, *lamdel, *thedel);
      fprintf(unit1, writetwofloats, *bmintns, *bki);
      fprintf(unit1, "%13d%13d%13d\n", *nlayer, *nrough, *mfit);
      fprintf(unit1, writeTwoFloatsOneInt, *qmina, *qmaxa, *npntsa);
      fprintf(unit1, writeTwoFloatsOneInt, *qminb, *qmaxb, *npntsb);
      fprintf(unit1, writeTwoFloatsOneInt, *qminc, *qmaxc, *npntsc);
      fprintf(unit1, writeTwoFloatsOneInt, *qmind, *qmaxd, *npntsd);
      fputs(proftyp, unit1);
      fputs("\n ", unit1);
      fputs(polstat, unit1);
      fputc('\n', unit1);
      fputs(infile, unit1);
      fputc('\n', unit1);
      fputs(outfile, unit1);
      fputc('\n', unit1);

      for (i = 0; i <= *nlayer; i++) {
         fprintf(unit1, writefourfloats, qcsq[i], d[i], rough[i], mu[i]);
         fprintf(unit1, writethreefloats, qcmsq[i], dm[i], mrough[i]);
         fprintf(unit1, writeonefloat, the[i]);
      }
      for (i = 0; i < *mfit; i++)
         fprintf(unit1, "%4d", lista[i]);
      fputc('\n', unit1);
      if (ConstraintScript != NULL)
	fwrite(ConstraintScript, strlen(ConstraintScript), 1, unit1);
      fclose(unit1);
   } else {
      line = 0;
      unit1 = fopen(parfile, "r");
      if (unit1 == NULL) {
         puts("/** Unable to open parameter file **/");
         strcpy(polstat, "a");
         infile[0] = 0;
         outfile[0] = 0;
         strcpy(proftyp, "E");
         return NOPARMFILE;
      } else line++;
      fgets(filebuf, FBUFFLEN, unit1);
      if (sscanf(filebuf, readthreefloats, lambda, lamdel, thedel) != 3) {
         parmFileError(parfile, line);
         return BADPARMDATA;
      } else line++;
      fgets(filebuf, FBUFFLEN, unit1);
      if (sscanf(filebuf, readtwofloats, bmintns, bki) != 2) {
         parmFileError(parfile, line);
         return BADPARMDATA;
      } else line++;
      fgets(filebuf, FBUFFLEN, unit1);
      if (sscanf(filebuf, "%13d%13d%13d\n", nlayer, nrough, mfit) != 3) {
         parmFileError(parfile, line);
         return BADPARMDATA;
      } else line++;
      fgets(filebuf, FBUFFLEN, unit1);
      if (sscanf(filebuf, readTwoFloatsOneInt, qmina, qmaxa, npntsa) != 3) {
         parmFileError(parfile, line);
         return BADPARMDATA;
      } else line++;
      fgets(filebuf, FBUFFLEN, unit1);
      if (sscanf(filebuf, readTwoFloatsOneInt, qminb, qmaxb, npntsb) != 3) {
         parmFileError(parfile, line);
         return BADPARMDATA;
      } else line++;
      fgets(filebuf, FBUFFLEN, unit1);
      if (sscanf(filebuf, readTwoFloatsOneInt, qminc, qmaxc, npntsc) != 3) {
         parmFileError(parfile, line);
         return BADPARMDATA;
      } else line++;
      fgets(filebuf, FBUFFLEN, unit1);
      if (sscanf(filebuf, readTwoFloatsOneInt, qmind, qmaxd, npntsd) != 3) {
         parmFileError(parfile, line);
         return BADPARMDATA;
      } else line++;
      fgets(filebuf, FBUFFLEN, unit1);
      if (sscanf(filebuf, "%s", proftyp) != 1) {
         parmFileError(parfile, line);
         return BADPARMDATA;
      } else {
         if (*proftyp == 'E')
            generf(*nrough, zint, rufint);
         else if (*proftyp == 'H')
            gentanh(*nrough, zint, rufint);
         else {
            parmFileError(parfile, line);
            return BADPARMDATA;
         }
         line++;
      }
      fgets(filebuf, FBUFFLEN, unit1);
      if (sscanf(filebuf, "%s", polstat) != 1) {
         parmFileError(parfile, line);
         return BADPARMDATA;
      } else line++;
      loadFilename(unit1, infile, INFILELEN);
      loadFilename(unit1, outfile, OUTFILELEN);
      line += 2;
      for (i = 0; i <= *nlayer; i++) {
         fgets(filebuf, FBUFFLEN, unit1);
         if (sscanf(filebuf, readfourfloats, qcsq++, d++, rough++, mu++) != 4) {
            parmFileError(parfile, line);
            return BADPARMDATA;
         } else line++;
         fgets(filebuf, FBUFFLEN, unit1);
         if (sscanf(filebuf, readthreefloats, qcmsq++, dm++, mrough++) != 3) {
            parmFileError(parfile, line);
            return BADPARMDATA;
         } else line++;
         fgets(filebuf, FBUFFLEN, unit1);
         if (sscanf(filebuf, readonefloat, the++) != 1) {
            parmFileError(parfile, line);
            return BADPARMDATA;
         } else line++;
      }
      for (i = 0; i < *mfit; i++)
         fscanf(unit1, "%d", &(lista[i]));

      for (i = getc(unit1); i != '\n'; i = getc(unit1));
      i = getc(unit1);
      cleanFree((void **)&ConstraintScript);
      if (i != EOF) {
         long pos,len;
         pos = ftell (unit1);
         fseek(unit1,0L,SEEK_END);
         len = ftell (unit1) - pos + 1;
         fseek(unit1,pos-1,SEEK_SET);
         ConstraintScript = malloc(len+1);
         if (ConstraintScript) {
            fread(ConstraintScript, len, 1, unit1);
            ConstraintScript[len] = '\0';
         }
      }
      if (ConstraintScript == NULL) retValue = NOPARMSCRIPT;
      fclose(unit1);
      for (i = 0; i < na; i++)
         unc[i] = 0.;
   }
   return retValue;
}


STATIC void parmFileError(char *parfile, int line)
{
   ERROR("/** Error reading parameter file %s on line %d **/\n", parfile, line);
}


STATIC int loadFilename(FILE *file, char *filename, int namelength)
{
   int n;

   fgets(filebuf, FBUFFLEN, file);
   strncpy(filename, filebuf, namelength);

   /* Ensure null terminated */
   filename[namelength] = 0;

  /* Strip trailing spaces and newline.  This will be a problem if
    * the filename ends with a blank, but until we need to change the
    * staj file format, we should continue to support the old fortran 
    * staj files, which may have trailing blanks in the file name.
    */
   n = strlen(filename) - 1;
   while (n>=0 && isspace(filename[n])) n--;
   filename[n+1] = '\0';

   return 1;
}


/*-new parameter file in ASCII form*****/

#include <stdio.h>
#include <string.h>
#include <parms.h>
#include <lenc.h>

#include <cparms.h>

/* Local function prototypes */
#include <static.h>
#include "error.h"
#include "genpsc.h"
#include "cleanFree.h"

#ifndef MALLOC
#define MALLOC malloc
#else
extern void* MALLOC(int);
#endif

STATIC void parmFileError(char *parfile, int line);
STATIC int loadLayers(FILE *file, int layers, double *qcsq, double *qcmsq,
   double *d, double *rough, double *mu);
STATIC int saveLayers(FILE *file, int layers, double *qcsq, double *qcmsq,
   double *d, double *rough, double *mu);
STATIC int loadFilename(FILE *file, char *filename, int namelength);


/* Module variables */
static char filebuf[FBUFFLEN + 1];


int parms(double tqcsq[], double mqcsq[], double bqcsq[], double tqcmsq[],
          double mqcmsq[], double bqcmsq[],
          double td[], double md[], double bd[],
          double trough[], double mrough[], double brough[],
          double tmu[], double mmu[], double bmu[],
          int maxlay, double *lambda,
          double *lamdel, double *thedel,
          int *ntlayer, int *nmlayer, int *nblayer, int *nrepeat,
          double *qmin, double *qmax, int *npnts,
          char *infile, char *outfile,
          double *bmintns, double *bki, int lista[],
          int *mfit,
          int na, int *nrough, char *proftyp,
          double *unc, char *scriptfile, char *parfile,
          int store)
{
   int i, line, retValue = 0;
   FILE *unit1;

   if (store) {
      unit1 = fopen(parfile, "w");
      if (unit1 != NULL) {
         fprintf(unit1, "%13d%13d%13d%13d%13d%13d\n",
             *ntlayer, *nmlayer, *nblayer, *nrepeat, *mfit, *nrough);

         fprintf(unit1, "%#15.6G%#15.6G%#15.6G\n",
             *lambda, *lamdel, *thedel);
         fprintf(unit1, "%#15.6G%#15.6G%#15.6G%#15.6G%15d\n",
             *bmintns, *bki, *qmin, *qmax, *npnts);
         fprintf(unit1, "%s\n", proftyp);
         fprintf(unit1, "%s\n", infile);
         fprintf(unit1, "%s\n", outfile);
         saveLayers(unit1, *ntlayer, tqcsq, tqcmsq, td, trough, tmu);
         saveLayers(unit1, *nmlayer, mqcsq, mqcmsq, md, mrough, mmu);
         saveLayers(unit1, *nblayer, bqcsq, bqcmsq, bd, brough, bmu);
         for (i = 0; i < *mfit; i++)
            fprintf(unit1, "%4d", lista[i]); /*ARRAY*/
         fputc('\n', unit1);
         if (ConstraintScript != NULL)
            fwrite(ConstraintScript, strlen(ConstraintScript), 1, unit1);
         fclose(unit1);
      } else {
         puts("/** Unable to open parameter file **/");
      }
   } else {
      line = 0;
      unit1 = fopen(parfile, "r");
      if (unit1 == NULL) {
         puts("/** Unable to open parameter file **/");
         infile[0] = 0;
         outfile[0] = 0;
         strcpy(proftyp, "e");
         return NOPARMFILE;
      } else line++;
      fgets(filebuf, FBUFFLEN, unit1);
      if (sscanf(filebuf, "%d %d %d %d %d %d",
          ntlayer, nmlayer, nblayer, nrepeat, mfit, nrough) != 6) {
         parmFileError(parfile, line);
         return BADPARMDATA;
      } else line++;
      fgets(filebuf, FBUFFLEN, unit1);
      if (sscanf(filebuf, "%lf %lf %lf", lambda, lamdel, thedel) != 3) {
         parmFileError(parfile, line);
         return BADPARMDATA;
      } else line++;
      fgets(filebuf, FBUFFLEN, unit1);
      if (sscanf(filebuf, "%lf %lf %lf %lf %d",
          bmintns, bki, qmin, qmax, npnts) != 5) {
         parmFileError(parfile, line);
         return BADPARMDATA;
      } else line++;
      fgets(filebuf, FBUFFLEN, unit1);
      if (sscanf(filebuf, "%s", proftyp) != 1) {
         parmFileError(parfile, line);
         return BADPARMDATA;
      } else line++;
      loadFilename(unit1, infile, INFILELEN);
      loadFilename(unit1, outfile, OUTFILELEN);
      line += 2;
      i = loadLayers(unit1, *ntlayer, tqcsq, tqcmsq, td, trough, tmu);
      line += *ntlayer - i;
      if (i > 0) {
         parmFileError(parfile, line);
         return BADPARMDATA;
      }
      i = loadLayers(unit1, *nmlayer, mqcsq, mqcmsq, md, mrough, mmu);
      line += *nmlayer - i;
      if (i > 0) {
         parmFileError(parfile, line);
         return BADPARMDATA;
      }
      i = loadLayers(unit1, *nblayer, bqcsq, bqcmsq, bd, brough, bmu);
      line += *nblayer - i;
      if (i > 0) {
         parmFileError(parfile, line);
         return BADPARMDATA;
      }
      for (i = 0; i < *mfit; i ++)
         fscanf(unit1, "%d", &(lista[i])); /*ARRAY*/

      for (i = getc(unit1); i != '\n'; i = getc(unit1));
      i = getc(unit1);
      cleanFree((double **)&ConstraintScript);
      if (i != EOF) {
         long pos,len;
         pos = ftell (unit1);
         fseek(unit1,0L,SEEK_END);
         len = ftell (unit1) - pos + 1;
         fseek(unit1,pos,SEEK_SET);
         ConstraintScript = MALLOC(len+1);
         if (ConstraintScript) {
            fread(ConstraintScript, len, 1, unit1);
            ConstraintScript[len] = '\0';
         }
      }
      if (ConstraintScript == NULL) retValue = NOPARMSCRIPT;
      fclose(unit1);
      for (i = 0; i < na; i ++)
         unc[i] = 0.;
   }
   return retValue;
}


STATIC void parmFileError(char *parfile, int line)
{
   ERROR("/** Error reading parameter file %s on line %d **/\n", parfile, line);
}


STATIC int loadLayers(FILE *file, int layers, double *qcsq, double *qcmsq,
   double *d, double *rough, double *mu)
{
   for (; layers >= 0; layers--) {
      fgets(filebuf, FBUFFLEN, file);
      if (sscanf(filebuf, "%lf %lf %lf %lf %lf",
         qcsq++, qcmsq++, d++, rough++, mu++) != 5) break;
   }
   return layers + 1;
}


STATIC int saveLayers(FILE *file, int layers, double *qcsq, double *qcmsq,
   double *d, double *rough, double *mu)
{
   static char *layerData = "%#15.6lE%#15.6lE%#15.6lE%#15.6lE%#15.6lE\n";

   for (; layers >= 0; layers--)
      fprintf(file, layerData,
          *(qcsq++), *(qcmsq++), *(d++), *(rough++), *(mu++));
   return layers + 1;
}


STATIC int loadFilename(FILE *file, char *filename, int namelength)
{
   fgets(filebuf, FBUFFLEN, file);
   strncpy(filename, filebuf, namelength);

   /* Ensure null terminated */
   filename[namelength] = 0;

   /* Strip trailing newline */
   if (filename[strlen(filename) - 1] == '\n')
      filename[strlen(filename) - 1] = 0;

   /* Strip up to first space */
   filename[lenc(filename)] = 0;

   return 1;
}


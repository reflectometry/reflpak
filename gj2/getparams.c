/* Fetches parameters from command line */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <getparams.h>
#include <badInput.h>
#include <caps.h>
#include <gentanh.h>
#include <generf.h>
#include <queryString.h>
#include <setLayerParam.h>

#include <genpsi.h>
#include <genpsr.h>
#include <genpsl.h>
#include <cparms.h>
#include <cdata.h>

/* Local function prototypes */
#include <static.h>
#include "error.h"

STATIC int setParam(void *data, char *prompt, const char *scanftag);
STATIC int fetchLayerParam(char *command, char *prompt, double *param,
   double *unc);
STATIC int fetchLayerNum(char *prompt);


/* Module variables */
static const char *twofloatfield = "%lf %lf";
#define onefloatfield (twofloatfield + 3)
static const char *intfield = "%d";


STATIC int setParam(void *data, char *prompt, const char *scanftag)
{
   int failed = FALSE;
   char *string;

   sprintf(filebuf, "Enter %s: ", prompt);
   string = queryString(filebuf, NULL, 0);
   if (string && sscanf(string, scanftag, data) != 1) {
      badInput(string);
      failed = TRUE;
   }
   return failed;
}


STATIC int fetchLayerParam(char *command, char *prompt, double *param,
   double *unc)
{
   int failed, n;

   n = atoi(command);
   if (n < 1 || n >= MAXLAY) {
      ERROR("/** Invalid parameter number **/");
      n = 0;
      failed = TRUE;
   } else {
      param += n;
      unc += n;
      failed = FALSE;
      sprintf(filebuf, "%s of layer %d", prompt, n);
      failed = setLayerParam(param, unc, filebuf);
   }
   return failed;
}


int setVQCSQ(double *qcsq)
{
   double dummyUnc;

   return setLayerParam(qcsq, &dummyUnc, "vacuum critical Q squared");
}


int setVMQCSQ(double *qcmsq)
{
   double dummyUnc;

   return setLayerParam(qcmsq, &dummyUnc, "vacuum magnetic critical q squared");
}


int setVMU(double *mu)
{
   double dummyUnc;

   return setLayerParam(mu, &dummyUnc, "vacuum linear absorption coefficient");
}


int setLamdel(double *lamdel)
{
   return setParam(lamdel, "delta lambda", onefloatfield);
}


int setThedel(double *thedel)
{
   return setParam(thedel, "delta theta", onefloatfield);
}


int setWavelength(double *lambda)
{
   return setParam(lambda, "wavelength", onefloatfield);
}


int setGuideangle(double *aguide)
{
   return setParam(aguide, "guide angle", onefloatfield);
}


int setNrough(int *nrough)
{
   return setParam(nrough, "number of interfacial layers", intfield);
}


int setNpnts(int *npnts)
{
   return setParam(npnts, "npnts", intfield);
}


int setBeamIntens(double *bmintns, double *unc)
{
   return setLayerParam(bmintns, unc, "beam intensity");
}


int setBackground(double *bki, double *unc)
{
   return setLayerParam(bki, unc, "background intensity");
}


int setQCSQ(char *command, double *qcsq, double *unc)
{
   return fetchLayerParam(command, "critical Q squared", qcsq, unc);
}


int setMQCSQ(char *command, double *mqcsq, double *unc)
{
   return fetchLayerParam(command, "magnetic critical Q squared", mqcsq, unc);
}


int setMU(char *command, double *mu, double *unc)
{
   return fetchLayerParam(command, "length absorption", mu, unc);
}


int setDM(char *command, double *dm, double *unc)
{
   return fetchLayerParam(command, "magnetic thickness", dm, unc);
}


int setD(char *command, double *d, double *unc)
{
   return fetchLayerParam(command, "chemical thickness", d, unc);
}


int setRO(char *command, double *rough, double *unc)
{
   return fetchLayerParam(command, "chemical roughness", rough, unc);
}


int setMRO(char *command, double *mrough, double *unc)
{
   return fetchLayerParam(command, "magnetic roughness", mrough, unc);
}


int setTHE(char *command, double *the, double *unc)
{
   return fetchLayerParam(command, "theta angle of moment", the, unc);
}


int setNlayer(int *nlayer)
{
   int failed;

   failed = setParam(nlayer, "number of layers", intfield);
   if (!failed && *nlayer >= MAXLAY) {
      ERROR("/** Cannot have more than %d layers **/\n", MAXLAY - 1);
      *nlayer = MAXLAY - 1;
   }
   return failed;
}


int setProfile(char *proftyp, int proftyplen)
{
   int failed = FALSE;

   queryString("(H)yperbolic tan or (E)rror function profile? ",
      proftyp, proftyplen);
   switch (*caps(proftyp)) {
      case 0:
         break;
      case 'H':
         gentanh(nrough, zint, rufint);
         break;
      case 'E':
         generf(nrough, zint, rufint);
         break;
      default:
         puts("/** Invalid profile type **/");
         strcpy(proftyp, "E");
         generf(nrough, zint, rufint);

   }
   return failed;
}


int setQrange(double *qmin, double *qmax)
{
   int failed = FALSE;
   char *string;

   string = queryString("Enter QMIN QMAX: ", NULL, 0);
   if (string && sscanf(string, twofloatfield, qmin, qmax) != 2) {
      badInput(string);
      failed = TRUE;
   }
   return failed;
}


int setFilename(char *file, int namelen)
{
   int failed = FALSE;

   queryString("Enter file name: ", file, namelen);
   return failed;
}


int setPolstat(char *polstat, int polstatlen)
{
   int failed = FALSE, xsec;

   queryString("Specify spin state file(s) (a = ++, b = +-, c = -+, d = --): ",
      polstat, polstatlen);
   caps(polstat);

   /* Parse for spin state values */
   for (xsec = 0; xsec < 4; xsec ++)
      xspin[xsec] = (strchr(polstat, (char) xsec + 'A') != NULL);

   ncross = 0;
   for (xsec = 0; xsec < 4; xsec ++)
      if (xspin[xsec]) polstat[ncross++] = (char) xsec + 'a';
   polstat[ncross] = 0;

   if (!(aspin | bspin | cspin | dspin)) {
      puts("/** Invalid polarization state **/");
      failed = TRUE;
   }
   return failed;
}

#include <genpsd.h>
int modifyLayers(char *command)
{
   int failed = FALSE;
   int np = 0;
   char *string;
   register int j;

   string = queryString((*command == 'A' ? "Add new layer before layer: " :
                            "Remove layer: "), NULL, 0);
   if (string) sscanf(string, "%d", &np);
   if (np > 0 && np <= nlayer) {
      if (*command == 'R') {
         for (j = np; j < nlayer; j++) {
               qcsq[j] =    qcsq[j + 1];
              Dqcsq[j] =   Dqcsq[j + 1];
                 mu[j] =      mu[j + 1];
                Dmu[j] =     Dmu[j + 1];
                  d[j] =       d[j + 1];
                 Dd[j] =      Dd[j + 1];
              rough[j] =   rough[j + 1];
             Drough[j] =  Drough[j + 1];
              qcmsq[j] =   qcmsq[j + 1];
             Dqcmsq[j] =  Dqcmsq[j + 1];
                the[j] =     the[j + 1];
               Dthe[j] =    Dthe[j + 1];
                 dm[j] =      dm[j + 1];
                Ddm[j] =     Ddm[j + 1];
             mrough[j] =  mrough[j + 1];
            Dmrough[j] = Dmrough[j + 1];
         }
         nlayer--;
      } else if (nlayer < MAXLAY - 1) {
         for (j = nlayer; j >= np; j--) {
               qcsq[j + 1] =    qcsq[j];
              Dqcsq[j + 1] =   Dqcsq[j];
                 mu[j + 1] =      mu[j];
                Dmu[j + 1] =     Dmu[j];
                  d[j + 1] =       d[j];
                 Dd[j + 1] =      Dd[j];
              rough[j + 1] =   rough[j];
             Drough[j + 1] =  Drough[j];
              qcmsq[j + 1] =   qcmsq[j];
             Dqcmsq[j + 1] =  Dqcmsq[j];
                the[j + 1] =     the[j];
               Dthe[j + 1] =    Dthe[j];
                 dm[j + 1] =      dm[j];
                Ddm[j + 1] =     Ddm[j];
             mrough[j + 1] =  mrough[j];
            Dmrough[j + 1] = Dmrough[j];
         }  
         nlayer++;
            qcsq[j + 1] = 1.e-10;
              mu[j + 1] = 1.e-10;
               d[j + 1] = 1.e-10;
           rough[j + 1] = 1.e-10;
           qcmsq[j + 1] = 1.e-10;
             the[j + 1] = 1.e-10;
              dm[j + 1] = 1.e-10;
          mrough[j + 1] = 1.e-10;
           Dqcsq[j + 1] = 0.;
             Dmu[j + 1] = 0.;
              Dd[j + 1] = 0.;
          Drough[j + 1] = 0.;
          Dqcmsq[j + 1] = 0.;
            Dthe[j + 1] = 0.;
             Ddm[j + 1] = 0.;
         Dmrough[j + 1] = 0.;
      } else {
         puts("/** Too many layers defined **/");
         failed = TRUE;
      }
   } else {
      badInput(string);
      failed = TRUE;
   }
   return failed;
}


int copyLayer(char *command)
{
   int failed = FALSE;
   int source = 0, target = 0;

   source = fetchLayerNum("Copy from layer: ");
   if (source < 0) {
      failed = TRUE;
      return failed;
   }
   
   target = fetchLayerNum("Copy to layer: ");
   if (target < 0) {
      failed = TRUE;
      return failed;
   }

      qcsq[target] =    qcsq[source];
     Dqcsq[target] =   Dqcsq[source];
        mu[target] =      mu[source];
       Dmu[target] =     Dmu[source];
         d[target] =       d[source];
        Dd[target] =      Dd[source];
     rough[target] =   rough[source];
    Drough[target] =  Drough[source];
     qcmsq[target] =   qcmsq[source];
    Dqcmsq[target] =  Dqcmsq[source];
       the[target] =     the[source];
      Dthe[target] =    Dthe[source];
        dm[target] =      dm[source];
       Ddm[target] =     Ddm[source];
    mrough[target] =  mrough[source];
   Dmrough[target] = Dmrough[source];

   return failed;
}


int superLayer(char *command)
{
   int source, count, layer, repeat = 0, failed = FALSE;
   char *string;

   source = fetchLayerNum("Superlattice starts with layer: ");
   if (source < 0) {
      failed = TRUE;
      return failed;
   }

   count = fetchLayerNum("Superlattice ends with layer: ");
   if (count < 0) {
      failed = TRUE;
      return failed;
   }

   count -= source;
   if (count < 0)
      count = -count;

   if (count == 0) {
      failed = TRUE;
      return failed;
   }
   count++;

   string = queryString("Number of repeats: ", NULL, 0);
   if (string) sscanf(string, "%d", &repeat);
   if (repeat < 1) {
      badInput(string);
      failed = TRUE;
      return failed;
   }

   if (source + count * repeat > MAXLAY) {
      ERROR("/** Number of repeats will exceed "
             "maximum layer count of %d. **/\n", MAXLAY - 1);
      failed = TRUE;
      return failed;
   }

   printf("%d layers starting at layer %d will be overwritten.  "
          "Type no to cancel.\n", repeat * count, source);
   string = queryString("Continue with superlattice? ", NULL, 0);
   if (string && !(*string == 'y' || *string == 'Y')) {
      failed = TRUE;
      return failed;
   }

   for (; repeat > 1; repeat--) {
      for (layer = 0; layer < count; layer ++) {
            qcsq[source + layer + count] =   qcsq[source + layer];
              mu[source + layer + count] =     mu[source + layer];
               d[source + layer + count] =     d[source + layer];
           rough[source + layer + count] =  rough[source + layer];
           qcmsq[source + layer + count] =  qcmsq[source + layer];
             the[source + layer + count] =    the[source + layer];
              dm[source + layer + count] =     dm[source + layer];
          mrough[source + layer + count] = mrough[source + layer];
           Dqcsq[source + layer + count] = 0.0;
             Dmu[source + layer + count] = 0.0;
              Dd[source + layer + count] = 0.0;
          Drough[source + layer + count] = 0.0;
          Dqcmsq[source + layer + count] = 0.0;
            Dthe[source + layer + count] = 0.0;
             Ddm[source + layer + count] = 0.0;
         Dmrough[source + layer + count] = 0.0;
      }
      source += count;
   }
   if (nlayer < source + count - 1)
      nlayer = source + count - 1;
   return failed;
}


STATIC int fetchLayerNum(char *prompt)
{
   char *string;
   int layer = 0;

   string = queryString(prompt, NULL, 0);
   if (string) sscanf(string, "%d", &layer);
   if (layer <= 0 || layer > nlayer) {
      badInput(string);
      layer = -1;
   }
   return layer;
}


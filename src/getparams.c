/* Fetches parameters from command line */

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <getparams.h>
#include <lenc.h>
#include <caps.h>
#include <gentanh.h>
#include <generf.h>
#include <badInput.h>
#include <queryString.h>

#include <cparms.h>
#include <genpsi.h>
#include <genpsr.h>
#include "setLayerParam.h"
#include "cdata.h"

/* Module variables */
#define INPUTLEN 256
static char textbuf[INPUTLEN];
static const char *twofloatfield = "%lf %lf";
#define onefloatfield (twofloatfield + 3)
static const char *intfield = "%d";


/* Local function protypes */
#include <static.h>
#include "error.h"

STATIC int setParam(void *data, char *prompt, const char *scanftag);
STATIC int loadRegPtrs(int sec, double **qcsq, double **Dqcsq, double **mu,
   double **Dmu, double **d, double **Dd, double **rough, double **Drough,
   int **nlayer);


STATIC int setParam(void *data, char *prompt, const char *scanftag)
{
   int failed = FALSE;
   char *string;
   static char textbuf[INPUTLEN];

   sprintf(textbuf, "Enter %s: ", prompt);
   string = queryString(textbuf, NULL, 0);
   if (string && sscanf(string, scanftag, data) != 1) {
      badInput(string);
      failed = TRUE;
   }
   return failed;
}


int setVQCSQ(double *qcsq)
{
   double dummyUnc;

   return setLayerParam(qcsq, &dummyUnc, "vacuum critical Q squared");
}


int setVMU(double *mu)
{
   double dummyUnc;

   return setLayerParam(mu, &dummyUnc, "vacuum linear absorption coefficient");
}


int setQCSQ(int n, double *qcsq, double *unc)
{
   int failed;

   if (n < 0) failed = TRUE;
   else {
      sprintf(textbuf, "critical Q squared of layer %d", n);
      failed = setLayerParam(qcsq, unc, textbuf);
   }
   return failed;
}


int setMU(int n, double *mu, double *unc)
{
   int failed;

   if (n < 0) failed = TRUE;
   else {
      sprintf(textbuf, "length absorption of layer %d", n);
      failed = setLayerParam(mu, unc, textbuf);
   }
   return failed;
}


int setD(int n, double *d, double *unc)
{
   int failed;

   if (n < 0) failed = TRUE;
   else {
      sprintf(textbuf, "thickness of layer %d", n);
      failed = setLayerParam(d, unc, textbuf);
   }
   return failed;
}


int setRO(int n, double *rough, double *unc)
{
   int failed;

   if (n < 0) failed = TRUE;
   else {
      sprintf(textbuf, "roughness of layer %d", n);
      failed = setLayerParam(rough, unc, textbuf);
   }
   return failed;
}


int setWavelength(double *lambda)
{
   return setParam(lambda, "wavelength", onefloatfield);
}


int setThetaoffset(double *theta_offset)
{
   return setParam(theta_offset, "theta offset", onefloatfield);
}


int setNLayer(int *nlayer)
{
   int failed = FALSE;

   failed = setParam(nlayer, "number of layers", intfield);
   if (!failed && *nlayer >= MAXLAY) {
      ERROR("/** Cannot have more than %d layers **/", MAXLAY - 1);
      *nlayer = MAXLAY - 1;
   }
   return failed;
}


int setNRough(int *nrough)
{
   return setParam(nrough, "number of interfacial layers", intfield);
}


int setProfile(char *proftyp, int proftyplen)
{
   int failed = FALSE;

   queryString("(H)yperbolic tan or (E)rror function profile? ",
      proftyp, proftyplen);
   switch(*caps(proftyp)) {
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


int setNrepeat(int *nrepeat)
{
   return setParam(nrepeat, "number of repeats in multilayer", intfield);
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


int setNpnts()
{
   int ret, n;
   ret = setParam(&n, "npnts", intfield);
   if (ret == FALSE) {
     allocCdata(n);
   }
   return ret;
}


int setFilename(char *file, int namelen)
{
   int failed = FALSE;

   queryString("Enter file name: ", file, namelen);
   return failed;
}


int setLamdel(double *lamdel)
{
   return setParam(lamdel, "delta lambda", onefloatfield);
}


int setThedel(double *thedel)
{
   return setParam(thedel, "delta theta", onefloatfield);
}


int setBeamIntens(double *bmintns, double *unc)
{
   return setLayerParam(bmintns, unc, "beam intensity");
}


int setBackground(double *bki, double *unc)
{
   return setLayerParam(bki, unc, "background intensity");
}


/* Be sure to call this with command and paramcom already in uppercase */
int fetchLayParam(char *command, char *paramcom,
   double *top, double *mid, double *bot,
   double *Dtop, double *Dmid, double *Dbot,
   int (*store)(int, double *, double *))
{
   int n, paramlen, failed = 0;
   double *param, *unc;

   paramlen = lenc(paramcom);

   switch (*command) {
      case 'T':
      case 'M':
      case 'B':
         if (strncmp(command + 1, paramcom, paramlen) == 0) {
            n = (int) (command[paramlen + 1]) - '0';
            if (n < 1 || n > 9) {
               puts("/** Invalid parameter number **/");
               failed = 1;
            } else {
               switch (*command) {
                  case 'T':
                     param = top;
                     unc = Dtop;
                     break;
                  case 'M':
                     param = mid;
                     unc = Dmid;
                     break;
                  case 'B':
                     param = bot;
                     unc = Dbot;
                     break;
               }
               param += n;
               unc += n;
               failed = (*store)(n, param, unc);
            }
         } else
            failed = -1;
         break;
      default:
         failed = -1;
   }
   return failed;
}


#include <genpsd.h>
int modifyLayers(char *command)
{
   int failed = FALSE;
   int np = 0, *nlayer;
   char *string;
   register int j;
   double *qcsq, *Dqcsq, *mu, *Dmu, *d, *Dd, *rough, *Drough;


   loadRegPtrs((int) command[1], &qcsq, &Dqcsq, &mu, &Dmu, &d, &Dd, &rough,
      &Drough, &nlayer);
   string = queryString((*command == 'A' ? "Add new layer before layer: " :
                            "Remove layer: "), NULL, 0);
   if (string) sscanf(string, "%d", &np);
   if (np > 0 && np <= *nlayer) {
      if (*command == 'R') {
         for (j = np; j < *nlayer; j++) {
              qcsq[j] =   qcsq[j + 1];
             Dqcsq[j] =  Dqcsq[j + 1];
                mu[j] =     mu[j + 1];
               Dmu[j] =    Dmu[j + 1];
                 d[j] =      d[j + 1];
                Dd[j] =     Dd[j + 1];
             rough[j] =  rough[j + 1];
            Drough[j] = Drough[j + 1];
         }
         (*nlayer)--;
      } else if (*nlayer < MAXLAY - 1) {
         for (j = *nlayer; j >= np; j--) {
              qcsq[j + 1] =   qcsq[j];
             Dqcsq[j + 1] =  Dqcsq[j];
                mu[j + 1] =     mu[j];
               Dmu[j + 1] =    Dmu[j];
                 d[j + 1] =      d[j];
                Dd[j + 1] =     Dd[j];
             rough[j + 1] =  rough[j];
            Drough[j + 1] = Drough[j];
         }
         (*nlayer)++;
           qcsq[j + 1] = 1.e-10;
             mu[j + 1] = 1.e-10;
              d[j + 1] = 1.e-10;
          rough[j + 1] = 1.e-10;
          Dqcsq[j + 1] = 0.;
            Dmu[j + 1] = 0.;
             Dd[j + 1] = 0.;
         Drough[j + 1] = 0.;
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
   int sourceLay = 0, targetLay = 0;
   char sourceReg = 0, targetReg = 0;
   char *string;
   int *s_nlayer, *t_nlayer;
   double *s_qcsq, *s_Dqcsq, *s_mu, *s_Dmu, *s_d, *s_Dd, *s_rough, *s_Drough;
   double *t_qcsq, *t_Dqcsq, *t_mu, *t_Dmu, *t_d, *t_Dd, *t_rough, *t_Drough;

   string = queryString("Copy from layer: ", NULL, 0);
   caps(string);
   if (string) sscanf(string, "%c%d", &sourceReg, &sourceLay);
   if (
      loadRegPtrs((int) sourceReg, &s_qcsq, &s_Dqcsq, &s_mu, &s_Dmu, &s_d,
         &s_Dd, &s_rough, &s_Drough, &s_nlayer) ||
      sourceLay <= 0 ||
      sourceLay > *s_nlayer
   ) {
      badInput(string);
      failed = TRUE;
      return failed;
   }

   string = queryString("Copy to layer: ", NULL, 0);
   caps(string);
   if (string) sscanf(string, "%c%d", &targetReg, &targetLay);
   if (
      loadRegPtrs((int) targetReg, &t_qcsq, &t_Dqcsq, &t_mu, &t_Dmu, &t_d,
         &t_Dd, &t_rough, &t_Drough, &t_nlayer) ||
      targetLay <= 0 ||
      targetLay > *t_nlayer
   ) {
      badInput(string);
      failed = TRUE;
      return failed;
   }

     t_qcsq[targetLay] =   s_qcsq[sourceLay];
    t_Dqcsq[targetLay] =  s_Dqcsq[sourceLay];
       t_mu[targetLay] =     s_mu[sourceLay];
      t_Dmu[targetLay] =    s_Dmu[sourceLay];
        t_d[targetLay] =      s_d[sourceLay];
       t_Dd[targetLay] =     s_Dd[sourceLay];
    t_rough[targetLay] =  s_rough[sourceLay];
   t_Drough[targetLay] = s_Drough[sourceLay];

   return failed;
}


STATIC int loadRegPtrs(int sec, double **qcsq, double **Dqcsq, double **mu,
   double **Dmu, double **d, double **Dd, double **rough, double **Drough,
   int **nlayer)
{
   int failed = FALSE;

   switch (sec) {
      case 'T':
           *qcsq =    tqcsq;
          *Dqcsq =   Dtqcsq;
             *mu =      tmu;
            *Dmu =     Dtmu;
              *d =       td;
             *Dd =      Dtd;
          *rough =   trough;  
         *Drough =  Dtrough;
         *nlayer = &ntlayer;
         break;
      case 'M':
           *qcsq =    mqcsq;
          *Dqcsq =   Dmqcsq;
             *mu =      mmu;
            *Dmu =     Dmmu;
              *d =       md;
             *Dd =      Dmd;
          *rough =   mrough;  
         *Drough =  Dmrough;
         *nlayer = &nmlayer;
         break;
      case 'B':
           *qcsq =    bqcsq;
          *Dqcsq =   Dbqcsq;
             *mu =      bmu;
            *Dmu =     Dbmu;
              *d =       bd;
             *Dd =      Dbd;
          *rough =   brough;  
         *Drough =  Dbrough;
         *nlayer = &nblayer;
         break;
      default:
         failed = TRUE;
   }
   return failed;
}


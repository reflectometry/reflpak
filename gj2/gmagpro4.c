/* Subroutine creates nuclear and magnetic profiles */
/* John Ankner 8 August 1992 */

#include <gmagpro4.h>

#include <stdio.h>
#include <parameters.h>
#include <nglayd.h>
#include <mglayd.h>
#include <glayd.h>
#include <glayin.h>
#include <glayim.h>
#include <glayi.h>
#include <genpsi.h>


void gmagpro4(void)
{
   register int j, jn, jm;
   double zn, zm, qcni, qcnf, qcmi, qcmf;
   double zdiff, mui, muf, thei, thef;

   /* Combine independently generated nuclear and magnetic profiles */
   /* such that one sequence of steps is generated, containing all of */
   /* the scattering density information. */
   /* Place first layer on stack and set up initial steps */
   zn = gdn[0] / 2.;
   zm = gdm[0] / 2.;
   jn = 0;
   jm = 0;
   zdiff = zn - zm;
   if (zdiff < -.01) {
      gd[0] = zn;
      zm += -zn + (gdm[0] + gdm[1]) / 2.;
      zn = (gdn[0] + gdn[1]) / 2.;
      jn++;
   } else if (zdiff > .01) {
      gd[0] = zm;
      zn += -zm + (gdn[0] + gdn[1]) / 2.;
      zm = (gdm[0] + gdm[1]) / 2.;
      jm++;
   } else {
      gd[0] = zn;
      zn = (gdn[0] + gdn[1]) / 2.;
      zm = (gdm[0] + gdm[1]) / 2.;
      jn++;
      jm++;
   }
   gqcsq[0] = gqcnsq[0];
     gmu[0] = gmun[0];
   gqmsq[0] = gqcmsq[0];
    gthe[0] = gthem[0];
       qcni = gqcnsq[0];
       qcnf = gqcnsq[1];
       qcmi = gqcmsq[0];
       qcmf = gqcmsq[1];
        mui = gmun[0];
        muf = gmun[1];
       thei = gthem[0];
       thef = gthem[1];
      nglay = 1;
   while (jn < nglayn && jm < nglaym) {
/* printf("jn: %d\tjm: %d\tzn: %G\tzm: %G\t", jn, jm, zn, zm); */
      /* Construct combined profile by stepping through nuclear and */
      /* magnetic profiles, always combining the shortest possible */
      /* steps together */
      zdiff = zn - zm;
      if (zdiff < -.01) {
/* puts("Nuc thinner"); */
         gd[nglay] = zn;
         /* Take average of nuclear quantities, which represents value at */
         /* center of ZN */
         gqcsq[nglay] = (qcni + qcnf) / 2.;
           gmu[nglay] = ( mui +  muf) / 2.;
         /* Interpolate magnetic quantities to center of ZN */
         gqmsq[nglay] = qcmi + (qcmf - qcmi) * zn / (2. * zm);
          gthe[nglay] = thei + (thef - thei) * zn / (2. * zm);
         /* Update initial and final values of nuclear quantities */
         qcni = gqcnsq[jn];
         qcnf = gqcnsq[jn + 1];
          mui =  gmun[jn];
          muf =  gmun[jn + 1];
         /* Update initial values of magnetic quantities */
         qcmi += (qcmf - qcmi) * zn / zm;
         thei += (thef - thei) * zn / zm;
         /* Update thicknesses */
         zm -= zn;
         zn = (gdn[jn] + gdn[jn + 1]) / 2.;
         jn++;
      } else if (zdiff > .01) {
/* puts("Mag thinner"); */
         gd[nglay] = zm;
         /* Interpolate nuclear quantities to center of ZM */
         gqcsq[nglay] = qcni + (qcnf - qcni) * zm / (2. * zn);
           gmu[nglay] =  mui + ( muf -  mui) * zm / (2. * zn);
         /* Take average of magnetic quantities, which represents value at */
         /* center of ZM */
         gqmsq[nglay] = (qcmi + qcmf) / 2.;
          gthe[nglay] = (thei + thef) / 2.;
         /* Update initial values of nuclear quantities */
         qcni += (qcnf - qcni) * zm / zn;
         mui += (muf - mui) * zm / zn;
         /* Update initial and final values of magnetic quantities */
         qcmi = gqcmsq[jm];
         qcmf = gqcmsq[jm + 1];
         thei =  gthem[jm];
         thef =  gthem[jm + 1];
         /* Update thicknesses */
         zn -= zm;
         zm = (gdm[jm] + gdm[jm + 1]) / 2.;
         jm++;
      } else {
/* puts("Nuc and mag equal"); */
         /* Nuclear and magnetic thicknesses equal */
         gd[nglay] = zn;
         /* Take average of nuclear and magnetic quantities */
         gqcsq[nglay] = (qcni + qcnf) / 2.;
           gmu[nglay] = ( mui +  muf) / 2.;
         gqmsq[nglay] = (qcmi + qcmf) / 2.;
          gthe[nglay] = (thei + thef) / 2.;
         /* Update initial and final values of nuclear and magnetic */
         /* quantities */
         qcni = gqcnsq[jn];
         qcnf = gqcnsq[jn + 1];
          mui =   gmun[jn];
          muf =   gmun[jn + 1];
         qcmi = gqcmsq[jm];
         qcmf = gqcmsq[jm + 1];
         thei =  gthem[jm];
         thef =  gthem[jm + 1];
         /* Update thicknesses */
         zn = (gdn[jn] + gdn[jn + 1]) / 2.;
         zm = (gdm[jm] + gdm[jm + 1]) / 2.;
         jn++;
         jm++;
      }
      nglay++;
   }
   /* Finish off profile */
/* printf("jn: %d nglayn: %d\tjm: %d nglaym: %d\n", jn, nglayn, jm, nglaym); */
   if (jn >= nglayn) {
      /* Interpolate between NGLAYN and center point of JM */
      gd[nglay] = zm;
      /* Take average of nuclear and magnetic quantities */
      gqcsq[nglay] = (qcni + qcnf) / 2.;
        gmu[nglay] = ( mui +  muf) / 2.;
      gqmsq[nglay] = (qcmi + qcmf) / 2.;
       gthe[nglay] = (thei + thef) / 2.;
      jm++;
      nglay++;
      if (jm < nglaym) {
         /* Place remaining magnetic layers on stack */
         for (j = jm; j < nglaym; j++) {
               gd[nglay] = (gdm[j] + gdm[j - 1]) / 2.;
            gqcsq[nglay] = gqcnsq[nglayn];
              gmu[nglay] = gmun[nglayn];
            gqmsq[nglay] = (gqcmsq[j] + gqcmsq[j - 1]) / 2.;
             gthe[nglay] = ( gthem[j] +  gthem[j - 1]) / 2.;
            nglay++;
         }
      }
      if (jm == nglaym) {
            gd[nglay] =    gdm[nglaym - 1] / 2.;
         gqcsq[nglay] = gqcnsq[nglayn];
           gmu[nglay] =   gmun[nglayn];
         gqmsq[nglay] = (gqcmsq[nglaym] + gqcmsq[nglaym - 1]) / 2.;
          gthe[nglay] = ( gthem[nglaym] +  gthem[nglaym - 1]) / 2.;
         nglay++;
      }
   } else if (jm >= nglaym) {
      /* Interpolate between NGLAYM and center point of JM */
         gd[nglay] = zn;
      gqcsq[nglay] = (qcni + qcnf) / 2.;
        gmu[nglay] = (mui + muf) / 2.;
      gqmsq[nglay] = (qcmi + qcmf) / 2.;
       gthe[nglay] = (thei + thef) / 2.;
      jn++;
      nglay++;
      if (jn < nglayn) {
         /* Place remaining nuclear layers on stack */
         for (j = jn; j <= nglayn - 1; j++) {
               gd[nglay] = (   gdn[j] +    gdn[j - 1]) / 2.;
            gqcsq[nglay] = (gqcnsq[j] + gqcnsq[j - 1]) / 2.;
              gmu[nglay] = (  gmun[j] +   gmun[j - 1]) / 2.;
            gqmsq[nglay] = gqcmsq[nglaym];
             gthe[nglay] =  gthem[nglaym];
            nglay++;
         }
      }
      if (jn == nglayn) {
            gd[nglay] = gdn[nglayn] / 2.;
         gqcsq[nglay] = (gqcnsq[nglayn] + gqcnsq[nglayn - 1]) / 2.;
           gmu[nglay] = (  gmun[nglayn] +   gmun[nglayn - 1]) / 2.;
         gqmsq[nglay] = gqcmsq[nglaym];
          gthe[nglay] =  gthem[nglaym];
         nglay++;
      }
   }
   /* Place last layer on stack */
      gd[nglay] =    gdn[nglayn];
   gqcsq[nglay] = gqcnsq[nglayn];
     gmu[nglay] =   gmun[nglayn];
   gqmsq[nglay] = gqcmsq[nglaym];
    gthe[nglay] =  gthem[nglaym];
}


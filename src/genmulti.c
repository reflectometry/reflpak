/* Subroutine calculates reflectivity of multilayer by calling
   GENMLAYERS to evaluate the cap layers, looping over the
   multilayer, evaluating the buffer and substrate layers, and
   combining it all into one profile
   John Ankner 26-June-1990 */

#include <genmulti.h>
#include <genvac.h>
#include <genmlayers.h>
#include <gensub.h>

void genmulti(double tqcsq[], double mqcsq[], double bqcsq[], double tqcmsq[],
              double mqcmsq[], double bqcmsq[],
              double td[], double md[], double bd[],
              double trough[], double mrough[], double brough[], double tmu[],
              double mmu[], double bmu[],
              int nrough, int ntlayer, int nmlayer,
              int nblayer, int nrepeat, char *proftyp)
{
#include <parameters.h>
#include <genpsr.h>
#include <glayd.h>
#include <glayi.h>

   int nmi, nmf, nsteps;
   register int i, j;

   /* Generate top-most (cap) layers */
   /* Vacuum layer */
   nglay = 0;
   genvac(tqcsq, td, trough, tmu, ntlayer, zint, rufint, nrough);
   /* Couple to multilayers */
    tqcsq[ntlayer + 1] =  mqcsq[1];
      tmu[ntlayer + 1] =    mmu[1];
   trough[ntlayer + 1] = mrough[1];
   genmlayers(tqcsq, td, trough, tmu, ntlayer + 1,
              zint, rufint, nrough, proftyp);

   /* Generate multilayers */

   /* Connect with cap */
    mqcsq[0] =  tqcsq[ntlayer];
      mmu[0] =    tmu[ntlayer];
   mrough[0] = trough[ntlayer];

   /* Connect with substrate */
    mqcsq[nmlayer + 1] =  bqcsq[1];
      mmu[nmlayer + 1] =    bmu[1];
   mrough[nmlayer + 1] = brough[1];

   /* Calculate unit cell of multilayer */
   nmi = nglay;
   genmlayers(mqcsq, md, mrough, mmu, nmlayer + 1,
              zint, rufint, nrough, proftyp);
   nmf = nglay;
   /* Repeat to obtain full lattice */
   nsteps = nmf - nmi;
   for (j = 1; j <= nrepeat - 1; j++) {
      for (i = nmi; i < nsteps + nmi; i++) {
         gqcsq[j * nsteps + i] = gqcsq[i];
           gmu[j * nsteps + i] =   gmu[i];
            gd[j * nsteps + i] =    gd[i];
      }
      nglay += nsteps;
   }
   /* Generate bottom-most (substrate) layers */

   /* Connect with multilayer */
    bqcsq[0] =  mqcsq[nmlayer];
      bmu[0] =    mmu[nmlayer];
   brough[0] = mrough[nmlayer];
   if (nblayer > 1)
      genmlayers(bqcsq, bd, brough, bmu, nblayer,
                 zint, rufint, nrough, proftyp);

   /* Put substrate on very bottom */
   gensub(bqcsq, bd, brough, bmu, nblayer, zint, rufint, nrough);

   nglay--;
}


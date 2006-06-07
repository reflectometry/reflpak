/* Loads parameters and constraints from parameter file */

#include <stdio.h>
#include <string.h>
#include <loadParms.h>
#include <parms.h>
#include <dlconstrain.h>

#include <cparms.h>
#include <cdata.h>
#include <clista.h>
#include <genpsl.h>
#include <genpsc.h>
#include <genpsi.h>
#include <genpsd.h>

int loadParms(char *command, int *npnts, char *parfile, char *scriptfile,
   char *objectfile)
{
   static char *devnull = "/dev/null";
   int failed = FALSE;
   int result;
    

   if (command[2] != 'C') scriptfile = devnull;

   result = parms(tqcsq, mqcsq, bqcsq, tqcmsq, mqcmsq, bqcmsq, td, md, bd,
         trough, mrough, brough, tmu, mmu, bmu,
         MAXLAY, &lambda,
		  &lamdel, &thedel, &theta_offset,
         &ntlayer, &nmlayer, &nblayer, &nrepeat, &qmin, &qmax, npnts,
         infile, outfile,
         &bmintns, &bki, listA, &mfit, NA, &nrough, proftyp,
         DA, scriptfile, parfile, FALSE);
#if 0
   if (scriptfile != devnull) {
      if (result != NOPARMSCRIPT && makeconstrain(scriptfile, objectfile) == 0)
         Constrain = loadConstrain(objectfile);
      else {
         puts("Errors in constrain module.  Current constraints unchanged.");
         failed = TRUE;
      }
   }
#endif
   return failed;
}


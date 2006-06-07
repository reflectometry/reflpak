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

int loadParms(char *command, char *parfile, char *scriptfile, char *objectfile)
{
   static char *devnull = "/dev/null";
   int failed = FALSE;
   int xsec, result;

   if (command[2] != 'C') scriptfile = devnull;

   result = parms(qcsq, qcmsq, d, dm, rough, mrough, mu, the,
                  MAXLAY, &lambda, &lamdel, &thedel, &aguide,
                 &nlayer, &qmina, &qmaxa, &npntsa,
                 &qminb, &qmaxb, &npntsb, &qminc, &qmaxc, &npntsc,
                 &qmind, &qmaxd, &npntsd,
                  infile, outfile,
                 &bmintns, &bki, listA, &mfit, NA, &nrough, proftyp,
                  polstat, DA, scriptfile, parfile, FALSE);
   for (xsec = 0; xsec < 4; xsec ++)
      xspin[xsec] = (strchr(polstat, (char) xsec + 'a') != NULL);
   ncross = aspin + bspin + cspin + dspin;
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


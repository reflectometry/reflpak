/* To use GNUPLOT from a kermit-based PC:  Type 'setenv GNUTERM kc' before
   running gmlayer!!!!!

  Program fits up to 9 layer reflectivity using algorithm of
  L.G. Parratt, Phys. Rev. 95, 359 (1954) to calculate reflectivity and
  Levenberg - Marquardt non - linear least squares fit routines from
  William H. Press, Brian P. Flannery, Saul A. Teukolsky, and William T.
  Vetterling, Numerical Recipes (Cambridge University Press, Cambridge,
  1986), ch. 14.
  John Ankner 3 January 1989 */

/* The main program MLAYER is organized as a command loop.  A 2 - 4 character
   string is entered into variable COMMAND at the `mlayer%' prompt and the
   program matches the entered command to those in the command loop and takes
   the appropriate action. */

#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include <complex.h>
#include <string.h>
#include <stdio.h>
#include <signal.h>
#include <mlayer.h>
#include <parms.h>
#include <gentanh.h>
#include <generf.h>
#include <caps.h>
#include <genshift.h>
#include <dlconstrain.h>
#include <cleanUp.h>
#include <badInput.h>
#include <getparams.h>
#include <printinfo.h>
#include <loadData.h>
#include <dofit.h>
#include <plotit.h>
#include <extres.h>
#include <loadParms.h>
#include <queryString.h>
#include <help.h>
#include <unix.h>
#include <ipc.h>
#include "error.h"

/* Global data */

#include <cparms.h>
#include <cdata.h>
#include <glayi.h>
#include <glayd.h>

#include <clista.h>
#include <genmem.h>
#include <genpsc.h>
#include <genpsi.h>
#include <genpsr.h>
#include <genpsd.h>

void mlayer_init(void)
{

   int code, ret;

   /* Assign temporary files */
   tmpnam(constrainScript);
   tmpnam(constrainModule);

   /* Obtain current directory */
   getcwd(currentDir,sizeof(currentDir));

   /* Retrieve parameters from disk */
   mfit = 0;
   /* XXX FIXME XXX why code? why not npnts? */
   ret = parms(tqcsq, mqcsq, bqcsq, tqcmsq, mqcmsq, bqcmsq, td, md, bd,
	       trough, mrough, brough, tmu, mmu, bmu,
	       MAXLAY, &lambda,
	       &lamdel, &thedel,
	       &ntlayer, &nmlayer, &nblayer, &nrepeat, &qmin, &qmax, &code,
	       infile, outfile,
	       &bmintns, &bki, listA, &mfit, NA, &nrough, proftyp,
	       DA, constrainScript, parfile, FALSE);
   npnts = 0;
   if (ret == 0) allocCdata(code);

   /* Retrieve constrain module */
   makeconstrain(constrainScript, constrainModule);
   Constrain = loadConstrain(constrainModule);

   /* Set initial background value */
   if (bki < 1.e-20) bki = 1.e-20;

   /* Generate interface roughness profile */
   if (nrough < 3) nrough = 11;
   if (*proftyp == 'H')
       gentanh(nrough, zint, rufint);
   else
       generf(nrough, zint, rufint);

}

void mlayer(void)
{
   static char command[COMMANDLEN+2];
   static double undoFit[NA], undoFitUnc[NA];

   /* Process command */
      while (queryString("mlayer% ", command, COMMANDLEN + 2) == NULL);
      caps(command);

      /* Spawn a command */
      if (strcmp(command, "!") == 0 || strcmp(command, "!!") == 0) {
         bang(command);

      /* Print current directory */
      } else if (strcmp(command, "PWD") == 0) {
         puts(currentDir);

      /* Change current directory */
      } else if (strcmp(command, "CD") == 0) {
         cd(command);

      /* Help */
      } else if (strcmp(command, "?") == 0
		 || strcmp(command, "HE") == 0
		 || strcmp(command, "HELP") == 0) {
         help(command + (*command == '?' ? 1 : 2));

      /* Value of vacuum QCSQ */
      } else if (strcmp(command, "QCV") == 0 || strcmp(command, "VQC") == 0) {
         setVQCSQ(tqcsq);

      /* Value of vacuum linear absorption coefficient */
      } else if (strcmp(command, "MUV") == 0 || strcmp(command, "VMU") == 0) {
         setVMU(tmu);

      /* Wavelength */
      } else if (strcmp(command, "WL") == 0) {
         setWavelength(&lambda);

      /* Number of layers */
      } else if (
         strcmp(command, "NTL") == 0 ||
         strcmp(command, "NML") == 0 ||
         strcmp(command, "NBL") == 0
      ) switch (command[1]) {
         case 'T':
            setNLayer(&ntlayer);
            break;
         case 'M':
            setNLayer(&nmlayer);
            break;
         case 'B':
            setNLayer(&nblayer);
            break;

      /* Add or remove layers */
      } else if (
         strcmp(command, "ATL") == 0 ||
         strcmp(command, "AML") == 0 ||
         strcmp(command, "ABL") == 0 ||
         strcmp(command, "RTL") == 0 ||
         strcmp(command, "RML") == 0 ||
         strcmp(command, "RBL") == 0
      ) {
         modifyLayers(command);

      /* Copy layer */
      } else if (strcmp(command, "CL") == 0) {
         copyLayer(command);

      /* Maximum number of layers used to simulate rough interface */
      } else if (
         strcmp(command, "NR") == 0 &&
         !setNRough(&nrough)
      ) {
         /* Generate interface profile */
         if (nrough < 3) nrough = 11;
         if (*proftyp == 'H')
            gentanh(nrough, zint, rufint);
         else
            generf(nrough, zint, rufint);

      /* Specify error function or hyperbolic tangent profile */
      } else if (strcmp(command, "PR") == 0) {
         setProfile(proftyp, PROFTYPLEN + 2);

      /* Number of layers in multilayer */
      } else if (strcmp(command, "NMR") == 0) {
         setNrepeat(&nrepeat);

      /* Range of Q to be scanned */
      } else if (strcmp(command, "QL") == 0) {
         setQrange(&qmin, &qmax);

      /* Number of points scanned */
      } else if (strcmp(command, "NP") == 0) {
         setNpnts();

      /* File for input data */
      } else if (strcmp(command, "IF") == 0) {
         setFilename(infile, INFILELEN + 2);

      /* File for output data */
      } else if (strcmp(command, "OF") == 0) {
         setFilename(outfile, OUTFILELEN + 2);

      /* File for parameters */
      } else if (strcmp(command, "PF") == 0) {
         setFilename(parfile, PARFILELEN + 2);

      /* Delta lambda */
      } else if (strcmp(command, "DL") == 0) {
         setLamdel(&lamdel);

      /* Delta theta */
      } else if (strcmp(command, "DT") == 0) {
         setThedel(&thedel);

      /* Beam intensity */
      } else if (strcmp(command, "BI") == 0) {
         setBeamIntens(&bmintns, &Dbmintns);

      /* Background intensity */
      } else if (strcmp(command, "BK") == 0) {
         setBackground(&bki, &Dbki);

      /* Verify parameters by printing out */
      } else if (
         strncmp(command, "TVE", 3) == 0 ||
         strncmp(command, "MVE", 3) == 0 ||
         strncmp(command, "BVE", 3) == 0 ||
         strncmp(command, "VE", 2) == 0
      ) {
         printLayers(command);

      /* Get data from file */
      } else if (strcmp(command, "GD") == 0) {
         loadData(infile);

      /* Edit constraints */
      } else if (strcmp(command, "EC") == 0) {
         constrainFunc newmodule;

         newmodule = newConstraints(constrainScript, constrainModule);
         if (newmodule != NULL) Constrain = newmodule;

      /* Reload constrain module */
      } else if (strcmp(command, "LC") == 0) {
         Constrain = loadConstrain(constrainModule);

      /* Unload constrain module */
      } else if (strcmp(command, "ULC") == 0) {
         Constrain = loadConstrain(NULL);

      /* Load parameters from parameter file */
      } else if (strncmp(command, "LP", 2) == 0) {
         loadParms(command, &npnts, parfile, constrainScript, constrainModule);

      /* Save parameters to parameter file */
      } else if (strcmp(command, "SP") == 0) {
         parms(tqcsq, mqcsq, bqcsq, tqcmsq, mqcmsq, bqcmsq, td, md, bd,
               trough, mrough, brough, tmu, mmu, bmu,
               MAXLAY, &lambda,
               &lamdel, &thedel,
               &ntlayer, &nmlayer, &nblayer, &nrepeat, &qmin, &qmax, &npnts,
               infile, outfile,
               &bmintns, &bki, listA, &mfit, NA, &nrough, proftyp,
               DA, constrainScript, parfile, TRUE);

      /* List data and fit */
      } else if (strcmp(command, "LID") == 0) {
         listData();

      /* Generate logarithm of bare (unconvoluted) reflectivity */
      } else if (strcmp(command, "GR") == 0 || strcmp(command, "SA") == 0) {
         genReflect(command);

      /* Generate and display layer profile used for roughness */
      } else if (strcmp(command, "GLP") == 0) {
         genProfile();

      /* Save layer profile to OUTFILE */
      } else if (
         strcmp(command, "SLP") == 0 ||
         strcmp(command, "SSP") == 0
      ) {
         saveProfile(command);

      /* Save values in XTEMP and YTEMP to OUTFILE */
      } else if (strcmp(command, "SV") == 0) {
         saveTemps(outfile);

      /* Calculate derivative of reflectivity or spin asymmetry with respect
         to a fit parameter or save a fit to disk file */
      } else if (
         strcmp(command, "RD") == 0 ||
         strcmp(command, "RSD") == 0 ||
         strcmp(command, "SRF") == 0 ||
         strcmp(command, "SRSF") == 0
      ) {
         printDerivs(command);

      /* Turn off all varied parameters */
      } else if (strcmp(command, "VANONE") == 0) {
         clearLista(listA);

      /* Specify which parameters are to be varied in the reflectivity fit */
      } else if (strncmp(command, "VA", 2) == 0) {
         varyParm(command);

      /* Calculate chi-squared */
      } else if (strcmp(command, "CSR") == 0 || strcmp(command, "CSRS") == 0) {
         printChiSq(command);

      /* Fit five-layer reflectivity */
      } else if (strncmp(command, "FR", 2) == 0) {
         register int n;

         for (n = 0; n < NA; n++) {
            undoFit[n] = A[n];
            undoFitUnc[n] = DA[n];
         }
         fitReflec(command);

      /* Undo last fit */
      } else if (strcmp(command, "UF") == 0) {
         register int n;

         for (n = 0; n < NA; n++) {
            A[n] = undoFit[n];
            DA[n] = undoFitUnc[n];
         }

      /* Exit */
      } else if (strcmp(command, "EX") == 0) {
         parms(tqcsq, mqcsq, bqcsq, tqcmsq, mqcmsq, bqcmsq, td, md, bd,
               trough, mrough, brough, tmu, mmu, bmu,
               MAXLAY, &lambda,
               &lamdel, &thedel,
               &ntlayer, &nmlayer, &nblayer, &nrepeat, &qmin, &qmax, &npnts,
               infile, outfile,
               &bmintns, &bki, listA, &mfit, NA, &nrough, proftyp,
               DA, constrainScript, parfile, TRUE);
         exit(0);

      /* Exit without saving changes */
      } else if (strcmp(command, "QU") == 0 || strcmp(command, "QUIT") == 0) {
         exit(0);

      /***** Start new ************** */

      /* Plot reflectivity on screen */
      } else if (strncmp(command, "PRF", 3) == 0) {
         plotfit(command);

      /* Plot profile on screen */
      } else if (strcmp(command, "PLP") == 0) {
      /* Generate profile */
         plotprofile(command);

      /* Send data to other processes. */
      } else if (strcmp(command, "SEND") == 0) {
	ipc_send(command);

      /* Receive data to other processes. */
      } else if (strcmp(command, "RECV") == 0) {
	ipc_recv(command);

      /* Plot movie of reflectivity change from fit */
      } else if (strncmp(command, "MVF", 3) == 0) {
         fitMovie(command, undoFit);

      /* Plot general movie from data file on screen */
      } else if (strncmp(command, "MVX", 3) == 0) {
         arbitraryMovie(command);

      /* Plot movie of parameter on screen */
      } else if (strncmp(command, "MV", 2) == 0) {
         oneParmMovie(command);

      /* Update constraints */
      } else if (strcmp(command, "UC") == 0) {
         /* genshift(a, TRUE); */
         /* constrain(a); */
         (*Constrain)(FALSE, a, ntlayer, nmlayer, nrepeat, nblayer);
         /* genshift(a, FALSE); */

      /* Enter critical Q squared */
      /* or */
      /* Top length absorption coefficient */
      /* or */
      /* Thicknesses of top layers */
      /* or */
      /* Roughnesses of top layers */

      } else {
         static char *paramcom[] = {"QC", "MU", "D", "RO"};
         static double  *top[] = { tqcsq,  tmu,  td,  trough};
         static double  *mid[] = { mqcsq,  mmu,  md,  mrough};
         static double  *bot[] = { bqcsq,  bmu,  bd,  brough};
         static double *Dtop[] = {Dtqcsq, Dtmu, Dtd, Dtrough};
         static double *Dmid[] = {Dmqcsq, Dmmu, Dmd, Dmrough};
         static double *Dbot[] = {Dbqcsq, Dbmu, Dbd, Dbrough};
         static int (*store[])(int, double *, double *) = {
            setQCSQ, setMU, setD, setRO
         };
         int param, code = -1;

         for (param = 0; param < sizeof(paramcom) / sizeof(paramcom[0]); param++) {
            code = fetchLayParam(command, paramcom[param], top[param],
               mid[param], bot[param], Dtop[param], Dmid[param], Dbot[param],
               store[param]);
            if (code > -1) break;
         }
         if (code == -1)
            ERROR("/** Unrecognized command: %s **/\n", command);
      }
}


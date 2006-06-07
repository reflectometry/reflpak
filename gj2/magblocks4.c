#if defined(COMMENT) && !defined(COMMENT)

  TO USE GNUPLOT from a Kermit-based PC:  Type "setenv GNUTERM kc"
  before running j2!!!!


 Program fits up to 9 layer reflectivity using algorithm of
 L.G. Parratt, Phys. Rev. 95, 359 (1954) to calculate reflectivity and
 Levenberg-Marquardt non-linear least squares fit routines from
 William H. Press, Brian P. Flannery, Saul A. Teukolsky, and William T.
 Vetterling, Numerical Recipes (Cambridge University Press, Cambridge,
 1986), ch. 14.
 John Ankner 3 January 1989

 The main program MAGBLOCKS is organized as a command loop.  A 2-4 character
 string is entered into variable COMMAND at the % prompt and the program
 matches the entered command to those in the command loop and takes the
 appropriate action.  This structure allows a great deal of flexibility
 in developing new features but suffers from the disadvantage that, over
 time, one tends to accumulate a number of useless or obsolete commands.
 However, knowing from bitter experience that, if I remove something, the
 program will fail in mysterious and exciting ways, I will include the
 whole mess and give some editorial guidance as to which sections are
 important.  What follows is an alphabetical list of the available commands.

-------------------------------------------------------------------------------
                             LIST OF COMMANDS
-------------------------------------------------------------------------------

 See help.c for a list of commands

#endif /* COMMENT */

#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>
#include <complex.h>
#include <magblocks4.h>
#include <loadData.h>
#include <loadParms.h>
#include <help.h>
#include <getparams.h>
#include <printinfo.h>
#include <plotit.h>
#include <dofit.h>
#include <gentanh.h>
#include <generf.h>
#include <badInput.h>
#include <dlconstrain.h>
#include <caps.h>
#include <genshift.h>
#include <parms.h>
#include <queryString.h>
#include <cleanUp.h>
#include <unix.h>

#include <parameters.h>
#include <cparms.h>
#include <cdata.h>
#include <clista.h>
#include <genmem.h>
#include <genpsr.h>
#include <genpsl.h>
#include <genpsc.h>
#include <genpsi.h>
#include <genpsd.h>

/* Local function protypes */
#include <static.h>
#include "error.h"
#include "ipc.h"

void magblocks4_init(void)
{
   int xsec, j;

   /* Assign temporary files */
   tmpnam(constrainScript); 
   tmpnam(constrainModule);
 
   /* Obtain current directory */
   getcwd(currentDir,sizeof(currentDir));

   /* Retrieve parameters from disk */
   mfit = 0;
   parms(qcsq, qcmsq, d, dm, rough, mrough, mu, the,
         MAXLAY, &lambda, &lamdel, &thedel, &aguide,
        &nlayer, &qmina, &qmaxa, &npntsa,
        &qminb, &qmaxb, &npntsb, &qminc, &qmaxc, &npntsc,
        &qmind, &qmaxd, &npntsd,
         infile, outfile,
        &bmintns, &bki, listA, &mfit, NA, &nrough, proftyp,
         polstat, DA, constrainScript, parfile, FALSE);

   /* Retrieve constrain module */
   makeconstrain(constrainScript, constrainModule);
   Constrain = loadConstrain(constrainModule);

   /* Set vacuum layer thicknesses */
   d[0] = 10.;
   dm[0] = 10.;

   /* Set initial background value */
   if (bki < 1.e-20) bki = 1.e-20;

   /* Generate interface roughness profile */
   if (nrough < 3) nrough = 11;
   if (proftyp[0] == 'H')
      gentanh(nrough, zint, rufint);
   else
      generf(nrough, zint, rufint);

   /* Set polarization state variables */
   for (xsec = 0; xsec < 4; xsec ++)
      xspin[xsec] = (strchr(polstat, (char) xsec + 'a') != NULL);
   ncross = aspin + bspin + cspin + dspin;

   /* Set all absorptions to non-zero values */
   for (j = 0; j <= nlayer; j++)
      if (mu[j] < 1.e-20) mu[j] = 1.e-20;

}

void magblocks4(void)
{
   static char command[COMMANDLEN + 2];
   static double undoFit[NA], undoFitUnc[NA];
   int npnts, j;
   double qmax, qmin;

   /* Process command */
      while (queryString("magblocks4% ", command, COMMANDLEN + 2) == NULL);
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
      } else if (
         strcmp(command, "?") == 0 ||
         strcmp(command, "HE") == 0
      ) {
         help(command + (*command == '?' ? 1 : 2));

      /* Value of vacuum QCSQ */
      } else if (
         strcmp(command, "QCV") == 0 ||
         strcmp(command, "VQC") == 0
      ) {
         setVQCSQ(qcsq);

      /* Vacuum QCMSQ */
      } else if (
         strcmp(command, "QMV") == 0 ||
         strcmp(command, "VQM") == 0
      ) {
         setVMQCSQ(qcmsq);

      /* Value of vacuum linear absorption coefficient */
      } else if (
         strcmp(command, "MUV") == 0 ||
         strcmp(command, "VMU") == 0
      ) {
         setVMU(mu);

      /* Enter critical Q squared */
      } else if (strncmp(command, "QC", 2) == 0) {
         setQCSQ(command + 2, qcsq, Dqcsq);

      /* Top magnetic critical Q squared */
      } else if (strncmp(command, "QM", 2) == 0) {
         setMQCSQ(command + 2, qcmsq, Dqcmsq);

      /* Top length absorption coefficient */
      } else if (strncmp(command, "MU", 2) == 0) {
         setMU(command + 2, mu, Dmu);

      /* Thicknesses of magnetic layers */
      } else if (strncmp(command, "DM", 2) == 0) {
         setDM(command + 2, dm, Ddm);

      /* Delta lambda */
      } else if (strcmp(command, "DL") == 0) {
         setLamdel(&lamdel);

      /* Delta theta */
      } else if (strcmp(command, "DT") == 0) {
         setThedel(&thedel);

      /* Enter chemical thickness */
      } else if (command[0] == 'D') {
         setD(command + 1, d, Dd);

      /* Chemical roughnesses */
      } else if (strncmp(command, "RO", 2) == 0) {
         setRO(command + 2, rough, Drough);

      /* Magnetic roughnesses of layers */
      } else if (strncmp(command, "RM", 2) == 0) {
         setMRO(command + 2, mrough, Dmrough);

      /* Theta angle of average moment in layer */
      } else if (strncmp(command, "TH", 2) == 0) {
         setTHE(command + 2, the, Dthe);

      /* Wavelength */
      } else if (strcmp(command, "WL") == 0) {
         setWavelength(&lambda);

      /* Guide angle */
      } else if (strcmp(command, "EPS") == 0) {
         setGuideangle(&aguide);

      /* Number of layers */
      } else if (strcmp(command, "NL") == 0) {
         if (!setNlayer(&nlayer))
         /* Bug found Wed Jun  7 10:38:45 EDT 2000 by KOD */
         /* since it starts at 0, correction for vacuum forces zero */
         for (j = 1; j <= nlayer; j++)
            /* Set all absorptions to non-zero values */
            if (mu[j] < *mu) mu[j] = *mu + 1.e-20;

      /* Add or remove layers */
      } else if (strcmp(command, "AL") == 0 || strcmp(command, "RL") == 0) {
         modifyLayers(command);

      /* Copy layer */
      } else if (strcmp(command, "CL") == 0) {
         copyLayer(command);

      /* Make superlattice */
      } else if (strcmp(command, "SL") == 0) {
         superLayer(command);

      /* Maximum number of layers used to simulate rough interface */
      } else if (strcmp(command, "NR") == 0) {
         if (!setNrough(&nrough)) {
            /* Generate interface profile */
            if (nrough < 3) nrough = 11;
            if (proftyp[0] == 'H')
               gentanh(nrough, zint, rufint);
            else
               generf(nrough, zint, rufint);
         }

      /* Specify error function or hyperbolic tangent profile */
      } else if (strcmp(command, "PR") == 0) {
         setProfile(proftyp, PROFTYPLEN + 2);

      /* Range of Q to be scanned */
      } else if (strcmp(command, "QL") == 0) {
         if (!setQrange(&qmin, &qmax)) {
            qmina = qmin;
            qmaxa = qmax;
            qminb = qmin;
            qmaxb = qmax;
            qminc = qmin;
            qmaxc = qmax;
            qmind = qmin;
            qmaxd = qmax;
         }

      /* Number of points scanned */
      } else if (strcmp(command, "NP") == 0) {
         if (!setNpnts(&npnts)) {
            npntsa = npnts;
            npntsb = npnts;
            npntsc = npnts;
            npntsd = npnts;
         }

      /* File for input data */
      } else if (strcmp(command, "IF") == 0) {
         setFilename(infile, INFILELEN + 2);

      /* File for output data */
      } else if (strcmp(command, "OF") == 0) {
         setFilename(outfile, OUTFILELEN + 2);

      /* File for parameters */
      } else if (strcmp(command, "PF") == 0) {
         setFilename(parfile, PARFILELEN + 2);

      /* Polarization state */
      } else if (strcmp(command, "PS") == 0) {
         setPolstat(polstat, POLSTATLEN + 2);

      /* Beam intensity */
      } else if (strcmp(command, "BI") == 0) {
         setBeamIntens(&bmintns, &Dbmintns);

      /* Background intensity */
      } else if (strcmp(command, "BK") == 0) {
         setBackground(&bki, &Dbki);

      /* Verify parameters by printing out */
      } else if (strncmp(command, "VE", 2) == 0) {
         printLayers(command);

      /* Get data from file */
      } else if (strcmp(command, "GD") == 0) {
         loadData(infile, xspin);

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
         loadParms(command, parfile, constrainScript, constrainModule);

      /* Save parameters to parameter file */
      } else if (strcmp(command, "SP") == 0) {
         parms(qcsq, qcmsq, d, dm, rough, mrough, mu, the,
               MAXLAY, &lambda, &lamdel, &thedel, &aguide,
              &nlayer, &qmina, &qmaxa, &npntsa,
              &qminb, &qmaxb, &npntsb, &qminc, &qmaxc, &npntsc,
              &qmind, &qmaxd, &npntsd,
               infile, outfile,
              &bmintns, &bki, listA, &mfit, NA, &nrough, proftyp,
               polstat, DA, constrainScript, parfile, TRUE);

      /* List data and fit */
      } else if (strcmp(command, "LID") == 0) {
         listData();

      /* Generate logarithm of bare (unconvoluted) reflectivity */
      /* or generate reflected amplitude */
      } else if (strcmp(command,"GR") == 0 || strcmp(command, "GA") == 0) {
         genReflect(command);

      /* Generate and display layer profile */
      } else if (
         strcmp(command, "GLP") == 0 ||
         strncmp(command, "SLP", 3) == 0
      ) {
         genProfile(command);

      /* Save values in Q4X and YFIT to OUTFILE */
      } else if (strcmp(command, "SV") == 0) {
         saveTemps(outfile, xspin, y4x, n4x, FALSE);

      /* Save values in Q4X and YFITA to OUTFILE */
      } else if (strcmp(command, "SVA") == 0) {
         saveTemps(outfile, xspin, yfita, n4x, TRUE);

      /* Calculate derivative of reflectivity or spin asymmetry with respect */
      /* to a fit parameter or save a fit to disk file */
      } else if (
         strcmp(command, "RD") == 0 ||
         strcmp(command, "SRF") == 0
      ) {
         printDerivs(command, npnts);

      /* Turn off all varied parameters */
      } else if (strcmp(command, "VANONE") == 0) {
         clearLista(listA);

      /* Specify which parameters are to be varied in the reflectivity fit */
      } else if (strncmp(command, "VA", 2) == 0) {
         varyParm(command);

      /* Calculate chi-squared */
      } else if (
         strcmp(command, "CSR") == 0 ||
         strcmp(command, "CS") == 0
      ) {
         calcChiSq(command);

      /* Fit reflectivity */
      } else if (strncmp(command, "FR", 2) == 0) {
         for (j = 0; j < NA; j++) {
            undoFit[j] = A[j];
            undoFitUnc[j] = DA[j];
         }
         fitReflec(command);

      /* Undo last fit */
      } else if (strcmp(command, "UF") == 0) {
         for (j = 0; j < NA; j++) {
            A[j] = undoFit[j];
            DA[j] = undoFitUnc[j];
         }

      /* Exit */
      } else if (
         strcmp(command, "EX") == 0 ||
         strcmp(command, "EXS") == 0
      ) {
         parms(qcsq, qcmsq, d, dm, rough, mrough, mu, the,
               MAXLAY, &lambda, &lamdel, &thedel, &aguide,
              &nlayer, &qmina, &qmaxa, &npntsa,
              &qminb, &qmaxb, &npntsb, &qminc, &qmaxc, &npntsc,
              &qmind, &qmaxd, &npntsd,
               infile, outfile,
              &bmintns, &bki, listA, &mfit, NA, &nrough, proftyp,
               polstat, DA, constrainScript, parfile, TRUE);
         /* Print elapsed CPU time */
         if (strcmp(command, "EXS") == 0) system("ps");
         exit(0);

      /* Exit without saving changes */
      } else if (strcmp(command, "QU") == 0 || strcmp(command, "QUIT") == 0) {
         exit(0);

      /* Plot reflectivity on screen */
      } else if (strncmp(command, "PRF", 3) == 0) {
         plotfit(command, xspin);

      /* Plot profile on screen */
      } else if (strncmp(command, "PLP", 3) == 0) {
         plotprofile(command, xspin);

      /* Plot movie of reflectivity change from fit */
      } else if (strncmp(command, "MVF", 3) == 0) {
         fitMovie(command, xspin, undoFit);

      /* Plot general movie from data file on screen */
      } else if (strncmp(command, "MVX", 3) == 0) {
         arbitraryMovie(command, xspin);

      /* Plot movie of parameter on screen */
      } else if (strncmp(command, "MV", 2) == 0) {
         oneParmMovie(command, xspin);

      /* Update constraints */
      } else if (strcmp(command, "UC") == 0) {
         genshift(a, TRUE);
         /* constrain(a); */
         (*Constrain)(FALSE, a, nlayer);
         genshift(a, FALSE);

      /* Determine number of points required for resolution extension */
      } else if (strcmp(command, "RE") == 0) {
         calcExtend(xspin);

#if 0 /* Dead code --- shadowed by "CD" command earlier */
      /* Convolute input raw data set with instrumental resolution */
      } else if (strcmp(command, "CD") == 0) {
         calcConvolve(polstat);
#endif

      /* Send data to other processes. */
      } else if (strcmp(command, "SEND") == 0) {
	ipc_send(command);

      /* Receive data to other processes. */
      } else if (strcmp(command, "RECV") == 0) {
	ipc_recv(command);

      /* Faulty input */
      } else
         ERROR("/** Unrecognized command **/");
}


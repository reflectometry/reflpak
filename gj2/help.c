#include <stdio.h>
#include <stdlib.h>
#include <help.h>
#include <queryString.h>
#include <caps.h>
#include <defStr.h>

#include <parameters.h>
#include <cparms.h>

/* Local function prototypes */
#include <static.h>

STATIC const char *dumplines(const char *string, int maxlines, FILE *stream);
STATIC const char *pageBack(const char *string, const char *top, int lines);
STATIC int pageHelp(const char *helpText, char *pager);

/* Module variables */
#define BANNERLINES 4
#define SCREENLINES 22

static const char *helpstring =
"-------------------------------------------------------------------------------\n"
"      Edit Parameters\n"
"-------------------------------------------------------------------------------\n"
" Layer-independent parameters\n"
" AL     Add a layer between existing layers.\n"
"\n"
" CL     Copy parameters from one layer to another.\n"
"\n"
" RL     Remove a layer between existing layers.\n"
"\n"
" SL     Create a superlattice from a specified range of layers.\n"
"\n"
" NL     Enter number of layers (between 1 and " STR(MAXLAY) ").\n"
"\n"
" NP     Enter number of data points (automatically done by GD).\n"
"\n"
" NR     Enter number of layers used to simulate rough interface (greater\n"
"        than 2).\n"
"\n"
" PR     Enter profile shape for simulated roughness.\n"
"\n"
" PS     Enter polarization states to use.\n"
"\n"
" QL     Enter Q limits of data set (automatically done by GD).\n"
"\n"
" BI     Enter intensity of incident beam (multiplies calculated\n"
"        reflectivity to give count rate).\n"
"\n"
" BK     Enter constant background intensity added to calculated\n"
"        intensity.\n"
"\n"
" DL     Enter the wavelength divergence of the incident beam (in\n"
"        Angstroms) to be used in the resolution convolution.\n"
"\n"
" DT     Enter the angular divergence of the incident beam (in radians)\n"
"        to be used in the resolution convolution.\n"
"\n"
" VMU\n"
" MUV    Enter the length absorption coefficient of the vacuum.\n"
"\n"
" VQC\n"
" QCV    Enter critical Q squared of the vacuum.\n"
"\n"
" VQM\n"
" QMV    Enter magnetic critical Q squared of the vacuum.\n"
"\n"
" WL     Enter wavelength of incident radiation.\n"
"\n"
" Layer-specific parameters\n"
" Dn     Enter thickness of nth chemical layer.\n"
"\n"
" DMn    Enter thickness of nth magnetic layer\n"
"\n"
" MUn    Enter the length absorption coefficient for chemical layer n.\n"
"\n"
" QCn    Enter nuclear (or x-ray) critical Q squared of chemical layer n.\n"
"\n"
" QMn    Enter magnetic critical Q squared of magnetic layer n.\n"
"\n"
" RMn    Enter interfacial roughness at top of magnetic layer n.\n"
"\n"
" ROn    Enter interfacial roughness at top of chemical layer n.\n"
"\n"
" THn    Enter the angle (in degrees) in the plane for the moment in\n"
"        magnetic layer n.  A value of 0 corresponds to the incident beam\n"
"        direction.\n"
"\n\f"
"-------------------------------------------------------------------------------\n"
"      Fitting Commands\n"
"-------------------------------------------------------------------------------\n"
" CS\n"
" CSR    Calculate chi-squared for logarithm of reflectivity.\n"
"\n"
" FR     Fit logarithm of reflectivity to data stored in IF.\n"
"\n"
" FRM    Fit logarithm of reflectivity to data stored in IF and plot a\n"
"        movie of the fit as it progresses.  Append A, B, C or D to watch\n"
"        only the specified cross-sections.\n"
"\n"
" UF     Restore parameters and uncertainties to values just before the last\n"
"        fit.\n"
"\n"
" RE     Determine number of points required for resolution extension\n"
"        (automatically done whenever necesssary).\n"
"\n"
" EC     Edit constraints found in the file entered using PF command.\n"
"        A new constrain module is created and loaded (automatically done\n"
"        when the program runs).\n"
"\n"
" LC     Reload the constrain module.  The module is not rebuilt, only\n"
"        reloaded.\n"
"\n"
" UC     Update constraints (automatically done whenever necessary).\n"
"\n"
" ULC    Unload the constrain module and revert to no constraints.\n"
"\n"
" VAnm   Toggle status of nmth fit parameter.  Toggles between varied and\n"
"        fixed in the fit.  Specify nm as you would for entering its value.\n"
"\n"
" VANONE Turn off all varied parameters\n"
"\n\f"
"-------------------------------------------------------------------------------\n"
"      Execute Commands\n"
"-------------------------------------------------------------------------------\n"
" Input/output commands\n"
"\n"
" EX     Exit the program and save parameters and constraints to file entered\n"
"        using PF command.\n"
"\n"
" EXS    Exit the program as with EX and print elapsed CPU time\n"
"\n"
" QU     Exit without saving changes to parameter file entered with PF.\n"
"\n"
" !      Spawn a command.  Enter the command at the prompt.\n"
"\n"
" !!     Spawn a subshell.\n"
"\n"
" CD     Change current directory.  Tilde (~) expansion is performed.\n"
"\n"
" PWD    Print current directory.\n"
"\n"
" IF     Enter name of input file.\n"
"\n"
" OF     Enter output file name.\n"
"\n"
" PF     Enter parameter file name.  Default is taken from commandline\n"
"        argument.  Default is gmagblocks4.sta if none given.\n"
"\n"
" LP     Load parameters from file entered using PF command without the\n"
"        constraints from that file.  This command resets the uncertainties.\n"
"\n"
" LPC    Load parameters from file entered using PF command and use the\n"
"        constraints from that file (automaticallly done when program runs).\n"
"        This command resets the uncertainties.\n"
"\n"
" SP     Save parameters to parameter file entered with PF.\n"
"\n"
" GD     Get data from filename entered using IF command.  The data is\n"
"        assumed to be in three-column format with the first column being\n"
"        the momentum transfer (Q=4 PI sin THETA/LAMBDA), the second\n"
"        column either the logarithm of the counts, and the third column\n"
"        the uncertainty (error bar).  If the first character in the line\n"
"        is #, the line is not read.\n"
"\n"
/*" CD     Convolute input raw data set with instrumental resolution\n"
"\n" */
" SLP    Generate and print layer profile.  Append A, B, C, or D to \n"
"        generate scattering density for the specified cross-section.\n"
"        Append O to generate separate magnetic and chemical profiles\n"
"        before their integration into a common profile.  SLP saves\n"
"        into file entered by OF (or IF if not yet given) with extension\n"
"        .proC where C is n, m, t, a, b, c, d, N or M.\n"
"\n"
" SRF    Save fit to log(reflectivity) in file name entered in OF.\n"
"        Written in two-column format:  first column is Q=4 PI *\n"
"        sin THETA/LAMBDA, second is fit.\n"
"\n"
" SV     Save values in Q4X and YFIT to file entered with OF with the\n"
"        extension .genC where C is a, b, c or d.\n"
"\n"
" SVA    Save values in Q4X and YFITA to file entered with OF with the\n"
"        extension .genC where C is a, b, c or d.\n"
"\n"
" Display commands\n"
" ?\n"
" HE     Prints this help.\n"
"\n"
" VE     Print out current values of all fit parameters on screen.  Append\n"
"        U to print uncertainties of the fit parameters.\n"
"\n"
" VEM    Print out current values of magnetic fit parameters on screen.\n"
"        Append U to print uncertainties of the magnetic fit parameters.\n"
"\n"
" LID    List the data entered by GD and the fit generated by any of the\n"
"        fit commands.\n"
"\n"
" GR     Generate unconvoluted logarithm of reflectivity.\n"
"\n"
" GA     Generate unconvolved complex amplitude of reflectivity.\n"
"\n"
" GLP    Generate and display layer profile.\n"
"\n"
" RD     Calculate log(reflectivity). \n"
"\n"
"-------------------------------------------------------------------------------\n"
" Plotting commands\n"
"-------------------------------------------------------------------------------\n"
" PLP    Plot profile on screen.  Default is chemical and magnetic.\n"
"        Append N for nuclear only; M for magnetic only; T for magnetic\n"
"        angle.  Append A, B, C, or D for scattering density for the\n"
"        specified cross-sections.  Append S for scattering density for\n"
"        the cross-sections specified in PS.  Data are saved in file\n"
"        mltmp.prC where C is n, m, t, a, b, c, or d.\n"
"\n"
" PRF    Plot reflectivity on screen.  Append A, B, C, or D for specific\n"
"        cross-sections.  Default uses value from PS.\n"
"\n"
" MVc    Enter a parameter name and watch as the reflectivity varies with\n"
"        that parameter.  Choose c to be one of R, D, I, S, or P.  R plots\n"
"        the reflectivities, D plots the ratio of successive frames to the\n"
"        first frame, I plots the ratio of successive frames, S plots the\n"
"        scattering densities, and P plots the nuclear, magnetic, and\n"
"        magnetic angle profile.  S is the default.  Append A, B, C or D\n"
"        for specific cross-sections.  Default uses value from PS.\n"
"\n"
" MVFc   Plots a movie of the last fit progression.  Choose c as in MV.\n"
"        Append A, B, C or D for specific cross-sections.  Default uses\n"
"        value from PS.\n"
"\n"
" MVXc   Plots a movie of parameters tabulated in a file.  Choose c as in\n"
"        MV.  Append A, B, C or D for specific cross-sections.  Default uses\n"
"        value from PS.  The file is formatted with a line that begins\n"
"        with # followed by a list of parameters to vary, separated with\n"
"        spaces.  The following lines (1 per frame) list the values to use\n"
"        for each respective parameter, again seperated with spaces.\n"
;

STATIC int pageHelp(const char *helpText, char *pager)
{
   int failed = TRUE;
   FILE *Pager;

   if (pager != NULL) {
      Pager = popen(pager, "w");
      if (Pager != NULL) {
         fputs(helpText, Pager);
         if (!ferror(Pager)) {
            putc('\n', Pager);
            if (!ferror(Pager) && pclose(Pager) == 0) {
               failed = FALSE;
            }
         }
      }   
   }
   return failed;
}


void help(char *command)
{
   register const char *text;
   register int lines;
   int screenlines = 0;
   char *string;

   /* Check if PAGER exists, and can be run */
   if (pageHelp(helpstring, getenv("PAGER"))) {

      /* Set lines per screen */
      string = getenv("LINES");
      if (string != NULL) screenlines = atoi(string);
      if (screenlines < 2) screenlines = SCREENLINES;

      text = helpstring;
      lines = screenlines;
      while (*text != 0) {
         text = dumplines(text, lines, stdout);
         lines = screenlines;
         string = queryString("\nEnter Q to quit, "
                                "J = down 1 line, "
                                "K = up 1 line, "
                                "B pages up, "
                                "others page down.", NULL, 0);
         if (string) {
            caps(string);
            if (*string == 'Q') break;
            switch (*string) {
               case 'J':
                  text = pageBack(text, helpstring, screenlines);
                  lines++;
                  break;
               case 'K':
                  text = pageBack(text, helpstring, 1 + screenlines);
                  break;
               case 'B':
                  text = pageBack(text, helpstring, 2 * screenlines);
                  break;
            }
         }
      }
   }
}


STATIC const char *dumplines(register const char *string, register int maxlines, FILE *stream)
{
   if (*string == '\f') string++; /* Ignore formfeed at top of page */
   while (*string != 0 && *string != '\f' && maxlines != 0) {
      putc (*string, stream);
      if (*(string++) == '\n') maxlines--;
   }
   if (*string == '\f') {
      for (;maxlines != 0; maxlines--) putc('\n', stream);
      string++;
   }
   return string;
}


STATIC const char *pageBack(register const char *string,
   register const char *top, register int lines)
{
   lines++;
   while (string > top && lines > 0) {
      --string;
      if (*string == '\n') lines--;
      if (*string == '\f') lines++;
   }
   if (string > top) string++; /* First character after newline */
   return string;
}


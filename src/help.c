#include <stdio.h>
#include <stdlib.h>
#include <help.h>
#include <queryString.h>
#include <caps.h>

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

/* To let values of #defines be placed into strings. (Use second one) */
#define XSTR(x) #x
#define STR(x) XSTR(x)

static const char *helpstring =
"-------------------------------------------------------------------------------\n"
"      Edit Parameters\n"
"-------------------------------------------------------------------------------\n"
" Layer-independent parameters\n"
" NcL    Enter number of layers for region c (between 1 and " STR(MAXLAY) ").\n"
"        Set c to T for top, M for middle and B for bottom.\n"
"\n"
" AcL    Add a layer between existing layers in a region.\n"
"        Set c to T for top, M for middle and B for bottom.\n"
"\n"
" RcL    Remove a layer between existing layers.\n"
"        Set c to T for top, M for middle and B for bottom.\n"
"\n"
" CL     Copy parameters from one layer in any region to another layer in\n"
"        any region.\n"
"\n"
" NMR    Enter the number of repeats of the middle region to make a\n"
"        superlattice.  Note: the bottom of the top region and the top of\n"
"        the bottom region must each be set to one repeat if NMR is\n"
"        greater than 1 for the profile to be constructed correctly.\n"
"\n"
" NP     Enter number of data points (automatically done by GD).\n"
"\n"
" NR     Enter number of layers used to simulate rough interface (greater\n"
"        than 2).\n"
"\n"
" PR     Enter profile shape for simulated roughness.\n"
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
" rDn    Enter thickness of nth chemical layer in region r.\n"
"\n"
" rMUn   Enter the length absorption coefficient for nth chemical layer in\n"
"        region r.\n"
"\n"
" rQCn   Enter x-ray (or nuclear) critical Q squared of nth chemical layer\n"
"        in region r.\n"
"\n"
/*" rQMn   Enter magnetic critical Q squared of nth magnetic layer in region\n"*/
/*"           r.\n"*/
/*"\n"*/
" rROn   Enter interfacial roughness at top of nth chemical layer in region\n"
"        r.\n"
"\n\f"
"-------------------------------------------------------------------------------\n"
"      Fitting Commands\n"
"-------------------------------------------------------------------------------\n"
" CSR    Calculate chi-squared for logarithm of reflectivity.  Append S to\n"
"        calculate chi-squared for the spin asymmetry.\n"
"\n"
" FR     Fit logarithm of reflectivity to data stored in IF.  Append S to\n"
"        fit the spin asymmetry.  Append M to plot a movie of the fit as\n"
"        it progresses.\n"
"\n"
" UF     Restore parameters and uncertainties to values just before the last\n"
"        fit.\n"
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
"        argument.  Default is mlayer.staj if none given.\n"
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
"        column either the logarithm of the counts or the spin asymmetry,\n"
"        and the third column the uncertainty (error bar).  If the first\n"
"        character in the line is #, the line is not read.\n"
"\n"
" SA     Generate and print unconvolved complex amplitude of reflectivity.\n"
"        The data are saved into file entered by OF.\n"
"\n"
" SLP\n"
" SSP    Generate and print layer profile.  The data are saved into file\n"
"        entered by OF (or IF if not yet given) with extension .pro\n"
"        SLP saves the critical angle in histogram form.  SSP saves scaled\n"
"        critical angle and absorption in table form.\n"
"\n"
" SRF    Save fit to log(reflectivity) in file name entered in OF with\n"
"        extensinon .fit.  Written in two-column format:  first column is\n"
"        Q=4 PI sin THETA/LAMBDA, second is fit.\n"
"\n"
" SRSF   Save fit to spin asymmetry in file name entered in OF with\n"
"        extension .fit.  Written in two-column format:  first column is\n"
"        Q=4 PI sin THETA/LAMBDA, second is fit.\n"
"\n"
" SV     Save values in XTEMP and YTEMP to file entered with OF.\n"
"\n"
" Display commands\n"
" ?\n"
" HE     Prints this help.\n"
"\n"
" VE     Print out current values of all fit parameters on screen.  Append\n"
"        U to print uncertainties of the fit parameters.\n"
"\n"
" VcE    Print out current values of only the fit parameters of layers\n"
"        specified by c on screen.  Set c to T for top, M for middle and\n"
"        B for bottom.  Append U to print uncertainties of the fit\n"
"        parameters.\n"
"\n"
" LID    List the data entered by GD and the fit generated by any of the\n"
"        fit commands.\n"
"\n"
" GR     Generate unconvoluted logarithm of reflectivity.\n"
"\n"
" GLP    Generate and display layer profile.\n"
"\n"
" RD     Calculate log(reflectivity) or derivative with respect to a\n"
"        specified parameter. \n"
"\n"
" RSD    Calculate spin asymmetry or derivative with respect to a\n"
"        specified parameter. \n"
"\n"
"-------------------------------------------------------------------------------\n"
" Plotting commands\n"
"-------------------------------------------------------------------------------\n"
" PLP    Plot profile on screen.  Data are saved in file mltmp.pro\n"
"\n"
" PRF    Plot reflectivity on screen.  Data are saved in file mltmp.fit\n"
"\n"
" MVc    Enter a parameter name and watch as the reflectivity varies with\n"
"        that parameter.  Choose c to be one of R, D, I or P.  R plots the\n"
"        reflectivity, D plots the ratio of successive frames of reflectivity\n"
"        to the first frame, I plots the ratio of successive frames, P plots\n"
"        the profile, and is the default.\n"
"\n"
" MVFc   Plots a movie of the last fit progression.  Choose c as in MV.\n"
"\n"
" MVXc   Plots a movie of parameters tabulated in a file.  Choose c as in\n"
"        MV.  The file is formatted with a line that begins with # followed\n"
"        by a list of parameters to vary, separated with spaces.  The\n"
"        following lines (1 per frame) list the values to use for each\n"
"        respective parameter, again separated with spaces.\n"
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


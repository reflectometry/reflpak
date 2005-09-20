/* Subroutine parses the VAry command to determine which parameter
   to vary in the least-squares fit, returning parameter number NC
   John Ankner 3-July-1990 */

#include <stdlib.h>
#include <string.h>
#include <parseva.h>
#include <parameters.h>

/* Local function prototypes */
#include <static.h>

STATIC int fetchLayNum(char *command, int nc);


int parseva(char *command)
{
   int nc;

   nc = 0;

   /* Check for background and beam intensity */
   if (strncmp(command, "BK", 2) == 0)
      nc = NA - 1;
   else if (strncmp(command, "BI", 2) == 0)
      nc = NA;

   /* Check for vacuum layer */
   else if (strncmp(command, "VQC", 3) == 0)
      nc = 1;
   else if (strncmp(command, "VMU", 3) == 0)
      nc = 2*MAXLAY + 1;

   /* Check for numbered variables (note the ordering in the large
      group of equivalence statements in subroutine GENSHIFT and
      compare to that in main program) */

   /* Parse for command group */
   else if (
      command[0] == 'T' ||
      command[0] == 'M' ||
      command[0] == 'B'
   ) {
      if (command[0] == 'M') nc += MAXLAY * NUMPARAMS;
      if (command[0] == 'B') nc += 2 * MAXLAY * NUMPARAMS;

      /* Parse for two-character command */
      if (
         strncmp(command + 1, "QC", 2) == 0 ||
         strncmp(command + 1, "RO", 2) == 0 ||
         strncmp(command + 1, "QM", 2) == 0 ||
         strncmp(command + 1, "MU", 2) == 0
      ) {
         if (strncmp(command + 1, "QM", 2) == 0) nc += MAXLAY;
         if (strncmp(command + 1, "MU", 2) == 0) nc += 2 * MAXLAY;
         if (strncmp(command + 1, "RO", 2) == 0) nc += 4 * MAXLAY;
         /*  Parse for layer number */
         nc = fetchLayNum(command + 3, nc);

      /* Parse for one-character command */
      } else if (command[1] == 'D') {
         nc += 3 * MAXLAY;
         /* Parse for layer number */
         nc = fetchLayNum(command + 2, nc);
      } else
         /* Invalid input */
         nc = -1;

   } else
      /* Invalid input */
      nc = -1;

   return nc - 1;
}


STATIC int fetchLayNum(char *command, int nc)
{
   int nl;

   nl = atoi(command) + 1;
   if (nl >= 2 && nl <= MAXLAY)
      nc += nl;
   else
      /* Invalid input */
      nc = -1;

   return nc;
}


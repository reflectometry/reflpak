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
   int nc = 0;

   /* Check for background and beam intensity */
   if (strncmp(command, "BK", 2) == 0)
      nc = NA - 1;
   else if (strncmp(command, "BI", 2) == 0)
      nc = NA;

   /* Check for numbered variables (note the ordering in the large
      group of equivalence statements in subroutine GENSHIFT and
      compare to that in main program) */


   /* Parse for two-character command */
   else if (
      strncmp(command, "QC", 2) == 0 ||
      strncmp(command, "QM", 2) == 0 ||
      strncmp(command, "MU", 2) == 0 ||
      strncmp(command, "DM", 2) == 0 ||
      strncmp(command, "RM", 2) == 0 ||
      strncmp(command, "RO", 2) == 0 ||
      strncmp(command, "TH", 2) == 0
   ) {
      if (strncmp(command, "QM", 2) == 0) nc += MAXLAY;
      if (strncmp(command, "MU", 2) == 0) nc += 2 * MAXLAY;
      if (strncmp(command, "DM", 2) == 0) nc += 4 * MAXLAY;
      if (strncmp(command, "RO", 2) == 0) nc += 5 * MAXLAY;
      if (strncmp(command, "RM", 2) == 0) nc += 6 * MAXLAY;
      if (strncmp(command, "TH", 2) == 0) nc += 7 * MAXLAY;
      /* Parse for layer number */
      nc = fetchLayNum(command + 2, nc);
   /* Parse for one-character command */
   } else if (command[0] == 'D') {
      nc += 3 * MAXLAY;
      /* Parse for layer number */
      nc = fetchLayNum(command + 1, nc);

   } else
      nc = -1;

   return nc - 1;
}


STATIC int fetchLayNum(char *command, int nc)
{
   int nl = 0;

   nl = atoi(command) + 1;
   if (nl > 1 && nl <= MAXLAY)
      nc += nl;
   else
      /* Invalid input */
      nc = -2;

   return nc;
}


/* Informs user of incorrect input */

/* Called by MLAYER, PRINTINFO and GETPARAMS */

#include <stdio.h>
#include <badInput.h>

/* Module variables */
static const char *nulltext = "(null)";

void badInput(char *text)
{
   if (text == NULL) text = (char *)nulltext;
   printf("/** Invalid input: %s **/\n", text);
}


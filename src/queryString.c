/* Retrieves a line of input from user and erases terminating newline */

#include <stdio.h>
#include <string.h>
#include <cparms.h>
#include <queryString.h>

/* Module data */
static char buffer[FBUFFLEN];

extern double *xdat;

char *queryString(char *prompt, char *string, int length)
{
   if (string == NULL || length == 0) {
      string = buffer;
      length = FBUFFLEN;
   }

   if (prompt != NULL) { fputs(prompt, stdout); fflush(stdout); }
   fgets(string, length, stdin);
   /* Remove trailing linefeed */
   string[strlen(string) - 1] = 0;
   return (*string == 0) ? NULL : string;
}


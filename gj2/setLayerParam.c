#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <setLayerParam.h>
#include <queryString.h>
#include <caps.h>
#include <badInput.h>
#include <parseva.h>

#include <cparms.h>
#include <genpsd.h>

/* Module variables */
#define INPUTLEN 256

int setLayerParam(double *data, double *unc, char *prompt)
{
   int failed = FALSE, nc;
   char *string, *stopChar;
   double value;
   static char textbuf[INPUTLEN];

   sprintf(textbuf, "Enter %s: ", prompt);
   string = caps(queryString(textbuf, NULL, 0));
   if (string) {
      value = strtod(string, &stopChar);
      if (*stopChar != 0 && !isspace(*stopChar)) {
         nc = parseva(string);
         if (nc >= 0 && nc < NA) {
            *data = A[nc];
            *unc = 0.0;
         } else {
            badInput(string);
            failed = TRUE;
         }
      } else {
         *data = value;
         *unc = 0.0;
      }
   }
   return failed;
}


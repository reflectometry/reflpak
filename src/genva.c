/* Subroutine produces character string containing list of fitted parameters
   for use in the TVE, MVE, and BVE statements
   John Ankner 10 December 1990 */

#include <string.h>
#include <genva.h>
#include <parameters.h>

void genva(int lista[], int mfit, char *fitlist)
{
   int lchar, nleft;
   int j;

   /* Loop through fit parameters */
   strcpy(fitlist, " ");
   lchar = 1;
   for (j = 0; j < mfit; j++) {
      /* Construct first characters in string */
      if (lista[j] < MAXLAY * NUMPARAMS) {
         strcat(fitlist, " T");
         lchar += 2;
         nleft = lista[j];
      } else if (lista[j] < 2 * MAXLAY * NUMPARAMS) {
         strcat(fitlist, " M");
         lchar += 2;
         nleft = lista[j] - MAXLAY * NUMPARAMS;
      } else if (lista[j] < 3 * MAXLAY * NUMPARAMS) {
         strcat(fitlist, " B");
         lchar += 2;
         nleft = lista[j] - 2 * MAXLAY * NUMPARAMS;
      } else if (lista[j] == NA - 2) {
         strcat(fitlist, " BK");
         lchar += 3;
         nleft = -1;
      } else if (lista[j] == NA - 1) {
         strcat(fitlist, " BI");
         lchar += 3;
         nleft = -1;
      }
      /* Construct remainder of phrase */
      if (nleft >= 4 * MAXLAY) {
         strcat(fitlist, "RO");
         fitlist[lchar + 2] = (char) (nleft - 4 * MAXLAY + '0');
         fitlist[lchar + 3] = 0;
         lchar += 3;
      } else if (nleft >= 3 * MAXLAY) {
         strcat(fitlist, "D");
         fitlist[lchar + 1] = (char) (nleft - 3 * MAXLAY + '0');
         fitlist[lchar + 2] = 0;
         lchar += 2;
      } else if (nleft >= 2 * MAXLAY) {
         strcat(fitlist, "MU");
         fitlist[lchar + 2] = (char) (nleft - 2 * MAXLAY + '0');
         fitlist[lchar + 3] = 0;
         lchar += 3;
      } else if (nleft >= MAXLAY) {
         strcat(fitlist, "QM");
         fitlist[lchar + 2] = (char) (nleft - MAXLAY + '0');
         fitlist[lchar + 3] = 0;
         lchar += 3;
      } else if (nleft >= 0) {
         strcat(fitlist, "QC");
         fitlist[lchar + 2] = (char) (nleft + '0');
         fitlist[lchar + 3] = 0;
         lchar += 3;
      }
   }
}


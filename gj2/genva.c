/* Subroutine produces character string containing list of fitted parameters */
/* for use in the VE statement */
/* John Ankner 28 March 1992 */

#include <string.h>
#include <stdio.h>
#include <genva.h>

#include <parameters.h>

void genva(int lista[], int mfit, char *fitlist)
/* int lista[mfit]; */
{
   int lchar, nleft, ll;
   char *startOfLine;
   register int j;

   /* Loop through fit parameters */
   strcpy(fitlist, " ");
   lchar = 1;
   for (j = 0; j < mfit; j++) {
      if (lista[j] == NA - 2) {
         strcat(fitlist, " BK");
         lchar += 3;
         nleft = -1;
      } else if (lista[j] == NA - 1) {
         strcat(fitlist, " BI");
         lchar += 3;
         nleft = -1;
      } else if (lista[j] > 7 * MAXLAY) {
         nleft = lista[j] - 7 * MAXLAY;
         strcat(fitlist, " TH");
         lchar += 3;
      } else if (lista[j] > 6 * MAXLAY) {
         nleft = lista[j] - 6 * MAXLAY;
         strcat(fitlist, " RM");
         lchar += 3;
      } else if (lista[j] > 5 * MAXLAY) {
         nleft = lista[j] - 5 * MAXLAY;
         strcat(fitlist, " RO");
         lchar += 3;
      } else if (lista[j] > 4 * MAXLAY) {
         nleft = lista[j] - 4 * MAXLAY;
         strcat(fitlist, " DM");
         lchar += 3;
      } else if (lista[j] > 3 * MAXLAY) {
         nleft = lista[j] - 3 * MAXLAY;
         strcat(fitlist, " D");
         lchar += 2;
      } else if (lista[j] > 2 * MAXLAY) {
         nleft = lista[j] - 2 * MAXLAY;
         strcat(fitlist, " MU");
         lchar += 3;
      } else if (lista[j] > MAXLAY) {
         nleft = lista[j] - MAXLAY;
         strcat(fitlist, " QM");
         lchar += 3;
      } else {
         nleft = lista[j];
         strcat(fitlist, " QC");
         lchar += 3;
      }
      /* Generate layer number, if required */
      if (nleft > 0 && nleft < MAXLAY)
         lchar += sprintf(fitlist + strlen(fitlist), "%d", nleft);
   }
   /* Break list into 70 character segments */
   for (
      startOfLine = fitlist;
      startOfLine <= fitlist + lchar - 70;
      startOfLine += ll
   ) {
      for (ll = 70; ll > 0 && startOfLine[ll] != ' '; ll--);
      startOfLine[ll++] = '\n';
   }
}


/* Calculates step widths for interfacial diffusion */

#include <calcStep.h>

void calcStep(double zint[], int nrough)
{
   register double ohalfstep, ztemp;
   register int j;

   /* Take derivative of zint */
   /* For first and last point use 2-point slope */
   /* For other points average the slope left and right */

   ohalfstep = .5 * (zint[1] - zint[0]);
   for (j = 0; j < nrough; j++) {
      ztemp = zint[j];
      zint[j] = ohalfstep + .5 * (zint[j + 1] - zint[j]);
      ohalfstep = .5 * (zint [j + 1] - ztemp);
   }
   /* Last point */
   zint[j] = 2 * ohalfstep;
}


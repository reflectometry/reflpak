/* Implements constraints in model */

#include <constrain.h>
#include <parameters.h>

const char *noconstraints_SCCS_Verinfo = "@(#)equalmagnucthick	version 1.0	02/28/2000";
long int mlayerid = GJ2COMPAT | 4;

void constrain(double a[], int nlayer)
{
/* Chemical and magnetic thickness equal */
   a[DM + 3] = a[D + 2] + a[D + 3] - a[DM + 2];
   a[DM + 4] = a[D + 5] + a[D + 4] - a[DM + 5];

/* Set magnetic roughnesses equal to thickness */
   if (a[RM + 2] > a[DM + 2]) a[RM + 2] = a[DM + 2];
   if (a[RM + 3] > a[DM + 3]) a[RM + 3] = a[DM + 3];
   if (a[RM + 5] > a[DM + 5]) a[RM + 5] = a[DM + 5];
   if (a[RM + 4] > a[DM + 4]) a[RM + 4] = a[DM + 4];

/* Match theta */
   a[TH + 1] = a[TH + 2];
   a[TH + nlayer] = a[TH + nlayer - 1];
   /* a[TH + 4] = a[TH + 3]; */

}


/* Shift reflectivity generating parameters to fit parameters A
   and vice versa
   John Ankner 3-July-1990 */

#include <math.h>
#include <string.h>
#include <genshift.h>

void genshift(double afit[], int gen_to_fit)
{

#include <parameters.h>
#include <genpsd.h>

/* Prevent non-positive intensities */
   if (fabs(A[NA - 3]) < 1.e-10) A[NA - 3] = 1.e-10;
   if (fabs(A[NA - 2]) < 1.e-10) A[NA - 2] = 1.e-10;
   if (fabs(afit[NA - 3]) < 1.e-10) afit[NA - 3] = 1.e-10;
   if (fabs(afit[NA - 2]) < 1.e-10) afit[NA - 2] = 1.e-10;

/* Perform transfer */
    if (gen_to_fit)
      memcpy(afit, A, NA * sizeof(double));
    else
      memcpy(A, afit, NA * sizeof(double));
}


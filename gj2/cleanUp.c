/* Cleans up dynamic allocations before exiting */

#include <unistd.h>
#include <cleanUp.h>
#include <cleanFree.h>
#include <dlconstrain.h>

#include <genmem.h>
#include <genpsr.h>
#include <genpsi.h>
#include <genpsc.h>
#include <cdata.h>

void cleanUp(void)
{
   closeLib();
   cleanFree((void **) (&qtemp));
   cleanFree((void **) (&y));
   cleanFree((void **) (&dy));
   cleanFree((void **) (&ymod));
   cleanFree((void **) (&dyda));

   cleanFree((void **) (&xdat));
   cleanFree((void **) (&ydat));
   cleanFree((void **) (&srvar));
   cleanFree((void **) (&yfit));
   cleanFree((void **) (&yfita));

   cleanFree((void **) nqx);
   cleanFree((void **) (nqx+1));
   cleanFree((void **) (nqx+2));
   cleanFree((void **) (nqx+3));

   cleanFree((void **) (&xtemp));
   cleanFree((void **) (&q4x));
   cleanFree((void **) (&y4x));

   if (*constrainScript != 0) unlink(constrainScript);
   if (*constrainModule != 0) unlink(constrainModule);
}


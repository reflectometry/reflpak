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
   cleanFree(&qtemp);
   cleanFree(&y);
   cleanFree(&dy);
   cleanFree(&ymod);
   cleanFree(&dyda);

   freeCdata();
   /* cleanFree((void **) (&yfita)); */

   if (*constrainScript != 0) unlink(constrainScript);
   if (*constrainModule != 0) unlink(constrainModule);
}


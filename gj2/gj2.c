/* Main program: parses command line arguments and then calls main
   loop in magblocks4 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <magblocks4.h>
#include <lenc.h>

#include <genpsc.h>

int main(int argc, char *argv[]);

/* Module data */
static const char *defparfile = "gmagblocks4.sta";
char *gj2_SCCS_VerInfo = "@(#)gj2	v1.50 6/9/2001";

/* Local function prototypes */
#include <static.h>

STATIC void exitMagblocks(int signum)
{
   exit(0);
}


int main(int argc, char *argv[])
{
   if (argc > 1) {
      /* Parse command line arguments */
      if ((int) lenc(argv[1]) < PARFILELEN)
         strcpy(parfile, argv[1]);
      else {
         printf("%s: filename too long, using default name instead\n", argv[1]);
         strcpy(parfile, defparfile);
      }
   } else
      strcpy(parfile, defparfile);

#ifndef DEBUGMALLOC
   /* Change interrupt signal handling to clean up */
   signal(SIGINT, exitMagblocks);
#endif

   magblocks4_init();
   atexit(cleanUp);

   for (;;) magblocks4();
   return 0;
}


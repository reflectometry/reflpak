#include <stdio.h>
#include <mlayer.h>
#include <lenc.h>

#include <genpsc.h>
#include <cparms.h>


/* Local function prototypes */
#include <static.h>

STATIC void exitMlayer(int signum)
{
   exit(0);
}


int main(int argc, char *argv[]);

/* Module data */
static const char *defparfile = "mlayer.staj";
char *mlayer_SCCS_VerInfo = "@(#)mlayer	v1.46 05/24/2001";


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
   signal(SIGINT, exitMlayer);
#endif

   mlayer_init();
   atexit(cleanUp);

   for (;;) mlayer();
   return 0;
}


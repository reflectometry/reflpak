/* Routines for changing directories */

#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>
#include <limits.h>
#include <errno.h>
/* #include <pwd.h> */
#include <string.h>
#include <unix.h>
#include <queryString.h>

#include <genpsc.h>

/* Local function prototypes */
#include <static.h>

STATIC char *tildeExpand(char dir[PATH_MAX + 1]);

int bang(char *command) {
   int retValue = 0;
   static char execstring[1024];

   if (command[1] == '!')
      retValue = system(getenv("SHELL"));

   else if (queryString("System: ", execstring, 1023) != NULL)
      retValue = system(execstring);

   return retValue;
}


#define ALWAYSEXPAND

int cd (char *command) {
   int retValue = 0;

#if 0
   if (
      queryString("New directory: ", currentDir, PATH_MAX) != NULL &&
      #ifdef ALWAYSEXPAND
         /* Always expand (like the shell). */
         chdir(tildeExpand(currentDir)) == -1
      #else
         /* Expand only if it doesn't exist in current dir. */
         chdir(currentDir) == -1 &&
         (errno != ENOENT || chdir(tildeExpand(currentDir)) == -1)
      #endif
   ) {
         perror(currentDir);
         retValue = -1;
   }
   getwd(currentDir);
#endif

   return retValue;
}


STATIC char *tildeExpand(char *dir)
{
   char *retValue = "";
#if 0
   struct passwd *thisEntry;
   char *logonEnd, *retValue;
   STATIC char expanded[PATH_MAX + 1];

#ifdef ALWAYSEXPAND
   retValue = dir;
#else
   retValue = "";
#endif

   if (dir != NULL && *dir == '~') {
      dir++;
      logonEnd = strchr(dir, '/');
      if (logonEnd == NULL)
         logonEnd = dir + strlen(dir);

      if (logonEnd - dir > 0) {
         strncpy(expanded, dir, logonEnd - dir);
         expanded[logonEnd - dir] = 0;
         thisEntry = getpwnam(expanded);
      } else
         thisEntry = getpwuid(getuid());

      if (thisEntry != NULL) {
         strncpy(expanded, thisEntry->pw_dir, PATH_MAX);
         expanded[PATH_MAX] = 0;
         if (strlen(expanded) + strlen(logonEnd) <= PATH_MAX) {
            strcat(expanded, logonEnd);
            retValue = expanded;
         }
      }
   }
#endif
   return retValue;
}


#include <stdio.h>
#include <signal.h>

#define COMMON
#include <stopFit.h>

void stopFit(int sig)
{
   abortFit = 1;
}


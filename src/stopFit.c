#include <stdio.h>
#include <signal.h>

#define COMMON
#include <stopFit.h>

void stopFit(int signum)
{
   abortFit = 1;
}


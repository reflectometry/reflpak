#include <stdio.h>
#include <signal.h>

#define COMMON
#include <stopMovie.h>

void stopMovie(int sig)
{
   abortMovie = 1;
}


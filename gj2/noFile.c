/* Prints error message when file can't be opened */

/* Used by PRINTINFO and GETDATA */

#include <stdio.h>
#include <noFile.h>
#include "error.h"

void noFile(const char *filename)
{
   ERROR("/** Unable to open file %s **/\n", filename);
}


/* Subroutine incorporates constraints into fit
   John Ankner 4 December 1991 */

#ifndef _CONSTRAIN_H
#define _CONSTRAIN_H

#include <common.h>

void constrain(double a[], int nlayer);

/* For constrain function compatibility across implementations of */
/* Ankner reflectivity suite */

#define MLAYCOMPAT 0x00010000L
#define  GJ2COMPAT 0x00020000L
#define TLAYCOMPAT 0x00040000L

#endif /* _CONSTRAIN_H */


/* Function returns character length of string */

#ifndef _LENC_H
#define _LENC_H

#include <string.h>

int lenc(char *string);

/* Be wary of side-effects with this macro! */
#define lenc(string) (((string) == NULL) ? 0 : strcspn((string), " "))

#endif /* _LENC_H */



/* Subroutine returns length of string preceding a period */

#ifndef _LENPRE_H
#define _LENPRE_H

int lenpre(char *string);

/* Be wary of side-effects with this macro! */
#define lenpre(string) (((string) == NULL) ? 0 : strcspn((string), ". "))

#endif /* _LENPRE_H */


/* Defines array and vector dereferencing macros */

#ifndef _DYNAMIC_H
#define _DYNAMIC_H

typedef struct {double *a; int row, col;} dynarray;

/* Beware of side effects with these macros! */
#define refray(array,r,c) ((array).a[(array).col * (r) + (c)])

#endif /* _DYNAMIC_H */


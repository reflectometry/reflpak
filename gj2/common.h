/* Implements FORTRAN COMMON blocks */

/* In the source file which allocates space
   for the block, include an empty #define
   for COMMON before #include-ing the block. */

#ifndef _COMMON_H
#define _COMMON_H

#ifndef COMMON
#define COMMON extern
#endif

#endif /* _COMMON_H */


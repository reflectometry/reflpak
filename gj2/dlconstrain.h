/* Provides support for linking dynamic loading of constrain function */

#ifndef _DLCONSTRAIN_H
#define _DLCONSTRAIN_H

/* For size_t */
#include <stddef.h>
#include <common.h>

COMMON void (*Constrain)(int, double [], int);

#define MLAYCOMPAT 0x00010000L
#define  GJ2COMPAT 0x00020000L
#define TLAYCOMPAT 0x00040000L

typedef void (*constrainFunc)(int, double [],int);

void closeLib(void);
constrainFunc findFunc(char *path, char *func, size_t length);
constrainFunc loadConstrain(char *path);
constrainFunc newConstraints(char *scriptfile, char *objectfile);
int makeconstrain(char *scriptfile, char *objectfile);
int editconstraints(char *scriptfile);

#endif /* _DLCONSTRAIN_H */


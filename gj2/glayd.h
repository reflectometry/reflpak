/* Implements FORTRAN COMMON block GLAYD */

#ifndef _GLAYD_H
#define _GLAYD_H

#include <common.h>
#include <parameters.h>

#ifdef MINUSQ
COMMON double gqcsq[2 * MAXGEN], gmu[2 * MAXGEN], gd[2 * MAXGEN];
COMMON double gqmsq[2 * MAXGEN], gthe[2 * MAXGEN];
#else
COMMON double gqcsq[MAXGEN], gmu[MAXGEN], gd[MAXGEN];
COMMON double gqmsq[MAXGEN], gthe[MAXGEN];
#endif

#endif /* _GLAYD_H */


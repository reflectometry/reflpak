/* Implements FORTRAN COMMON block GENPSD */

#ifndef _GENPSD_H
#define _GENPSD_H

#include <common.h>
#include <parameters.h>

COMMON union {
   struct {
      double dqcsq[MAXLAY], dqcmsq[MAXLAY], dmu[MAXLAY];
      double dd[MAXLAY], ddm[MAXLAY], drough[MAXLAY];
      double dmrough[MAXLAY], dthe[MAXLAY];
      double dbki, dbmintns;
   } layer;
   double a[NA];
} fitvars, fitunc;

#define qcsq (fitvars.layer.dqcsq)
#define qcmsq (fitvars.layer.dqcmsq)
#define mu (fitvars.layer.dmu)
#define d (fitvars.layer.dd)
#define dm (fitvars.layer.ddm)
#define rough (fitvars.layer.drough)
#define mrough (fitvars.layer.dmrough)
#define the (fitvars.layer.dthe)
#define bki (fitvars.layer.dbki)
#define bmintns (fitvars.layer.dbmintns)

#define A (fitvars.a)

#define Dqcsq (fitunc.layer.dqcsq)
#define Dqcmsq (fitunc.layer.dqcmsq)
#define Dmu (fitunc.layer.dmu)
#define Dd (fitunc.layer.dd)
#define Ddm (fitunc.layer.ddm)
#define Drough (fitunc.layer.drough)
#define Dmrough (fitunc.layer.dmrough)
#define Dthe (fitunc.layer.dthe)
#define Dbki (fitunc.layer.dbki)
#define Dbmintns (fitunc.layer.dbmintns)

#define DA (fitunc.a)

COMMON double thedel, lamdel, lambda;

#endif /* _GENPSD_H */


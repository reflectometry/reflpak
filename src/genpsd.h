/* Implements FORTRAN COMMON block GENPSD */

#ifndef _GENPSD_H
#define _GENPSD_H

#include <common.h>
#include <parameters.h>

struct layerparams {double qcsq[MAXLAY], qcmsq[MAXLAY], mu[MAXLAY], d[MAXLAY], rough[MAXLAY];};

struct fitparameters {
  struct layerparams top, mid, bot;
  double dbki, dbmintns;
};

COMMON union {
   struct fitparameters layers;
   double a[NA];
} fitvars, fitunc;

#define tqcsq (fitvars.layers.top.qcsq)
#define tqcmsq (fitvars.layers.top.qcmsq)
#define tmu (fitvars.layers.top.mu)
#define td (fitvars.layers.top.d)
#define trough (fitvars.layers.top.rough)

#define mqcsq (fitvars.layers.mid.qcsq)
#define mqcmsq (fitvars.layers.mid.qcmsq)
#define mmu (fitvars.layers.mid.mu)
#define md (fitvars.layers.mid.d)
#define mrough (fitvars.layers.mid.rough)

#define bqcsq (fitvars.layers.bot.qcsq)
#define bqcmsq (fitvars.layers.bot.qcmsq)
#define bmu (fitvars.layers.bot.mu)
#define bd (fitvars.layers.bot.d)
#define brough (fitvars.layers.bot.rough)

#define bki (fitvars.layers.dbki)
#define bmintns (fitvars.layers.dbmintns)

#define A (fitvars.a)

#define Dtqcsq (fitunc.layers.top.qcsq)
#define Dtqcmsq (fitunc.layers.top.qcmsq)
#define Dtmu (fitunc.layers.top.mu)
#define Dtd (fitunc.layers.top.d)
#define Dtrough (fitunc.layers.top.rough)

#define Dmqcsq (fitunc.layers.mid.qcsq)
#define Dmqcmsq (fitunc.layers.mid.qcmsq)
#define Dmmu (fitunc.layers.mid.mu)
#define Dmd (fitunc.layers.mid.d)
#define Dmrough (fitunc.layers.mid.rough)

#define Dbqcsq (fitunc.layers.bot.qcsq)
#define Dbqcmsq (fitunc.layers.bot.qcmsq)
#define Dbmu (fitunc.layers.bot.mu)
#define Dbd (fitunc.layers.bot.d)
#define Dbrough (fitunc.layers.bot.rough)

#define Dbki (fitunc.layers.dbki)
#define Dbmintns (fitunc.layers.dbmintns)

#define DA (fitunc.a)

COMMON double thedel, lamdel, lambda;

#endif /* _GENPSD_H */


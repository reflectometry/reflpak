#include "mx.h"

void 
build_mesh(const int m, const int n, const mxtype xin[], const mxtype yin[],
	   mxtype x[], mxtype y[]);
void 
build_fmesh(const int n, const int m, 
	    const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	    mxtype x[], mxtype y[]);
void 
build_dmesh(const int n, const int m,
	    const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	    mxtype x[], mxtype y[]);
void 
build_abmesh(const int n, const int m,
	     const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	     mxtype x[], mxtype y[]);
void
build_Qmesh(const int n, const int m,
	    const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	    const mxtype lambda, mxtype Qx[], mxtype Qz[]);
void
build_Lmesh(const int n, const int m,
	    const mxtype alpha, const mxtype beta, const mxtype dtheta[],
	    const mxtype lambda[], mxtype Qx[], mxtype Qz[]);

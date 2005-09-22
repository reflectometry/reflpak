#include "mx.h"

void 
build_mesh(const int n, const int m, const mxtype yin[], const mxtype xin[],
	   mxtype x[], mxtype y[]);
int
find_in_mesh(const int n, const int m, 
	     const mxtype yin[], const mxtype xin[],
	     const mxtype x, const mxtype y);

void 
build_fmesh(const int n, const int m, 
	    const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	    mxtype x[], mxtype y[]);
int
find_in_fmesh(const int n, const int m,
	      const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	      const mxtype x, const mxtype y);

void 
build_dmesh(const int n, const int m,
	    const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	    mxtype x[], mxtype y[]);
int
find_in_dmesh(const int n, const int m,
	      const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	      const mxtype x, const mxtype y);

void 
build_abmesh(const int n, const int m,
	     const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	     mxtype x[], mxtype y[]);
int
find_in_abmesh(const int n, const int m,
	      const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	       const mxtype x, const mxtype y);

void
build_Qmesh(const int n, const int m,
	    const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	    const mxtype lambda, mxtype Qx[], mxtype Qz[]);
int
find_in_Qmesh(const int n, const int m, 
	      const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	      const mxtype lambda, const mxtype Qx, const mxtype Qz);

void
build_Lmesh(const int n, const int m,
	    const mxtype alpha, const mxtype beta, const mxtype dtheta[],
	    const mxtype lambda[], mxtype Qx[], mxtype Qz[]);
int
find_in_Lmesh(const int n, const int m, 
	      const mxtype alpha, const mxtype beta, const mxtype dtheta[],
	      const mxtype lambda[], const mxtype Qx, const mxtype Qz);

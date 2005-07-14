#include "mx.h"

void 
build_mesh(int m, int n, const mxtype xin[], const mxtype yin[],
	   mxtype x[], mxtype y[]);
void 
build_fmesh(int n, int m, 
	    const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	    mxtype x[], mxtype y[]);
void 
build_dmesh(int n, int m,
	    const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	    mxtype x[], mxtype y[]);
void
build_Qmesh(int n, int m, mxtype lambda,
	    const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	    mxtype Qx[], mxtype Qz[]);

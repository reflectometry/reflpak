#include <math.h>
#include "refl.h"

/* Build a mesh from the scan of linear detector readings.
 *
 * Values for the scan are stored as a dense vector, point by point:
 *
 *   bin_1 bin_2 ... bin_m bin_1 bin_2 ... bin_m ... bin_1 bin_2 ... bin_m
 *   \------point 1------/ \------point 1------/ ... \------point n------/
 *
 * The values are assumed to be at the centers of the pixels, and the mesh
 * will be built up from the bin edges, and from the alpha and beta angles
 * of the detector.  The resulting grid will be complete but not 
 * necessarily rectilinear.
 *
 * The angle alpha, also known as theta or as A3, is the angle of the beam 
 * with respect to the surface of the sample.   The angle beta, also known 
 * as two-theta or as A4, is the angle of the detector with respect to the
 * beam.
 *
 * There a few different scans we want to be able to support:
 *
 *   point vs. bin
 *   theta_i vs. bin
 *   theta_i vs. dtheta
 *   theta_i vs. theta_f
 *   theta_i vs. theta_f-theta_i
 *   Qz vs. Qx
 *
 * We have specialized functions to construct the meshes for each scan:
 *
 *   build_fmesh (n, m, alpha, beta, dtheta, x, y)
 *     Contructs indices for theta_i vs. theta_f.
 *   build_dmesh (n, m, alpha, beta, dtheta, x, y)
 *     Constructs theta_i vs. theta_f-theta_i.
 *   build_Qmesh (n, m, alpha, beta, dtheta, x, y)
 *     Constructs Qz vs. Qx.
 *   build_mesh (n, m, points, bins, x, y)
 *     Constructs point vs. bin.  Using alpha instead of points and
 *     dtheta instead of bins we can construct theta_i vs. bin and
 *     theta_i vs. dtheta.
 * 
 * Creating the set of bin edges is an easy enough problem that it
 * can be done in a script.

proc edges {centers} {
  if { [llength $centers] == 1 } {
    if { $centers == 0. } {
      set e {-1. 1}
    } elseif { $centers < 0. } {
      set e [list [expr {2.*$centers}] 0.]
    } else {
      set e [list 0 [expr {2.*$centers}]]
    }
  } else {
    set l [lindex $centers 0]
    set r [lindex $centers 1]
    set e [expr {$l - 0.5*($r-$l)}]
    foreach r [lrange $centers 1 end] {
      lappend e [expr {0.5*($l+$r)}]
      set l $r
    }
    set l [lindex $centers end-2]
    lappend e [expr {$r + 0.5*($r-$l)}]
  }
  return $e
}

proc bin_edges {pixels} {
  set edges {}
  for {set p 0} {$p <= $pixels} {incr p} {
    lappend edges [expr {$p+0.5}]
  }
  return $edges
}

proc dtheta_edges {pixels pixelwidth distance centerpixel} {
  set edges {}
  for {set p 0} {$p <= $pixels} {incr p} {
    lappend edges [expr {atan2(($centerpixel-$p)*$pixelwidth, $distance)}]
  }
  return $edges
}

 */

void 
build_mesh(int m, int n, const mxtype xin[], const mxtype yin[],
	   mxtype x[], mxtype y[])
{
  int idx = 0;
  int j, k;
  for (j=0; j <= n; j++) {
    for (k=0; k <= m; k++) {
      y[idx] = yin[j];
      x[idx] = xin[k];
      idx++;
    }
  }
}

void 
build_fmesh(int n, int m, 
	    const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	    mxtype x[], mxtype y[])
{
  int idx = 0;
  int j, k;
  for (j=0; j <= n; j++) {
    for (k=0; k <= m; k++) {
      y[idx] = alpha[j];
      x[idx] = beta[j] - alpha[j] + dtheta[k];
      idx++;
    }
  }
}

void 
build_abmesh(int n, int m, 
	     const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	     mxtype x[], mxtype y[])
{
  int idx = 0;
  int j, k;
  for (j=0; j <= n; j++) {
    for (k=0; k <= m; k++) {
      y[idx] = alpha[j];
      x[idx] = beta[j] + dtheta[k];
      idx++;
    }
  }
}

void 
build_dmesh(int n, int m,
	    const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	    mxtype x[], mxtype y[])
{
  int idx = 0;
  int j, k;
  for (j=0; j <= n; j++) {
    for (k=0; k <= m; k++) {
      y[idx] = alpha[j];
      x[idx] = beta[j] - 2*alpha[j] + dtheta[k];
      idx++;
    }
  }
}

void
build_Qmesh(int n, int m, mxtype lambda,
	    const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	    mxtype Qx[], mxtype Qz[])
{
  const mxtype two_pi_over_lambda = 2.*M_PI/lambda;
  const mxtype pi_over_180 = M_PI/180.;
  int idx = 0;
  int j,k;
  for (j=0; j <= n; j++) {
    const mxtype in = alpha[j]*pi_over_180;
    for (k=0; k <= m; k++) {
      const mxtype out = (beta[j]+dtheta[k])*pi_over_180 - in;
      Qz[idx] = two_pi_over_lambda*(sin(out)+sin(in));
      Qx[idx] = two_pi_over_lambda*(cos(out)-cos(in));
      idx++;
    }
  }
}

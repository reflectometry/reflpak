#include <math.h>
#include <stdio.h>
#include "refl.h"


/* Qx-Qz reverse indexing

From Qx,Qz find Alpha,Beta given Lambda
From Qx,Qz find Lambda,Beta given Alpha

Note that the inverse (x,y) = f'(Qx,Qz) is not unique.
If Beta == 0, Alpha/Lambda can be anything.
If Beta > 0, then Alpha,Beta and Alpha+Beta-180,-Beta yield the same Qx,Qz
We are assuming that if Qz<0 then Beta<0, which works for the range of angles
we are likely to see in a reflectometry configuration.

Octave code:

# Sample Qx/Qz data
alpha=-[-25,-20,-15,-1];
beta=-20;
lambda=5;
ks = 2*pi./lambda;
a=alpha*pi/180;
b=beta*pi/180;
Qz=ks.*(sin(b-a)+sin(a));
Qx=ks.*(cos(b-a)-cos(a));

# Compute Alpha-Beta
x=Qx*L/(2*pi);  z=Qz*L/(2*pi);      # Normalize Q
#B=acos(1-x.^2/2-z.^2/2)*180/pi;    # Calculate beta (faster)
B=2*asin(sqrt(x.^2+z.^2)/2)*180/pi; # Calculate beta (more accurate)
B(z<0) = -B(z<0);                   # Force Qz < 0 to use B < 0
T=atan2(Qx,Qz)*180/pi;              # Calculate theta (inaccurate for low beta)
T(T>90)-=360;                       # Force Qz < 0 to use A < 0
A=T+B/2;                            # Calculate alpha assuming B>0
A(z<0)+=180;                        # Correct alpha for B < 0

# Compute Lambda-Beta
T=atan2(Qx,Qz)*180/pi;
T(T>90)-=360;
B=2*(alpha-T);
B(B>180)-=360;
L=4*pi*sin(B/2*pi/180)./sqrt(Qx.^2+Qz.^2)

# Show results
alpha,beta,x,z,T,A,B



Tests should explore the range alpha,beta = (-90,90), beta != 0, lambda > 0,
particularly near Qx,Qy = 0.

*/

void
QxQz_to_AlphaBeta(const double Qx, const double Qz, const double lambda,
		  double *alpha, double *beta)
{
  mxtype T,B,A;

  T = 180./M_PI * atan2(Qx,Qz);
  if (T > 90.) T -= 360;
  B = 360./M_PI * asin ( sqrt(Qx*Qx + Qz*Qz) * lambda/(4.*M_PI) );
  if (Qz < 0) B = -B;
  A = T + B/2;
  if (Qz < 0) A += 180.;

  *beta = B;
  *alpha = A;
}


void
QxQz_to_BetaLambda(const double Qx, const double Qz, const double alpha,
		   double *beta, double *lambda)
{
  mxtype T,B,L;

  T = 180./M_PI * atan2(Qx,Qz);
  if (T>90.) T -= 360.;
  B = 2*(alpha-T);
  if (B>180.) B -= 360.;
  L = 4*M_PI*sin(B/2.*M_PI/180) / sqrt(Qx*Qx + Qz*Qz);

  *beta = B;
  *lambda = L;
}

/* Search for a value in a particular interval.  Return the interval.
 *
 * The list of values is assumed to be strictly monotonic increasing.
 * The value is in the semiopen interval [x_i,x_{i+1}) where i is the
 * returned index.  The returned value is -1 if the value is not in
 * any interval.

 * Developed and tested in Octave using the following code:

function lo=interval(x,v)
  if length(x) < 2 || v < x(1) || v >= x(end)
    lo = -1;
  else
    lo = 0;
    hi = length(x)-1;
    while (lo < hi-1)
      mid = floor((lo+hi)/2);
      if (v < x(mid+1)) hi=mid;
      else lo=mid;
      end
    end
  end

%!assert(interval(1:5,0),-1)
%!assert(interval(1:5,1),0)
%!assert(interval(1:5,1.5),0)
%!assert(interval(1:5,2),1)
%!assert(interval(1:5,3),2)
%!assert(interval(1:5,4),3)
%!assert(interval(1:5,5),-1)
%!assert(interval([],5),-1)
%!assert(interval(1,0),-1)
%!assert(interval(1,1),-1)
%!assert(interval(1:2,0),-1)
%!assert(interval(1:2,1),0)
%!assert(interval(1:2,2),-1)

 */
static int
interval(const int n, const mxtype x[], const mxtype v)
{
  int lo = 0, hi=n-1;
  if (n < 2) return -1;
  if (x[0] < x[n-1]) {
    /* Ascending */
    if (v < x[0] || v >= x[n-1]) return -1;
    while (lo < hi-1) {
      const int mid = (lo+hi)/2;
      if (v < x[mid]) hi=mid;
      else lo=mid;
    }
  } else {
    /* Descending */
    if (v >= x[0] || v < x[n-1]) return -1;
    while (lo < hi-1) {
      const int mid = (lo+hi)/2;
      if (v >= x[mid]) hi=mid;
      else lo=mid;
    }
  }
  return lo;
}

/* Calculate skew for a point between the lines in a skewed grid so that 
 * we can lookup the x-coordinate grid x-spacing. */
static mxtype skew(const mxtype y, const mxtype ybelow, const mxtype yabove,
		   const mxtype skewbelow, const mxtype skewabove)
{
  return (y-ybelow)*(skewabove-skewbelow)/(yabove-ybelow) + skewbelow;
}



/* Build a mesh from the scan of linear detector readings.
 *
 * Values for the scan are stored as a dense vector, point by point:
 *
 *   bin_1 bin_2 ... bin_m bin_1 bin_2 ... bin_m ... bin_1 bin_2 ... bin_m
 *   \------point 1------/ \------point 2------/ ... \------point n------/
 *
 * The values are assumed to be at the centers of the pixels, and the mesh
 * will be built up from the bin edges, and from the alpha and beta angles
 * of the detector.  The resulting grid will be complete but not 
 * necessarily rectilinear.
 *
 * The angle alpha, also known as theta or as A3, is the angle of the surface
 * of the sample with respect to the beam.   The angle beta, also known 
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
 *   lambda vs. bin
 *   lambda vs. dtheta
 *   Qz vs. Qx
 *
 * We have specialized functions to construct the meshes for each scan:
 *
 *   build_fmesh (n, m, alpha, beta, dtheta, x, y)
 *     Contructs indices for theta_i vs. theta_f.
 *   build_dmesh (n, m, alpha, beta, dtheta, x, y)
 *     Constructs theta_i vs. theta_f-theta_i.
 *   build_Qmesh (n, m, alpha, beta, dtheta, x, y)
 *     Constructs Qz vs. Qx from alpha,beta,dtheta given lambda for the frame.
 *   build_Lmesh (n, m, alpha, beta, dtheta, lambda, x, y)
 *     Constructs Qz vs. Qx from lambda,dtheta given alpha,beta for the frame.
 *   build_mesh (n, m, points, bins, x, y)
 *     Constructs point vs. bin.  Using alpha instead of points and
 *     dtheta instead of bins we can construct theta_i vs. bin and
 *     theta_i vs. dtheta.
 *
 * Each build_?mesh function has a corresponding find_in_?mesh function
 * which takes the same parameters, with x,y being a scalar value to look
 * up in the mesh.  The returned integer is an index into the (n-1)x(m-1)
 * array of points at the center of the mesh quad j,k, formed by j*(n-1)+k.
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

/* ==== Rectilinear mesh ==== */
void 
build_mesh(const int n, const int m, 
	   const mxtype yin[], const mxtype xin[],
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

int
find_in_mesh(const int n, const int m, 
	     const mxtype yin[], const mxtype xin[],
	     const mxtype x, const mxtype y)
{
  int j,k;

  j = interval(n+1,yin,y);
  if (j < 0) return -1;
  k = interval(m+1,xin,x);
  if (k < 0) return -1;
  return m*j + k;
}

/* ==== Skewed mesh: beta-alpha vs dtheta ==== */
void 
build_fmesh(const int n, const int m, 
	    const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	    mxtype x[], mxtype y[])
{
  int idx = 0;
  int j, k;
  for (j=0; j <= n; j++) {
    const mxtype theta = beta[j] - alpha[j];
    for (k=0; k <= m; k++) {
      y[idx] = alpha[j];
      x[idx] = theta + dtheta[k];
      idx++;
    }
  }
}

int
find_in_fmesh(const int n, const int m,
	      const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	      const mxtype x, const mxtype y)
{
  int j, k;
  mxtype dx;

  j = interval(n+1,alpha,y);
  if (j < 0) return -1;
  dx = x-skew(y,alpha[j],alpha[j+1],beta[j]-alpha[j],beta[j+1]-alpha[j+1]);
  k = interval(m+1,dtheta,dx);
  if (k < 0) return -1;
  return m*j + k;
}

/* == skewed mesh, alpha vs beta == */
void 
build_abmesh(const int n, const int m, 
	     const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	     mxtype x[], mxtype y[])
{
  int idx = 0;
  int j, k;
  for (j=0; j <= n; j++) {
    const mxtype theta = beta[j];
    for (k=0; k <= m; k++) {
      y[idx] = alpha[j];
      x[idx] = theta + dtheta[k];
      idx++;
    }
  }
}

int
find_in_abmesh(const int n, const int m,
	      const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	      const mxtype x, const mxtype y)
{
  int j, k;
  mxtype dx;

  j = interval(n+1,alpha,y);
  if (j < 0) return -1;
  dx = x-skew(y,alpha[j],alpha[j+1],beta[j],beta[j+1]);
  k = interval(m+1,dtheta,dx);
  if (k < 0) return -1;
  return m*j + k;
}

/* == skewed mesh, alpha vs. beta - 2*alpha == */
void 
build_dmesh(const int n, const int m,
	    const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	    mxtype x[], mxtype y[])
{
  int idx = 0;
  int j, k;
  for (j=0; j <= n; j++) {
    const mxtype theta = beta[j]-2*alpha[j];
    for (k=0; k <= m; k++) {
      y[idx] = alpha[j];
      x[idx] = theta + dtheta[k];
      idx++;
    }
  }
}

int
find_in_dmesh(const int n, const int m,
	      const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	      const mxtype x, const mxtype y)
{
  int j, k;
  mxtype dx;

  j = interval(n+1,alpha,y);
  if (j < 0) return -1;
  dx = x-skew(y,alpha[j],alpha[j+1],beta[j]-2*alpha[j],beta[j+1]-2*alpha[j+1]);
  k = interval(m+1,dtheta,dx);
  if (k < 0) return -1;
  return m*j + k;
}

/* == warped mesh, Qx vs Qz from beta-alpha, delta theta == */
void
build_Qmesh(const int n, const int m, 
	    const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	    const mxtype lambda, mxtype Qx[], mxtype Qz[])
{
  const mxtype ks = 2.*M_PI/lambda;
  const mxtype pi_over_180 = M_PI/180.;
  int idx = 0;
  int j,k;
  for (j=0; j <= n; j++) {
    const mxtype sin_in = sin(alpha[j]*pi_over_180);
    const mxtype cos_in = cos(alpha[j]*pi_over_180);
    const mxtype theta = beta[j]-alpha[j];
    for (k=0; k <= m; k++) {
      const mxtype out = (theta+dtheta[k])*pi_over_180;
      Qz[idx] = ks*(sin(out)+sin_in);
      Qx[idx] = ks*(cos(out)-cos_in);
      idx++;
    }
  }
}


/* Find the rate scaling to apply to each pixel.  This is based on
 * the derivative at the center of the pixel rather than boundaries
 * of the mesh --- that way we don't have to worry about whether the
 * steps sizes in the mesh are uniform.  Note that this means that
 * the scale goes nxm rather than (n+1)x(m+1) elements.
 *
 *
 * The scale factor is determined by seeing the size of a patch
 * dA = dxdy that is transformed into a patch dQ(u,v).
 * From a text on surface integrals we read that dQ is
 *
 *    | dx/du dy/dv - dy/du dx/dv | du dv
 *
 * CHECK!!! This may be off by a factor of 1/2.
 *
 * For the transformation from Ti,Tf -> Qx,Qz we have:
 *
 *   Qx = k cos Tf - k cos Ti
 *   Qz = k sin Tf + k sin Ti
 *
 *   dQx/dTi =  k sin Ti
 *   dQx/dTf = -k sin Tf
 *   dQz/dTi =  k cos Ti
 *   dQz/dTf =  k cos Tf
 *
 * Multiplying, this is:
 *
 *   dQ = k^2 | sin Ti cos Tf + cos Ti sin Tf | dTi dTf
 *
 * which is the value used below.
 *
 * Should we drive it back further to position p on the detector?
 * This would expand dTf into (dTf/dp) dp.  Given:
 *
 *    Tf = atan( (p-c)/d )
 *
 * where c is the center pixel and d is the detector distance, then:
 *
 *    dTf/dp = d / (d^2 + (p-c)^2)
 *
 * with d >> (p-c), this is about 1/d, so the effect can be ignored.
 */
void
scale_Qmesh(const int n, const int m, 
	    const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	    const mxtype lambda, mxtype scale[])
{
  const mxtype ksq = 4.*M_PI*M_PI/lambda/lambda;
  const mxtype pi_over_180 = M_PI/180.;
  int idx = 0;
  int j,k;
  for (j=0; j < n; j++) {
    for (k=0; k < m; k++) {
      const mxtype twotheta = (beta[j]+dtheta[k])*pi_over_180;
      scale[idx++] = fabs(ksq*sin(twotheta));
    }
  }
}


int
find_in_Qmesh(const int n, const int m, 
	      const mxtype alpha[], const mxtype beta[], const mxtype dtheta[],
	      const mxtype lambda, const mxtype Qx, const mxtype Qz)
{
  double A,B;
  mxtype dx;
  int j,k;

  if (fabs(Qz) < 1.e-10) return -1; /* Ignore main beam for now */

  QxQz_to_AlphaBeta(Qx,Qz,lambda,&A,&B);
  j = interval(n+1,alpha,A);
  if (j < 0) return -1;
  dx = B-skew(A,alpha[j],alpha[j+1],beta[j],beta[j+1]);
  k = interval(m+1,dtheta,dx);
  if (k < 0) return -1;
  return m*j + k;
}


/* == warped mesh, Qx vs. Qz from delta-theta, lambda ==
// alpha is sample angle (usually known as theta)
// beta is detector angle (usually known as twotheta)
// dtheta is angle of pixel center relative to the detector angle
// lambda is wavelength of the pixel
//
// The values in the displayed mesh are the vertically summed
// time binned detector values, possibly normalized by monitor,
// clipped and log-scaled.
*/

void
build_Lmesh(const int n, const int m, 
	    const mxtype alpha, const mxtype beta, const mxtype dtheta[],
	    const mxtype lambda[], mxtype Qx[], mxtype Qz[])
{
  const mxtype pi_over_180 = M_PI/180.;
  const mxtype sin_in = sin(alpha*pi_over_180);
  const mxtype cos_in = cos(alpha*pi_over_180);
  const mxtype theta = beta-alpha;
  int idx = 0;
  int j,k;
  for (j=0; j <= n; j++) {
    const mxtype ks = 2.*M_PI/lambda[j];
    for (k=0; k <= m; k++) {
      const mxtype out = (theta+dtheta[k])*pi_over_180;
      Qz[idx] = ks*(sin(out)+sin_in);
      Qx[idx] = ks*(cos(out)-cos_in);
      idx++;
    }
  }
}

/* Find the rate scaling to apply to each pixel.  This is based on
 * the derivative at the center of the pixel rather than boundaries
 * of the mesh --- that way we don't have to worry about whether the
 * steps sizes in the mesh are uniform.  Note that this means that
 * the scale goes nxm rather than (n+1)x(m+1) elements.
 *
 *
 * The scale factor is determined by seeing the size of a patch
 * dA = dxdy that is transformed into a patch dQ(u,v).
 * From a text on surface integrals we read that dQ is
 *
 *    | dx/du dy/dv - dy/du dx/dv | du dv
 *
 * For the transformation from L,Tf -> Qx,Qz we have:
 *
 *   Qx = 2 pi/L (cos Tf - cos Ti)
 *   Qz = 2 pi/L (sin Tf + sin Ti)
 *
 *   dQx/dL  = -2 pi/L^2 (cos Tf - cos Ti)
 *   dQx/dTf = -2 pi/L sin Tf
 *   dQz/dL  = -2 pi/L^2 (sin Tf + sin Ti)
 *   dQz/dTf =  2 pi/L cos Tf
 *
 * Expanding the above, this is:
 *
 *   dQ = k^2/L | 1 + sin Ti sin Tf - cos Ti cos Tf | dTf dL
 *
 * which is the value used below.
 */
void
scale_Lmesh(const int n, const int m, 
	    const mxtype alpha, const mxtype beta, const mxtype dtheta[],
	    const mxtype lambda[], mxtype scale[])
{
  const mxtype pi_over_180 = M_PI/180.;
  int idx = 0;
  int j,k;
  for (j=0; j <= n; j++) {
    const mxtype ks = 2.*M_PI/lambda[j];
    const mxtype ksq_L = ks*ks/lambda[j];
    for (k=0; k <= m; k++) {
      const mxtype twotheta = (beta+dtheta[k])*pi_over_180;
      scale[idx++] = ksq_L * fabs(1 - cos(twotheta));
    }
  }
}

int
find_in_Lmesh(const int n, const int m, 
	      const mxtype alpha, const mxtype beta, const mxtype dtheta[],
	      const mxtype lambda[], const mxtype Qx, const mxtype Qz)
{
  double B,L;
  mxtype dx;
  int j,k;

  if (fabs(Qz) < 1.e-6) return -1; /* Ignore main beam for now */

  QxQz_to_BetaLambda(Qx,Qz,alpha,&B,&L);
  j = interval(n+1,lambda,L);
  if (j < 0) return -1;
  dx = B-skew(L,lambda[j],lambda[j+1],beta,beta);
  k = interval(m+1,dtheta,dx);
  if (k < 0) return -1;
  return m*j + k;
}


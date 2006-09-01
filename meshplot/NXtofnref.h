/* This is a work of the United States Government and is not
 * subject to copyright protection in the United States.
 */

#ifndef _NXTOFNREF_H
#define _NXTOFNREF_H

#include <assert.h>
#include <vector>
#include <string>
#include <iostream>

#include "nexus_helper.h"

inline double square(double x) { return x*x; }


// Properties of NXtofnref
class NXtofnref
{
  void load_instrument(void);
  void load_detector_tcb(void);
  void load_monitor(void);
  void load_pixel_angle(void);
  void compute_wavelength(void);

  void find_channels(double vlo, double vhi, int &ilo, int &ihi);

public:
  // File information
  Nexus *file;        // File handle
  std::string name, title;  // Complete filename
  bool is_open;

  // Resolution information
  double slit_width[4];         // (mm)
  double slit_distance[4];      // (mm)
  double slit_height[4];        // (mm)

  // Detector definition
  int Nx, Ny;                   // Detector dimensions
  int data_rank;                // Number of data dimensions
  int primary_dimension;        // Primary detector dimension
  double moderator_to_detector; // (m)
  double sample_to_detector;    // (m)
  double detector_angle;        // (degrees)
  double sample_angle;          // (degrees)
  double pixel_width;           // (mm)
  double pixel_height;          // (mm)
  std::vector<double> delta_x;    // detector relative angle (Nx)
  std::vector<double> delta_y;    // detector relative angle (Ny)

  // TOF definition
  int Ndetector_channels;  // (m)
  std::vector<double> detector_tcb;  // detector time channel boundaries (m+1)
  std::vector<double> detector_edges; // detector wavelength edges (m+1)

  // Monitor definition
  double moderator_to_monitor;  // (m)
  int Nmonitor_channels;  // (q)
  std::vector<double> monitor_tcb; // monitor time channel boundaries (q+1)
  std::vector<double> monitor_edges;   // monitor wavelength edges  (q+1)
  std::vector<double> monitor_lambda;  // monitor wavelength (q)
  std::vector<double> monitor_counts;  // raw monitor counts (q)
  std::vector<double> monitor_dcounts; // raw monitor dcounts (q)

  // Processed data
  int Nchannels;      // Number of channels after integration (n)
  int Npixels;        // Number of pixels across the detector (r)
  std::vector<double> bin_edges;      // wavelength at bin edges (n+1)
  std::vector<double> lambda, dlambda;   // wavelength of bins (n)
  std::vector<double> monitor, dmonitor; // binned monitor counts (n)
  std::vector<double> counts, dcounts;   // binned detector counts (r x n)
  std::vector<double> I, dI;             // normalized intensity   (r x n)
  std::vector<double> image_sum;         // sum over all bins (Ny x Nx)


  NXtofnref() {}
  ~NXtofnref() {}
  bool open(const char *file);      // Open the file
  void close(void) { nexus_close(file); }
  void reload(void);                // Load the data

  void set_bins(const std::vector<double>& edges);
  void set_bins(const std::vector<int>& bins);
  void set_bins(double lo, double hi, double percentage=0.);
  void set_primary_dimension(int dim) { primary_dimension = dim; }
  std::vector<double> sum_all_images(void);
  void integrate_counts(void);
  void normalize_counts(void);
  void get_image(std::vector<double>&, int);
  void print_image(int n, std::ostream& out = std::cout);
  void print_counts(int n, std::ostream& out = std::cout);
  void print_summary(std::ostream& out = std::cout);
} ;

/* From Robin Becker <robin@jessikat.fsnet.co.uk>
 * Posted to sci.math.num-analysis on Dec 6 2003, 2:24 pm
 * He does not remember who is the original author.
 */
template <class Real> void 
transpose(int n, int m, Real a[], Real *b = NULL)
{
  int size = m*n;
  if(b!=NULL && b!=a){ /* out of place transpose */
    Real *bmn, *aij, *anm;
    bmn = b + size; /*b+n*m*/
    anm = a + size;
    while(b<bmn) for(aij=a++;aij<anm; aij+=n ) *b++ = *aij;
  }
  else if(n!=1 && m!=1){ /* in place transpose */
    /* PAK: use (n!=1&&m!=1) instead of (size!=3) to avoid vector transpose */
    int i,row,column,current;
    for(i=1, size -= 2;i<size;i++){
      current = i;
      do {
        /*current = row+n*column*/
        column = current/m;
        row = current%m;
        current = n*row + column;
      } while(current < i);

      if (current>i) std::swap(a[i], a[current]);
    }
  }
}

#if 0
// Swap between fortran and C indexing in a 3 dimensional array.
// Should be a clever way to do this in one pass, but instead
// we transpose each matrix separately then swap the ordering of
// the channels. 
template <class Real> void 
c_to_fortran_indexing(int n, int m, int l, Real a[], Real *b = NULL)
{
  if (b==NULL) b=a;
  transpose(l,n*m,a,b);
  for (int i=0; i < l; i++) transpose(n,m,b+i*n*m,b+i*n*m);
}
template <class Real> void 
fortran_to_c_indexing(int n, int m, int l, Real a[], Real *b = NULL)
{
  if (b==NULL) b=a;
  for (int i=0; i < l; i++) transpose(m,n,a+i*n*m,b+i*n*m);
  transpose(n*m,l,b,b);
}
#endif

// rebin_counts(Nx, x, Ix, dIx, Ny, y, Iy, dIy)
// Rebin from the bin edges in x to the bin edges in y where
// I is the counts in each bin and dI is the uncertainty. x and y
// should be of length Nx+1 and Ny+1 respectively.  I and dI should
// be of length Nx and Ny respectively.
template <class Real> void
rebin_counts(const int Nold, const Real xold[], const Real Iold[],
             const int Nnew, const Real xnew[], Real Inew[])
{
  // Note: inspired by rebin from OpenGenie, but using counts per bin rather than rates.

  // Clear the new bins
  for (int i=0; i < Nnew; i++) Inew[i] = 0.;

  // Traverse both sets of bin edges; if there is an overlap, add the portion 
  // of the overlapping old bin to the new bin.
#if 0
  int iold(1), inew(1);
  Real xold_lo = xold[0];
  Real xold_hi = xold[1];
  Real xnew_lo = xnew[0];
  Real xnew_hi = xnew[1];
  while (inew < Nnew && iold < Nold) {
    if ( xnew_hi <= xold_lo ) {
      // new must catch up to old
      xnew_lo = xnew_hi;
      xnew_hi = xnew[++inew];
    } else if ( xold_hi <= xnew_lo ) {
      // old must catch up to new
      xold_lo = xold_hi;
      xold_hi = xold[++iold];
    } else {
      // delta is the overlap of the bins on the x axis
      const Real delta = std::min(xold_hi, xnew_hi) - std::max(xold_lo, xnew_lo);
      const Real width = xold_hi - xold_lo;
      const Real portion = delta/width;

      Inew[inew] += Iold[iold]*portion;
      if ( xnew_hi > xold_hi ) {
	xold_lo = xold_hi;
	xold_hi = xold[++iold];
      } else {
	xnew_lo = xnew_hi;
	xnew_hi = xnew[++inew];
      }
    }
  }
#else
  int iold(0), inew(0);
  while (inew < Nnew && iold < Nold) {
    const Real xold_lo = xold[iold];
    const Real xold_hi = xold[iold+1];
    const Real xnew_lo = xnew[inew];
    const Real xnew_hi = xnew[inew+1];
    if ( xnew_hi <= xold_lo ) inew++;      // new must catch up to old
    else if ( xold_hi <= xnew_lo ) iold++; // old must catch up to new
    else {
      // delta is the overlap of the bins on the x axis
      const Real delta = std::min(xold_hi, xnew_hi) - std::max(xold_lo, xnew_lo);
      const Real width = xold_hi - xold_lo;
      const Real portion = delta/width;

      Inew[inew] += Iold[iold]*portion;
      if ( xnew_hi > xold_hi ) iold++;
      else inew++;
    }
  }
#endif
}

template <class Real> inline void
rebin_counts(const std::vector<Real> &xold, const std::vector<Real> &Iold,
             const std::vector<Real> &xnew, std::vector<Real> &Inew)
{
  assert(xold.size()-1 == Iold.size());
  Inew.resize(xnew.size()-1);
  rebin_counts(Iold.size(), &xold[0], &Iold[0],
               Inew.size(), &xnew[0], &Inew[0]);
}

// rebin_counts(Nx, x, Ix, dIx, Ny, y, Iy, dIy)
// Rebin from the bin edges in x to the bin edges in y where
// I is the counts in each bin and dI is the uncertainty. x and y
// should be of length Nx+1 and Ny+1 respectively.  I and dI should
// be of length Nx and Ny respectively.
template <class Real> void
rebin_intensity(const int Nold, const Real xold[], const Real Iold[], const Real dIold[],
		const int Nnew, const Real xnew[], Real Inew[], Real dInew[])
{
  // Note: inspired by rebin from OpenGenie, but using counts per bin rather than rates.

  // Clear the new bins
  for (int i=0; i < Nnew; i++) dInew[i] = Inew[i] = 0.;

  // Traverse both sets of bin edges, and if there is an overlap, add the portion 
  // of the overlapping old bin to the new bin.
  int iold(0), inew(0);
  while (inew < Nnew && iold < Nold) {
    const Real xold_lo = xold[iold];
    const Real xold_hi = xold[iold+1];
    const Real xnew_lo = xnew[inew];
    const Real xnew_hi = xnew[inew+1];
    if ( xnew_hi <= xold_lo ) inew++;      // new must catch up to old
    else if ( xold_hi <= xnew_lo ) iold++; // old must catch up to new
    else {
      // delta is the overlap of the bins on the x axis
      const Real delta = std::min(xold_hi, xnew_hi) - std::max(xold_lo, xnew_lo);
      const Real width = xold_hi - xold_lo;
      const Real portion = delta/width;

      Inew[inew] += Iold[iold]*portion;
      dInew[inew] += square(dIold[iold]*portion);  // add in quadrature
      if ( xnew_hi > xold_hi ) iold++;
      else inew++;
    }
  }

  // Convert variance to standard deviation.
  for (int i=0; i < Nnew; i++) dInew[i] = sqrt(dInew[i]);
}

template <class Real> inline void
rebin_intensity(const std::vector<Real> &xold, 
		const std::vector<Real> &Iold, const std::vector<Real> &dIold,
		const std::vector<Real> &xnew, 
		std::vector<Real> &Inew, std::vector<Real> &dInew)
{
  assert(xold.size()-1 == Iold.size());
  assert(xold.size()-1 == dIold.size());
  Inew.resize(xnew.size()-1);
  dInew.resize(xnew.size()-1);
  rebin_intensity(Iold.size(), &xold[0], &Iold[0], &dIold[0],
		  Inew.size(), &xnew[0], &Inew[0], &dInew[0]);
}

template <class Real> inline void
compute_uncertainty(const std::vector<Real> &counts, 
		    std::vector<Real> &uncertainty)
{
  uncertainty.resize(counts.size());
  for (size_t i=0; i < counts.size(); i++)
    uncertainty[i] = counts[i] != 0 ? sqrt(counts[i]) : 1.;
}


#endif /* _NXTOFNREF_H */

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
  void load_all_frames(void);
  void load_time_channel_boundaries(void);
  void load_monitor(void);

  void copy_frame(int from, int to); // helper for merge_frames
  void add_frame(int from, int to); // helper for add_frames
  void integrate_counts(void);
  void compute_pixel_angle(void);
  void compute_wavelength(void);
  void rebin_monitor(void);
  void normalize_counts(void);

public:
  Nexus *file;        // File handle
  int nTimeChannels;
  int Nx, Ny;                   // Detector dimensions
  double moderator_to_detector; // (m)
  double sample_to_detector;    // (m)
  double moderator_to_monitor;  // (m)
  double pixel_width;           // (mm)
  double detector_angle;
  double sample_angle;
  std::vector<double> all_frames;
  std::vector<double> tcb;
  std::vector<double> lambda_edges;   // edges of the wavelength bins
  std::vector<double> lambda;     // wavelength (nTimeChannels)
  std::vector<double> dlambda;    // wavelength uncertainty
  std::vector<double> monitor_raw, dmonitor_raw, monitor_raw_lambda;
  std::vector<double> monitor;    // monitor  (nTimeChannels)
  std::vector<double> dmonitor;   // monitor uncertainty
  std::vector<double> delta;      // detector relative angle
  std::vector<double> counts;     // raw detector counts (Ny x nTimeChannels)
  std::vector<double> dcounts;    // raw detector counts uncertainty
  std::vector<double> I;          // normalized detector counts (Ny x nTimeChannels)
  std::vector<double> dI;         // normalized detector counts uncertainty

  std::string name, title;  // Complete filename
  bool is_open;



  NXtofnref() {}
  ~NXtofnref() {}
  bool open(const char *file);    // Open the file
  void close(void) { nexus_close(file); }
  void reload(void);                // Load the data

  std::vector<double> sum_all_frames(void);
  void get_frame(std::vector<double>&, int);
  void print_frame(int n, std::ostream& out = std::cout);
  void print_counts(int n, std::ostream& out = std::cout);
  void merge_frames(int n, int boundaries[]);
  void merge_frames(double lo, double hi, double step);
  void select_frames(double lo, double hi);
  void summary(std::ostream& out = std::cout);
} ;

/* From Robin Becker <robin@jessikat.fsnet.co.uk>
 * Posted to sci.math.num-analysis on Dec 6 2003, 2:24 pm
 * He does not remember who is the original author.
 */
template <class Real> void 
transpose(int n, int m, Real a[], Real b[])
{
  int size = m*n;
  if(b!=a){ /* out of place transpose */
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

// rebin_counts(Nx, x, Ix, dIx, Ny, y, Iy, dIy)
// Rebin from the bin edges in x to the bin edges in y where
// I is the counts in each bin and dI is the uncertainty. x and y
// should be of length Nx+1 and Ny+1 respectively.  I and dI should
// be of length Nx and Ny respectively.
template <class Real> void
rebin_counts(const int Nold, const Real xold[], const Real Iold[], const Real dIold[],
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
rebin_counts(const std::vector<Real> &xold, 
             const std::vector<Real> &Iold, const std::vector<Real> &dIold,
             const std::vector<Real> &xnew, 
             std::vector<Real> &Inew, std::vector<Real> &dInew)
{
  assert(xold.size()-1 == Iold.size());
  assert(xold.size()-1 == dIold.size());
  Inew.resize(xnew.size()-1);
  dInew.resize(xnew.size()-1);
  rebin_counts(Iold.size(), &xold[0], &Iold[0], &dIold[0],
               Inew.size(), &xnew[0], &Inew[0], &dInew[0]);
}


#endif /* _NXTOFNREF_H */

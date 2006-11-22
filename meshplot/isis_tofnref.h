#ifndef _ISIS_TOFNREF_H
#define _ISIS_TOFNREF_H

#include <cassert>
#include <vector>
#include <iostream>
#include <fcntl.h>
#include <unistd.h>
#include "progress.h"


#if 0
#include <stdint.h> // intptr_t
#define DEBUG(a) do { std::cout << a << std::endl; } while (0)
#else
#define DEBUG(a) do { } while (0)
#endif


inline double square(double x) { return x*x; }

class isis_file {
  int fileid;        // File handle
  int offset[11];    // Offsets for sections
  // offset is like IFORMAT except that it is corrected for the
  // presence of the USER section, and includes the header offset 
  // as the first value, preserving 1-origin values for remaining
  // sections.
  int compression;   // DATA_HEADER(1)
  int frame_table;   // DATA_HEADER(3)
  // We are not following the standard ISIS reader code in this
  // implementation.  Rather than special casing data section version <= 2 
  // which does not contain the DATA_HEADER information, we fake 
  // reasonable values for compression and frame_table (0 and 0).

public:
  int version[11];   // Version numbers for sections
  // like IVER, this is corrected for presence of the USER section
  int nTimeRegimes;  // NTRG
  int nTimeChannels; // NTC1
  int nSpectra;      // NSP1
  int nPeriods;      // NPER
  int nDetectors;    // NDET
  int nMonitors;     // NMON
  int nSampleEnvironmentParameters; // NSEP
  int userLength;    // ULEN
  int run;           // RUN
  signed char title[81];    // TITL, with space for null terminator
  signed char instrument[9]; // NAME, with space for null terminator
  std::string name;  // Complete filename
  bool is_open;
  std::vector<double> tcb;

  enum section_number { 
    HEAD=0, // File header
    RUN=1, 
    INSTRUMENT=2, 
    SAMPLE_ENVIRONMENT=3, 
    DAE=4, 
    TCB=5, 
    USER=6, 
    DATA=7, 
    NOTES=8
    // sections 9 and 10 are unused.
  };
  void seek(section_number section, int p); // Jump to position p in a section
  int getint(void);            // Read int from current position
  double getreal(void);        // Read real from current position
  void getbytes(signed char *b, int n); // Read string from current position
  // FIXME call these spectra rather than frames
  int getframes(int data[], int frame, int num_frames); // Read a set of data frames
  int getframes(std::vector<int>& data, int frame, int num_frames);
  void getTimeChannelBoundaries(void);
  bool open(const char *filename);
  void close(void) { 
    if (is_open) DEBUG("Closing " << fileid);
    if (is_open) ::close(fileid); is_open = false; 
  }
  void summary(std::ostream& out = std::cout);

  isis_file() { 
    is_open = false; 
    nTimeRegimes = nTimeChannels = nSpectra = nPeriods 
      = nSampleEnvironmentParameters = nDetectors = nMonitors = 0; 
    userLength = 0;
    run = 0;
    title[0] = '\0';
  }
  ~isis_file() { close(); }
} ;

// Properties of SURF
class SURF : public isis_file
{
  void copy_frame(int from, int to); // helper for merge_frames
  void add_frame(int from, int to); // helper for add_frames
  void load_monitor(void);
  void set_delta(void);
  void set_lambda(void);
  void load_all_frames(void);
  std::vector<int> all_frames;
public:
  const int Nx, Ny;            // Detector dimensions
  const double moderator_to_detector; // (m)
  const double sample_to_detector;     // (m)
  const double moderator_to_monitor;    // (m)
  const double pixel_width;         // (m)
  std::vector<double> lambda_edges; // edges of the wavelength bins
  std::vector<double> lambda;     // wavelength (nTimeChannels)
  std::vector<double> dlambda;    // wavelength uncertainty
  std::vector<double> monitor_raw, dmonitor_raw, monitor_lambda;
  std::vector<double> monitor;    // monitor  (nTimeChannels)
  std::vector<double> dmonitor;   // monitor uncertainty
  std::vector<double> delta;      // detector relative angle
  std::vector<double> counts;     // raw detector counts (Ny x nTimeChannels)
  std::vector<double> dcounts;    // raw detector counts uncertainty
  std::vector<double> I;          // normalized detector counts (Ny x nTimeChannels)
  std::vector<double> dI;         // normalized detector counts uncertainty

  SURF() :
  Nx(40), Ny(46),               // Detector dimensions
  moderator_to_detector(11.84), // (m)
  sample_to_detector(2.84),     // (m)
  moderator_to_monitor(8.5),    // (m)
  pixel_width(-0.0023)          // (m)
  { set_delta(); }
  ~SURF() {}
  bool open(const char *file);    // Open the file
  void load(void);                // Load the data
  void getframe(std::vector<double>& frame, int i);  // Return a particular frame
  std::vector<int> sum_all_frames(void);
  // Note: for isis files, we need to preload all frames because they are stored
  // transposed.  For other file formats we may be able to load one frame at a time.
  // Unless the frames are enormous, though, lazy loading is probably sufficient.
  // For enormous frames the program should probably cache the loaded frames to 
  // support rapid switching between consecutive frames.  
  void printframe(int n, std::ostream& out = std::cout);
  void printcounts(int n, std::ostream& out = std::cout);
  void printspectrum(int n, std::ostream& out = std::cout);
  void merge_frames(int n, int boundaries[]);
  void merge_frames(double lo, double hi, double step);
  void select_frames(double lo, double hi);
  void integrate_counts(ProgressMeter *meter);
  void normalize_counts(void);
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


#endif /* _ISIS_TOFNREF_H */

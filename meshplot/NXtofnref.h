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
#include "progress.h"

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
  void integrate_counts(ProgressMeter*);
  void normalize_counts(void);
  void get_image(std::vector<double>&, int);
  void print_image(int n, std::ostream& out = std::cout);
  void print_counts(int n, std::ostream& out = std::cout);
  void print_summary(std::ostream& out = std::cout);
} ;

#endif /* _NXTOFNREF_H */

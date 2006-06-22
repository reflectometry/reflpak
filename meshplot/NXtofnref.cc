#include <cmath>
#include <vector>
#include <iomanip>
#include <iostream>
#include <string>
#include <algorithm> // min, max, swap
#include <fstream>

// For open() and read()
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include <napi.h>
typedef int NXdims[NX_MAXRANK];  // Should be part of napi.h

#if 0
#include <stdint.h> // intptr_t
#define DEBUG(a) do { std::cout << a << std::endl; } while (0)
#else
#define DEBUG(a) do { } while (0)
#endif

#include "NXtofnref.h"
#include "NXtofnref_keys.icc"

// =======================================================================
// Utility functions


// Convert time of flight to wavelength
const double Plancks_constant=6.62618e-27; // Planck constant (erg*sec)
const double neutron_mass=1.67495e-24;     // neutron mass (g)
inline double 
TOF_to_wavelength(double d)  // distance (m)
{
  return Plancks_constant/(neutron_mass*d);
}

// Detector pixel angle as a function of pixel width and detector distance
static void 
compute_pixel_angle(int n, double delta[], double pixelwidth, 
		    double detectordistance)
{
  // Set y coordinates
  for (int i=0; i < n; i++) {
    delta[i] = 180./M_PI*atan2(pixelwidth*(i+1-n/2.),detectordistance);
    //    std::cout << "atan2(" << pixelwidth*(i-n/2.) << "," << detectordistance << ") = " << delta[i] << std::endl;
  }
}

// ======================================================================
// Nexus file handling functions

// Grab the first NXtofnref entry in the file.
//
// Result: file
bool NXtofnref::open(const char *filename)
{
  file = nexus_open(filename, "r");
  name = filename;

  while (1) {
    if (!nexus_nextset(file)) break;
    if (strcmp(file->definition,"NXtofnref")!=0) continue;
    reload();
    return true;
  }
  nexus_close(file);
  return false;
}


void NXtofnref::reload(void)
{
  title = file->entry;
  load_instrument();
  load_time_channel_boundaries();
  load_monitor();
  load_all_frames();
  compute_pixel_angle();
  compute_wavelength();
  rebin_monitor();
  integrate_counts();
  normalize_counts();
}


void NXtofnref::load_instrument(void)
{
  double moderator_distance, monitor_distance;
  NexusDim dims;

  if (!nexus_dims(file, DETECTOR_DATA, &dims)) return;
  nTimeChannels = dims.size[dims.rank-1];
  Nx = Ny = 1;
  if (dims.rank > 1) Ny = dims.size[0];
  if (dims.rank > 2) Nx = dims.size[1];

  // std::cout << "dims = " << Ny << "x" << Nx << "x" << nTimeChannels << std::endl;

  nexus_read(file, DETECTOR_DISTANCE, &sample_to_detector, 1);
  nexus_read(file, PIXEL_WIDTH, &pixel_width, 1);
  nexus_read(file, DETECTOR_ANGLE, &detector_angle, 1);
  nexus_read(file, SAMPLE_ANGLE, &sample_angle, 1);
  nexus_read(file, MODERATOR_DISTANCE, &moderator_distance, 1);
  nexus_read(file, MONITOR_DISTANCE, &monitor_distance, 1);
  // Items before the sample have negative distance, so subtract.
  moderator_to_detector = sample_to_detector - moderator_distance;
  moderator_to_monitor = monitor_distance - moderator_distance;

  // std::cout << "instrument loaded\n";
}


// Load the detector time channels into tcb and set nTimeChannels.
//
// Result: nTimeChannels, tcb
void NXtofnref::load_time_channel_boundaries(void)
{
  // std::cout << "loading time channels\n";
  NexusDim dims;
  if (nexus_dims(file, TIME_CHANNEL_BOUNDARIES, &dims)) {
    assert(dims.rank == 1);
    tcb.resize(dims.size[0]);
    if (nexus_read(file, TIME_CHANNEL_BOUNDARIES, &tcb[0], dims.size[0]))
      nTimeChannels = dims.size[0]-1;
  }
  // std::cout << "loading time channels done\n";
}

// Load the monitor values.  Computes monitor uncertainty and bin wavelengths.
//
// Result: monitor_raw, dmonitor_raw, monitor_raw_lambda
void NXtofnref::load_monitor(void)
{
  // std::cout << "loading monitor\n";
  // Load raw monitor counts
  monitor_raw.resize(nTimeChannels);
  dmonitor_raw.resize(nTimeChannels);

  nexus_read(file,MONITOR_DATA,&monitor_raw[0],nTimeChannels);
  //for (int i=0;i<nTimeChannels;i+=100) DEBUG(i<<": "<<monitor_raw[i]<<" ");

  // Compute monitor uncertainty
  for (int i=0; i < nTimeChannels; i++) {
    dmonitor_raw[i] = monitor_raw[i] != 0 ? sqrt(monitor_raw[i]) : 1.;
  }

  // Compute wavelength at the centers of the monitor bins
  monitor_raw_lambda.resize(nTimeChannels);
  const double scale = TOF_to_wavelength(moderator_to_monitor); 
  for (int i=0; i < nTimeChannels; i++) 
    monitor_raw_lambda[i] = (tcb[i]+tcb[i+1])*scale/2.;
  // std::cout << "loading monitor done\n";
}

// Load all detector frames
//
// Result: frames
// Frames are Ny by Nx, with x varying fastest.  
//   00 01 02 ... 0Nx 10 11 12 ... 1Nx ...
// Integrate along x to simulate a linear detector.
// Frames are stored one after the other.
void NXtofnref::load_all_frames(void)
{
  // std::cout << "loading frames\n";
  all_frames.resize(Nx*Ny*nTimeChannels);
  if (nexus_read(file, DETECTOR_DATA, &all_frames[0], Nx*Ny*nTimeChannels)) {
    // std::cout << "transposing\n";
    transpose(nTimeChannels, Nx*Ny, &all_frames[0]);
  }
  // std::cout << "loading frames done\n";
}


void NXtofnref::summary(std::ostream& out)
{
  out << name << ": "  << title << std::endl;
  out << " Time channels: " << nTimeChannels
      << " Spectra: " << Nx*Ny << std::endl
      << std::endl;
}



// ==================================================================
// TOF calculations


// Rebin monitor bins to match detector wavelength channels.
//
// Result: monitor, dmonitor
//
// Must be used in this sequence:
//   load_time_channel_boundaries
//   load_monitor
//   compute_wavelength
//   rebin_monitor
// Will not work correcting after select/merge frames.
void NXtofnref::rebin_monitor(void)
{
  // Compute wavelength at the time boundaries for the monitor
  const double scale = TOF_to_wavelength(moderator_to_monitor); 
  std::vector<double> monitor_edges(nTimeChannels+1);
  for (int i = 0; i <= nTimeChannels; i++) 
    monitor_edges[i] = tcb[i]*scale;

  DEBUG("about to rebin");

  // Rebin monitor bins to detector bins of the same wavelength.
  rebin_counts(monitor_edges,monitor_raw,dmonitor_raw,
	       lambda_edges,monitor,dmonitor);
}


// Determine wavelength for each time channel from the center of the time bins.
// Stores the result in lambda, dlambda and lambda_edges.
void NXtofnref::compute_wavelength(void)
{
  // Use the usual formula for TOF to lambda, *100. for units.
  lambda.resize(nTimeChannels);
  dlambda.resize(nTimeChannels);
  lambda_edges.resize(nTimeChannels+1);
  const double scale = TOF_to_wavelength(moderator_to_detector);
  for (int i=0; i <= nTimeChannels; i++) lambda_edges[i] = tcb[i]*scale;
  for (int i=0; i < nTimeChannels; i++) {
    lambda[i] = 0.5 * (tcb[i] + tcb[i+1])*scale;
    // FIXME incorrect formula for dlambda
    dlambda[i] = (tcb[i+1] - tcb[i])/sqrt(log10(256.))*scale; 
  }
  DEBUG("setting lambda(" << lambda.size() << ") at " << intptr_t(&lambda[0]));
}


// for each frame applyDetectorEfficiencyCorrection(frame);


// Return a particular frame
void NXtofnref::get_frame(std::vector<double>& frame, int n)  
{
  frame.resize(Nx*Ny);
  const int offset = n * Nx*Ny;
  for (int i=0; i < Nx*Ny; i++) frame[i] = all_frames[offset+i];
}

// Compute pixel solid angle from pixel width and detector distance
void NXtofnref::compute_pixel_angle(void)
{
  delta.resize(Ny);
  ::compute_pixel_angle(Ny,&delta[0],pixel_width,sample_to_detector);
}

 
void NXtofnref::integrate_counts(void)
{
  // Reset counts vector
  counts.resize(Ny*nTimeChannels, 0);
  dcounts.resize(Ny*nTimeChannels);

  // Sum across x
  std::vector<int> frame(nTimeChannels);
  for (int k=0; k < nTimeChannels; k++) {
    for (int j=0; j < Ny; j++) {
      double sum = 0.;
      const int offset = k*Nx*Ny + j;
      for (int i=0; i < Nx; i++) sum += all_frames[offset+i*Ny];
      counts[k*Ny+j] = sum;
    }
  }     

  for (int i=0; i < Ny*nTimeChannels; i++) 
    dcounts[i] = counts[i] != 0. ? sqrt(counts[i]) : 1.;
}


// Compute I,dI from counts and monitors
void NXtofnref::normalize_counts(void)
{
  I.resize(Ny*nTimeChannels);
  dI.resize(Ny*nTimeChannels);
  for (int k=0; k < nTimeChannels; k++) {
    const double mon = (monitor[k] == 0. ? 1. : monitor[k]);
    const double dmon_mon_sq = dmonitor[k] / square(mon);
    const int offset = k*Ny;
    for (int j=0; j < Ny; j++) {
      dI[offset+j] = sqrt(square(dcounts[offset+j]/mon) + square(counts[offset+j] * dmon_mon_sq));
      I[offset+j] = counts[offset+j]/mon;
    }
  }
}

// Must load all frames at once with ISIS file format; don't need to 
// for NeXus, but keep life simple for now.
std::vector<double> 
NXtofnref::sum_all_frames(void)
{
  std::vector<double> frame(Nx*Ny,0);
  for (int k = 0; k < nTimeChannels; k++) {
    const int offset = k * Nx * Ny;
    for (int i = 0; i < Nx*Ny; i++) frame[i] += all_frames[offset+i];
  }
  return frame;
}


// ======================================================================
// Rebinning frames
template <class T>
static void copy_chunk(int n, T* from, T* to)
{
  memcpy(to, from, n*sizeof(T));
}
template <class T>
static void add_chunk(int n, T* from, T* to)
{
  for (int k=0; k < n; k++) to[k] += from[k];
}
template <class T>
static void copy_chunk_square(int n, T* from, T* to)
{
  for (int k=0; k < n; k++) to[k] = from[k]*from[k];
}
template <class T>
static void add_chunk_square(int n, T* from, T* to)
{
  for (int k=0; k < n; k++) to[k] += from[k]*from[k];
}

void NXtofnref::copy_frame(int from, int to)
{
  if (from == to) return;
  copy_chunk(Nx*Ny,&all_frames[from*Nx*Ny],&all_frames[to*Nx*Ny]);
  copy_chunk(Ny,&counts[from*Ny],&counts[to*Ny]);
  copy_chunk_square(Ny,&dcounts[from*Ny],&dcounts[to*Ny]);
  copy_chunk(Ny,&I[from*Ny],&I[to*Ny]);
  copy_chunk_square(Ny,&dI[from*Ny],&dI[to*Ny]);
  monitor[to] = monitor[from];
  dmonitor[to] = square(dmonitor[from]);
  tcb[to] = tcb[from];
}

void NXtofnref::add_frame(int from, int to)
{
  add_chunk(Nx*Ny,&all_frames[from*Nx*Ny],&all_frames[to*Nx*Ny]);
  add_chunk(Ny,&counts[from*Ny],&counts[to*Ny]);
  add_chunk_square(Ny,&dcounts[from*Ny],&dcounts[to*Ny]);
  add_chunk(Ny,&I[from*Ny],&I[to*Ny]);
  add_chunk_square(Ny,&dI[from*Ny],&dI[to*Ny]);
  monitor[to] += monitor[from];
  dmonitor[to] += square(dmonitor[from]);
}

// Given a list [b_1 b_2 ... b_{n+1}], sum all data from b_i to b_{i+1}-1
// and save it if frame i.  Note that there are n+1 boundaries for n channels.
//
// The current implementation is defined to operate in-place, but there is
// no performance reason to do so.  In fact, because it resizes the memory
// down to the new size, it effectively does a copy.
void NXtofnref::merge_frames(int n, int boundaries[])
{
  for (int k=0; k < n; k++) {
    copy_frame(boundaries[k], k);
DEBUG("merging " << boundaries[k] << " to " << boundaries[k+1] << " into " << k);
    for (int i=boundaries[k]+1; i < boundaries[k+1]; i++) add_frame(i,k);
  }
  // Adding in quadrature; take square roots
  for (int k=0; k < n; k++) {
    dmonitor[k] = sqrt(dmonitor[k]);
  }
  for (int k=0; k < n*Ny; k++) {
    dI[k] = sqrt(dI[k]);
    dcounts[k] = sqrt(dcounts[k]);
  }
  // Throw away unneeded memory (really only need to do this for all_frames)
  all_frames.resize(n*Nx*Ny);
  I.resize(n*Ny);
  dI.resize(n*Ny);
  counts.resize(n*Ny);
  dcounts.resize(n*Ny);
  monitor.resize(n);
  dmonitor.resize(n);
  tcb[n] = tcb[boundaries[n]];
  tcb.resize(n+1);
  nTimeChannels = n;
DEBUG("rebin n=" << n << ", Ny=" << Ny);
  compute_wavelength();
}

void NXtofnref::select_frames(double lo, double hi)
{
  int ilo=1;
  while (ilo <= nTimeChannels && lambda_edges[ilo] <= lo) ilo++;
  ilo--;
  int ihi=ilo+1;
  while (ihi < nTimeChannels && lambda_edges[ihi] < hi) ihi++;

  std::vector<int> ichannels(ihi-ilo+1);
  for (int i=ilo; i <= ihi; i++) ichannels[i-ilo] = i;

  merge_frames(ihi-ilo,&ichannels[0]);
}

void NXtofnref::merge_frames(double lo, double hi, double percent)
{
  if (percent == 0.) {
    select_frames(lo,hi);
    return;
  }

  // Convert percent to step
  const double step = percent/100.+1.;

  // Count bins
  int n=0;
  double next=lo;
  while (next < hi) { next*=step; n++; }
  std::vector<int> ichannels(n+1);

  int i=1,k=0;
  while (i <= nTimeChannels && lambda_edges[i] <= lo) i++;
  ichannels[k++] = i-1;
  next=lo*step;
  while (i <= nTimeChannels && lambda_edges[i] <= hi) {
    if (lambda_edges[i] > next) {
      ichannels[k++] = i;
      next *= step;
    }
    i++;
  }
  while (k <= n) ichannels[k++] = i; 

  merge_frames(n, &ichannels[0]);
}

void NXtofnref::print_frame(int n, std::ostream& out)
{
  out << "# " << name << ": " << title << std::endl;
  out << "# frame " << n << std::endl;
  const int offset = n*Nx*Ny;
  for (int i=0; i < Nx; i++) {
    for (int j=0; j < Ny; j++) 
      out << std::setw(10) << all_frames[offset+j+i*Ny];
    out << std::endl;
  }
}

void NXtofnref::print_counts(int n, std::ostream& out)
{
  for (int j=0; j < Ny; j++) 
    out << " " << std::setw(10) << log10(1.+counts[n*Ny + j]);
  out << std::endl;
}



#if defined(STANDALONE)
static void
print_sum_all_frames(NXtofnref& data, std::ostream& out = std::cout)
{
  out << "# " << data.name << ": " << data.title << std::endl;
  out << "# sum of all frames" << std::endl;
  std::vector<double> frame(data.sum_all_frames());
  for (int i=0; i < data.Nx; i++) {
    for (int j=0; j < data.Ny; j++) 
      out << " " << std::setw(10) << frame[j+i*data.Ny];
    out << std::endl;
  }
}

static void
print_integrated_counts(NXtofnref& data, std::ostream& out = std::cout)
{
  out << "# " << data.name << ": " << data.title << std::endl;
  out << "# integrated counts" << std::endl;
  for (int i=0; i < data.nTimeChannels; i++) data.print_counts(i, out);
}

static void
print_normalized_counts(NXtofnref& data, std::ostream& out = std::cout)
{
  // Find the data floor before plotting log data
  int start=std::min(data.nTimeChannels,80), stop=std::min(data.nTimeChannels,850);
  double floor = 1e308;
  for (int i=start*data.Ny; i <= stop*data.Ny; i++) {
    const double d = data.I[i];
    if (d > 0. && d < floor) floor = d;
  }
  floor = floor/2.;

  out << "# " << data.name << ": " << data.title << std::endl;
  out << "# normalized counts" << std::endl;
  for (int k=start; k <= stop; k++) {
    for (int j=0; j < data.Ny; j++) {
      const double d = data.I[k*data.Ny + j];
      out << " " << std::setw(10) << log10(d<floor ? floor : d);
    }
    out << std::endl;
  }
}

static void
print_monitor(NXtofnref& data, std::ostream& out = std::cout)
{
  out << "# " << data.name << ": " << data.title << std::endl;
  out << "# rebinned monitor" << std::endl;
  out << "# lambda I dI" << std::endl;
  for (int i=0; i < data.nTimeChannels; i++) {
    out << std::setw(20) << data.lambda[i] << " " << std::setw(20) << data.monitor[i] 
        << " " << std::setw(20) << data.dmonitor[i] << std::endl;
  }
}

#define WRITE(file, junk) do { std::ofstream out(file); junk; } while (0)
int main(int argc, char *argv[])
{
  NXtofnref data;
  if (argc > 1) {
    data.open(argv[1]);
    data.summary();
    for (int i=0; i < data.nTimeChannels; i+=50) {
      char filename[50]; sprintf(filename,"frame%03d.dat",i);
      WRITE(filename, data.print_frame(i, out));
    }
    WRITE("framesum.dat", print_sum_all_frames(data, out));
    WRITE("counts.dat", print_integrated_counts(data, out));
    WRITE("norm.dat", print_normalized_counts(data, out));
    WRITE("monitor.dat", print_monitor(data, out));
  }
}

#endif

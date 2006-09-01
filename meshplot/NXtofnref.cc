// This is a work of the United States Government and is not
// subject to copyright protection in the United States.

#include <cassert>
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

#if 1
#include <stdint.h> // intptr_t needed for some statements
#define DEBUG(a) do { std::cout << a << std::endl; } while (0)
#else
#define DEBUG(a) do { } while (0)
#endif
#define ERROR(a) do { std::cerr << a << std::endl; } while (0)

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

int array_size(NexusDim& dims) 
{
  int t=1;
  for (int i=0; i < dims.rank; i++) t*=dims.size[i];
  return t;
}

void NXtofnref::find_channels(double vlo, double vhi, int &ilo, int &ihi)
{
  // find range of channels needed
  for (ilo=1; ilo < Ndetector_channels; ilo++)
    if (detector_edges[ilo]>vlo) break;
  for (ihi=ilo; ihi < Ndetector_channels; ihi++)
    if (detector_edges[ihi]>=vhi) break;
  ilo--;
  assert(ilo == 0 || detector_edges[ilo] <= vlo);
  assert(ilo == Ndetector_channels || detector_edges[ilo+1] > vlo);
  assert(ihi == Ndetector_channels || detector_edges[ihi] >= vhi);
  assert(ihi == 0 || detector_edges[ihi-1] < vhi);
}


// ======================================================================
// Nexus file handling functions

// Grab the first NXtofnref entry in the file.
//
// Result: file
bool NXtofnref::open(const char *filename)
{
  DEBUG("open " << filename);
  file = nexus_open(filename, "r");
  name = filename;

  while (1) {
    if (!nexus_nextset(file)) break;
    DEBUG("checking definition " << file->definition);
    // FIXME change this to definition NXtofnref?
    if (strcmp(file->definition,DEFINITION_NAME)!=0) continue;
    DEBUG("loading dataset " << filename);
    reload();
    return true;
  }
  nexus_close(file);
  return false;
}


void NXtofnref::reload(void)
{
  title = file->entry;
  DEBUG("load_instrument");
  load_instrument();
  DEBUG("load_detector_tcb");
  load_detector_tcb();
  DEBUG("load_monitor");
  load_monitor();
  DEBUG("load_pixel_angle");
  load_pixel_angle();
  DEBUG("load complete");
  // integrate_counts();
  // normalize_counts();
}

void NXtofnref::load_instrument(void)
{
  double moderator_distance, monitor_distance;
  NexusDim dims;

  DEBUG("dims for " << DETECTOR_DATA);
  if (!nexus_dims(file, DETECTOR_DATA, &dims)) return;
  data_rank = dims.rank;
  Ndetector_channels = dims.size[dims.rank-1];
  Nx = Ny = 1;
  if (dims.rank > 1) Nx = dims.size[0];
  if (dims.rank > 2) Ny = dims.size[1];
  // FIXME need to check whether we have a horizontal or vertical
  // geometry reflectometer
  primary_dimension = 0;
  Npixels = (primary_dimension == 0?Nx:Ny);

  DEBUG("dims = " << Nx << "x" << Ny << "x" << Ndetector_channels);

  DEBUG(DETECTOR_DISTANCE);
  sample_to_detector = 0;
  if (nexus_dims(file, DETECTOR_DISTANCE, &dims)) {
    int Ndistances = array_size(dims);
    std::vector<double> pixel_distance(Ndistances);
    if (nexus_read(file, DETECTOR_DISTANCE, &pixel_distance[0], Ndistances)) {
      // Compute mean distance to the detector pixels.
      double sum=0.;
      for (int i=0; i < Ndistances; i++) sum += pixel_distance[i];
      sample_to_detector = sum/Ndistances; 
    }
  }
  

#if 1

  if (data_rank == 3) {
    // pixel offsets, no pixel width
    std::vector<double> offset;

    offset.resize(Nx);
    nexus_read(file, X_PIXEL_OFFSET, &offset[0], Nx);
    double sum = 0.;
    for (int i=0; i < Nx; i++) sum += offset[i];
    pixel_width = 1000.*sum/Nx; // Average pixel width in mm

    offset.resize(Ny);
    nexus_read(file, Y_PIXEL_OFFSET, &offset[0], Ny);
    sum = 0.;
    for (int i=0; i < Ny; i++) sum += offset[i];
    pixel_height = 1000.*sum/Ny; // Average pixel width in mm
  } else if (data_rank == 2) {
    std::vector<double> offset(Nx);
    nexus_read(file, PIXEL_OFFSET, &offset[0], Nx);
    double sum = 0.;
    for (int i=0; i < Nx; i++) sum += offset[i];
    pixel_width = pixel_height = 1000.*sum/Nx; // Average pixel width in mm
  } else {
    assert(data_rank == 1);
    pixel_width = pixel_height = 1;
  }

#else

  // pixel width, no pixel offsets
  DEBUG(PIXEL_WIDTH);
  nexus_read(file, PIXEL_WIDTH, &pixel_width, 1);
  DEBUG(PIXEL_HEIGHT);
  nexus_read(file, PIXEL_HEIGHT, &pixel_width, 1);

#endif

  DEBUG(DETECTOR_ANGLE);
  if (!nexus_read(file, DETECTOR_ANGLE, &detector_angle, 1))
    detector_angle = 0;
  DEBUG(SAMPLE_ANGLE);
  if (!nexus_read(file, SAMPLE_ANGLE, &sample_angle, 1))
    sample_angle = 0;
  DEBUG(MODERATOR_DISTANCE);
  nexus_read(file, MODERATOR_DISTANCE, &moderator_distance, 1);
  DEBUG(MONITOR_DISTANCE);
  nexus_read(file, MONITOR_DISTANCE, &monitor_distance, 1);
  DEBUG(PRE_SLIT1);
  nexus_readslit(file, PRE_SLIT1, 
		 &slit_distance[0], &slit_width[0], &slit_height[0]);
  DEBUG(PRE_SLIT2);
  nexus_readslit(file, PRE_SLIT2, 
		 &slit_distance[1], &slit_width[1], &slit_height[1]);
  DEBUG(POST_SLIT1);
  nexus_readslit(file, POST_SLIT1, 
		 &slit_distance[2], &slit_width[2], &slit_height[2]);
  DEBUG(POST_SLIT2);
  nexus_readslit(file, POST_SLIT2, 
		 &slit_distance[3], &slit_width[3], &slit_height[3]);
  // Note: test file REF_M_50.nxs has a positive moderator distance
  if (moderator_distance > 0) moderator_distance = -moderator_distance;
  // Items before the sample have negative distance, so subtract.
  moderator_to_detector = sample_to_detector - moderator_distance;
  moderator_to_monitor = monitor_distance - moderator_distance;

  DEBUG("instrument loaded");
}


// Load the detector time channel boundaries into detector_tcb.
//
// Result: Ndetector_channels, detector_tcb, detector_edges
void NXtofnref::load_detector_tcb(void)
{
  // DEBUG("loading time channels");
  NexusDim dims;
  if (nexus_dims(file, DETECTOR_TCB, &dims)) {
    assert(dims.rank == 1);
    detector_tcb.resize(dims.size[0]);
    if (nexus_read(file, DETECTOR_TCB, &detector_tcb[0], dims.size[0]))
      Ndetector_channels = dims.size[0]-1;
  }
  // DEBUG("loading time channels done");

  const double scale = TOF_to_wavelength(moderator_to_detector);
  detector_edges.resize(Ndetector_channels+1);
  for (int i=0; i <= Ndetector_channels; i++) 
    detector_edges[i] = detector_tcb[i]*scale;

  // Not yet integrated
  Nchannels = 0;
}

// Load the monitor values.  Computes monitor uncertainty and bin wavelengths.
//
// Result: monitor_counts, monitor_dcounts, monitor_edges, monitor_lambda
void NXtofnref::load_monitor(void)
{
  // DEBUG("loading monitor");

#if 1

  // Monitor tcb and detector tcb stored separately
  NexusDim dims;
  Nmonitor_channels = 0;
  DEBUG("reading dims for " << MONITOR_TCB);
  if (nexus_dims(file, MONITOR_TCB, &dims)) {
    assert(dims.rank == 1);
    monitor_tcb.resize(dims.size[0]);
    DEBUG("reading data length " << dims.size[0] << " for " << MONITOR_TCB);
    if (nexus_read(file, MONITOR_TCB, &monitor_tcb[0], dims.size[0]))
      Nmonitor_channels = dims.size[0]-1;
  }
  DEBUG("Nmonitor_channels = " << Nmonitor_channels);
  if (Nmonitor_channels<2) return;

#else

  // Monitor tcb and detector tcb are equivalent
  Nmonitor_channels = Ndetector_channels;
  monitor_tcb.resize(Nmonitor_channels+1);
  for (int i = 0; i <= Ndetector_channels; i++)
    monitor_tcb[i] = detector_tcb[i];

#endif

  // Load raw monitor counts
  monitor_counts.resize(Nmonitor_channels);
  nexus_read(file,MONITOR_DATA,&monitor_counts[0],Nmonitor_channels);
  compute_uncertainty(monitor_counts, monitor_dcounts);

  // Compute wavelength at the edges of the monitor bins
  const double scale = TOF_to_wavelength(moderator_to_monitor); 
  monitor_edges.resize(Nmonitor_channels+1);
  for (int i = 0; i <= Nmonitor_channels; i++)
    monitor_edges[i] = monitor_tcb[i]*scale;

  // Compute wavelength at the centers of the monitor bins
  monitor_lambda.resize(Nmonitor_channels);
  for (int i=0; i < Nmonitor_channels; i++) 
    monitor_lambda[i] = (monitor_tcb[i]+monitor_tcb[i+1])*scale/2.;
}



// ==================================================================
// TOF calculations


// Reset binning.
// Assigns the wavelength for the bin centers and edges, and rebins the
// monitor to the new binning.
// Stores the wavelength info in bin_edges, lambda, dlambda and the
// monitor info in monitor, dmonitor.
void NXtofnref::set_bins(const std::vector<double>& edges)
{
  Nchannels = edges.size()-1;
  bin_edges.resize(Nchannels+1);
  lambda.resize(Nchannels);
  dlambda.resize(Nchannels);

  // bin edges are wavelengths
  for (int i=0; i <= Nchannels; i++) bin_edges[i] = edges[i];
  for (int i=0; i < Nchannels; i++) {
    lambda[i] = 0.5 * (edges[i] + edges[i+1]);
    // FIXME incorrect formula for dlambda
    dlambda[i] = (edges[i+1] - edges[i])/sqrt(log10(256.));
  }

#if 0
  // Dead code from when bin edges are times
  const double scale = TOF_to_wavelength(moderator_to_detector);
  for (int i=0; i <= Nchannels; i++) bin_edges[i] = tcb[i]*scale;
  for (int i=0; i < Nchannels; i++) {
    lambda[i] = 0.5 * (tcb[i] + tcb[i+1])*scale;
    // FIXME incorrect formula for dlambda
    dlambda[i] = (tcb[i+1] - tcb[i])/sqrt(log10(256.))*scale; 
  }
#endif

  // Rebin monitor bins to detector bins of the same wavelength.
  if (Nmonitor_channels) {
    rebin_counts(monitor_edges,monitor_counts,bin_edges,monitor);
    compute_uncertainty(monitor,dmonitor);
  }
}


// Set bin edges according to a vector of channel numbers.  Each bin
// spans from the start of its channel to the start of the channel for
// the next bin.  You will need one more channel than the number of
// bins so that the width of the final bin is defined.  Channels should 
// be monotonically increasing integers in the interval 0 to 
// Ndetector_channels.
//
// E.g., group bins in sets of 10:
//    [0, 10, 20, 30, 40, 50, ..., Ndetector_channels+1]
void NXtofnref::set_bins(const std::vector<int>& channels)
{
  int n = channels.size();
  std::vector<double> edges(n);
  int last = 0;
  for (int i=0; i < n; i++) {
    if (channels[i] < last) 
      edges[i] = detector_edges[last];
    else if (channels[i] > Ndetector_channels) 
      edges[i] = detector_edges[Ndetector_channels];
    else {
      edges[i] = detector_edges[channels[i]];
      last = channels[i];
    }
  }

  set_bins(edges);
}

// Proportional binning from wavelengths lo to hi by percent.  If percent
// is 0%, then use linear binning.
void NXtofnref::set_bins(double vlo, double vhi, double percent)
{
  std::vector<double> edges;

  if (percent <= 0.) {

    int ilo, ihi;
    find_channels(vlo, vhi, ilo, ihi);

    // Set bin boundaries
    int n = ihi-ilo;
    edges.resize(n+1);
    for (int i=0; i <= n; i++) edges[i] = detector_edges[ilo+i];

  } else {

    // Convert percent to step
    const double step = percent/100.+1.;

    // Count bins
    int n=0;
    double next=vlo;
    while (next < vhi) { next*=step; n++; }
    
    // Set bin boundaries
    edges.resize(n+1);
    edges[0] = vlo;
    for (int i=1; i <= n; i++) edges[i] = edges[i-1]*step;
  }

  set_bins(edges);
}


// FIXME for each image applyDetectorEfficiencyCorrection(image);

// Return the rebinned detector image for a particular time
void NXtofnref::get_image(std::vector<double>& image, int n)
{ 
  assert(data_rank == 3); // No support yet for linear or point detectors

  // TODO: ought to use caching rather than reading the image
  // each time it is needed.

  image.resize(Nx*Ny);
  double edges[2] = { bin_edges[n], bin_edges[n+1] };
  int lo, hi;
  find_channels(edges[0], edges[1], lo, hi);
  int Nk = hi-lo+1;

  DEBUG("reading image " << n << " from channels " << lo << " to " << hi);
  DEBUG("rebinning " << detector_edges[lo] << "-" << detector_edges[hi]
	<< " into " << edges[0] << "-" << edges[1]);
  if (Nk*Ny*Nx > 10000000) {
    DEBUG("processing individual channels");
    // Too many channels to process the entire slab as one block;
    // read individual time channels separately.
    int start[3] = {0, 0, lo};
    int size[3] = {1, 1, Nk};
    std::vector<double> data(Nk);

    for (int i=0; i < Nx; i++) {
      for (int j=0; j < Ny; j++) {
	start[0] = i; start[1] = j;
	if (!nexus_readslab(file, DETECTOR_DATA, &data[0], start, size)) {
	  ERROR("could not read channels " << lo << "-" << lo+Nk-1 << " from pixel " << i << "," << j << " of " << DETECTOR_DATA);
	  return; // FIXME what to do with error?
	}
	rebin_counts(Nk, &detector_edges[lo], &data[0],
		     1, edges, &image[i*Ny+j]);
      }
    }
  } else {
    DEBUG("processing entire slab");
    // Read entire slab and process each pixel separately
    int start[3] = {0, 0, lo};
    int size[3] = {Nx, Ny, Nk};
    
    // TODO: Should check for excessively large numbers of channels
    // in that case, read and process each time channel separately.
    std::vector<double> data(Nx*Ny*Nk);
    if (!nexus_readslab(file, DETECTOR_DATA, &data[0], start, size)) {
      ERROR("could not read channels " << lo << "-" << lo+Nk-1 << " from all pixels of " << DETECTOR_DATA);
      return; // FIXME what to do with error?
    }
    
    for (int i=0; i < Nx; i++) {
      for (int j=0; j < Ny; j++) {
	rebin_counts(Nk, &detector_edges[lo],&data[(i*Ny+j)*Nk],
		     1, edges, &image[i*Ny+j]);
	double sum=0.;
	// for (int k=0; k < Nk; k++) sum += data[(i*Ny+j)*Nk];
	// DEBUG(" " << i << "," << j << ": " << sum << " -> " << image[i*Ny+j]);
      }
    }
  }
}

// Get the pixel angle associated with each bin of the detector
void NXtofnref::load_pixel_angle(void)
{
  // If it is not stored in the nexus file like it should be, compute 
  // pixel angle from pixel width and detector distance
  delta_x.resize(Nx);
  compute_pixel_angle(Nx,&delta_x[0],pixel_width,sample_to_detector);
  delta_y.resize(Ny);
  compute_pixel_angle(Ny,&delta_y[0],pixel_height,sample_to_detector);
}

 
void NXtofnref::integrate_counts(void)
{
  // Use the current number of pixels
  Npixels = (primary_dimension == 0?Nx:Ny);

  // Reset counts vector
  counts.resize(Npixels*Nchannels, 0);
  image_sum.resize(Nx*Ny);

  // Find channels we care about
  int lo, hi;
  find_channels(bin_edges[0], bin_edges[Nchannels], lo, hi);
  int Nk = hi-lo+1;

  // Process each channel for each pixel
  assert(data_rank == 3); // Doesn't yet support linear or point detectors
  int start[3] = {0, 0, lo};
  int size[3] = {1, 1, Nk};
  std::vector<double> data(Nk);
  std::vector<double> binned_channels(Nchannels);
  DEBUG("Integrating lines from " << lo << " to " 
	<< hi << "  with Nx = " << Nx);
  for (int i=0; i < Nx; i++) {
    int nonzeros = 0;
    for (int j=0; j < Ny; j++) {
      // Load and rebin counts for one pixel
      start[0] = i; start[1] = j;
      if (!nexus_readslab(file, DETECTOR_DATA, &data[0], start, size)) {
	ERROR("could not read channels " << lo << "-" << lo+Nk-1 << " from pixel " << i << "," << j << " of " << DETECTOR_DATA);
	return; // FIXME what to do with error?
      }
      rebin_counts(Nk, &detector_edges[lo], &data[0],
		   Nchannels, &bin_edges[0], &binned_channels[0]);

      // Accumulate bins across Nx and across times
      double sum = 0.;
      for (int k=0; k < Nchannels; k++) {
	counts[k*Npixels+(primary_dimension==0?i:j)] += binned_channels[k];
	sum += binned_channels[k];
      }
      image_sum[i*Ny+j] = sum;
      for (int k=0; k < Nk; k++) nonzeros += (data[k]!=0);
    }
    char ch = i%100==0 ? '#' : ( i%10==0 ? '0'+(i/10)%10 : 
				 ( nonzeros?':':'.') );
    std::cout << ch << std::flush;
  }
  std::cout << std::endl;

  compute_uncertainty(counts, dcounts);
}


// Compute I,dI from counts and monitors
void NXtofnref::normalize_counts(void)
{
  I.resize(counts.size());
  dI.resize(counts.size());
  if (Nmonitor_channels) {
    // Divide detector images for each time channel by monitor
    for (int k=0; k < Nchannels; k++) {
      const double mon_inv = 1./(monitor[k] == 0. ? 1. : monitor[k]);
      const double dmon_mon_sq = dmonitor[k] * square(mon_inv);
      const int offset = k*Npixels;
      for (int j=0; j < Npixels; j++) {
	dI[offset+j] = sqrt(square(dcounts[offset+j] * mon_inv) 
			    + square(counts[offset+j] * dmon_mon_sq));
	I[offset+j] = counts[offset+j]*mon_inv;
      }
    }
  } else {
    // Can't normalize without the monitor
    for (int k=0; k < Nchannels; k++) {
      const int offset = k*Npixels;
      for (int j=0; j < Npixels; j++) {
	dI[offset+j] = dcounts[offset+j];
	I[offset+j] = counts[offset+j];
      }
    }
  }
}

std::vector<double> 
NXtofnref::sum_all_images(void)
{
  // image_sum is cheap to compute when integrating, so cache
  // it and return it here.
  return image_sum;
}


void NXtofnref::print_summary(std::ostream& out)
{
  out << name << ": "  << title << std::endl;
  out << " detector dimensions " << Nx << " x " << Ny << std::endl;
  out << " moderator to detector distance: " << moderator_to_detector
      << " m" << std::endl;
  out << " sample to detector distance:    " << sample_to_detector
      << " m" << std::endl;
  out << " detector angle: " << detector_angle << " degrees" << std::endl;
  out << " sample angle:   " << sample_angle << " degrees" << std::endl;
  out << " detector time channels (" << Ndetector_channels << "): " 
      << detector_tcb[0] << " - " << detector_tcb[Ndetector_channels] << " us"
      << std::endl;
  out << " detector wavelength: " 
      << detector_edges[0] << " - " << detector_edges[Ndetector_channels] 
      << " Angstroms"
      << std::endl;
  if (Nmonitor_channels) {
    out << " monitor wavelength (" << Nmonitor_channels << "): " 
	<< monitor_edges[0] << " - " << monitor_edges[Nmonitor_channels] 
	<< " Angstroms"
	<< std::endl;
  }
  if (Nchannels) {
    out << " binned wavelength (" << Nchannels << "): " 
	<< bin_edges[0] << " - " << bin_edges[Nchannels] << " Angstroms"
	<< std::endl;
  }
  out << std::endl;
}

void NXtofnref::print_image(int n, std::ostream& out)
{
  out << "# " << name << ": " << title << std::endl;
  out << "# image " << n << std::endl;
  std::vector<double> image;
  get_image(image, n);
  for (int i=0; i < Nx; i++) {
    for (int j=0; j < Ny; j++) 
      out << std::setw(10) << image[j+i*Ny];
    out << std::endl;
  }
}

void NXtofnref::print_counts(int n, std::ostream& out)
{
  for (int j=0; j < Npixels; j++) 
    out << " " << std::setw(10) << log10(1.+counts[n*Npixels + j]);
  out << std::endl;
}



#if defined(STANDALONE)
static void
print_sum_all_images(NXtofnref& data, std::ostream& out = std::cout)
{
  out << "# " << data.name << ": " << data.title << std::endl;
  out << "# sum of all images" << std::endl;
  std::vector<double> image(data.sum_all_images());
  for (int i=0; i < data.Nx; i++) {
    for (int j=0; j < data.Ny; j++) 
      out << " " << std::setw(10) << image[j+i*data.Ny];
    out << std::endl;
  }
}

static void
print_integrated_counts(NXtofnref& data, std::ostream& out = std::cout)
{
  out << "# " << data.name << ": " << data.title << std::endl;
  out << "# integrated counts" << std::endl;
  for (int i=0; i < data.Nchannels; i++) data.print_counts(i, out);
}

static void
print_normalized_counts(NXtofnref& data, std::ostream& out = std::cout)
{
  // Find the data floor before plotting log data
  int start=std::min(data.Nchannels,80), stop=std::min(data.Nchannels,850);
  double floor = 1e308;
  for (int i=start*data.Npixels; i <= stop*data.Npixels; i++) {
    const double d = data.I[i];
    if (d > 0. && d < floor) floor = d;
  }
  floor = floor/2.;

  out << "# " << data.name << ": " << data.title << std::endl;
  out << "# normalized counts" << std::endl;
  for (int k=start; k <= stop; k++) {
    for (int j=0; j < data.Npixels; j++) {
      const double d = data.I[k*data.Npixels + j];
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
  if (data.Nmonitor_channels) {
    for (int i=0; i < data.Nchannels; i++) {
      out << std::setw(20) << data.lambda[i] << " " 
	  << std::setw(20) << data.monitor[i] 
	  << " " << std::setw(20) << data.dmonitor[i] << std::endl;
   }
  }
}

#define WRITE(file, junk) do { std::ofstream out(file); junk; } while (0)
int main(int argc, char *argv[])
{
  NXtofnref data;
  if (argc > 1) {
    DEBUG("Opening " << argv[1]); 
    data.open(argv[1]);
    data.print_summary();

    DEBUG("No binning");
    data.set_bins(0., data.detector_edges[data.Ndetector_channels], 0.);
    for (int i=0; i < data.Ndetector_channels; i+=500) {
      char filename[50]; sprintf(filename,"imageraw%03d.dat",i);
      WRITE(filename, data.print_image(i, out));
    }

    DEBUG("Setting bins 5% bins between " << 0.1
	  << " and " << data.detector_edges[data.Ndetector_channels]);
    data.set_bins(0.1, data.detector_edges[data.Ndetector_channels], 5.);

    WRITE("monitor.dat", print_monitor(data, out));
    for (int i=0; i < data.Nchannels; i+=50) {
      char filename[50]; sprintf(filename,"image%03d.dat",i);
      WRITE(filename, data.print_image(i, out));
    }
    data.integrate_counts();
    WRITE("imagesum.dat", print_sum_all_images(data, out));
    WRITE("counts.dat", print_integrated_counts(data, out));
    data.normalize_counts();
    WRITE("norm.dat", print_normalized_counts(data, out));
  }
}

#endif

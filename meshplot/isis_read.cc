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

#if 1
#define DEBUG(a) do { std::cout << a << std::endl; } while (0)
#else
#define DEBUG(a) do { } while (0)
#endif

#include "isis_read.h"

const double Plancks_constant=6.62618e-27; // Planck constant (erg*sec)
const double neutron_mass=1.67495e-24;     // neutron mass (g)

void isis_file::seek(section_number section, int p) // Jump to position p in a section
{
  // DEBUG("seek to " << 4*p << " in " << section << " (offset " << offset[section] << ")" );
  lseek(fileid, 4*(offset[section]+p-1), SEEK_SET); 
}

void isis_file::summary(std::ostream& out = std::cout)
{
  out << name << ": "  << title << std::endl;
  out << " Run: " << run << " Time channels: " << nTimeChannels
      << " Spectra: " << nSpectra << std::endl
      << " Periods: " << nPeriods
      << " Detectors: " << nDetectors
      << " Environment parameters: " << nSampleEnvironmentParameters
      << std::endl;
}

static int isis_convert_int(const unsigned char b[])
{
  // FIXME confirm this works for signed integers
  int ret =  int(b[0]) + (int(b[1])<<8) + (int(b[2])<<16) + (int(b[3])<<24);
  // DEBUG("convert_int: bytes are " << int(b[0]) << ", " << int(b[1]) << ", " << int(b[2]) << ", " << int(b[3]) << " => " << ret);
  return ret;
}

void isis_file::getbytes(signed char *b, int n) // Read string from current position
{ 
  ::read(fileid,b,n); 
}

int isis_file::getint(void)
{
  signed char b[4];

  read(fileid, b, 4);
  return isis_convert_int((unsigned char *)(b));
}

static bool
isis_byte_relative_expand(const signed char indata[], const int nin, 
		     const int nfrom, int outdata[], const int nout)
{
  /*
C
C Expansion of byte-relative format into 32bit format
C
C Each integer is stored relative to the previous value in byte form.The first
C is relative to zero. This allows for numbers to be within + or - 127 of
C the previous value. Where a 32bit integer cannot be expressed in this way a 
C special byte code is used (-128) and the full 32bit integer stored elsewhere.
C The final space used is (NIN-1)/4 +1 + NEXTRA longwords, where NEXTRA is the
C number of extra longwords used in giving absolute values.
C
C
C Type definitions
C   Passed parameters
        INTEGER NIN
        BYTE    INDATA(NIN)     
C                               Array of NIN compressed bytes
        INTEGER NFROM           
C                               pass back data from this 32bit word onwards
C
        INTEGER NOUT            
C                               Number of 32bit words expected
        INTEGER OUTDATA(NOUT)   
C                               outgoing expanded data
        INTEGER ISTATUS         
C                               Status return
C                                      =0  no problems!
C                                      =1  failed
  */

  // First check no slip-ups in the input parameters
  if (nin <= 0 || nout+nfrom-1 > nin) return false;


  // Set initial absolute value to zero and channel counter to zero
  int itemp=0;
  int j=0;

  // Loop over all expected 32bit integers
  for (int i=0; i < nfrom+nout; i++) {
    if (j >= nin) return false;

    // if number is contained in a byte
    if (indata[j] != -128) {
      // add in offset to base
      itemp += indata[j];
    } else {
      // else skip marker and pick up new absolute value
      if (j+5 >= nin) return 1;
      itemp = isis_convert_int((unsigned char *)(indata+j+1));
      j += 4;
    }
    if (i > nfrom) outdata[i-nfrom] = itemp;
    j++;
  }

  return true;
}

void isis_file::getTimeChannelBoundaries(void)
{
#include <stdint.h>
DEBUG("nTimeChannels=" << nTimeChannels << ", &tcb[0]=" << intptr_t(&tcb[0]));
  tcb.resize(nTimeChannels+1);
DEBUG("nTimeChannels=" << nTimeChannels << ", &tcb[0]=" << intptr_t(&tcb[0])
      << ", size=" << tcb.size());
 exit(1);
  double extra;
  if (version[HEAD] == 1) {
    extra = 0.0;
  } else {
    seek(DAE,25);
    extra = 4.*double(getint());
  }
  DEBUG("extra = " << extra << ", nTimeChannels=" << nTimeChannels);

  seek(TCB,287);
  double pre1 = double(getint());
  for (int i=0; i <= nTimeChannels; i++) { // one more boundary than channel
    tcb[i] = double(getint())*pre1/32. + extra;
  }
  DEBUG("done reading time channel boundaries");
}


  /*
C
C *** ERROR CODES ***
C
C    0 = all OK
C    1 = file not open
C    2 = file not accessible
C    3 = invalid starting frame
C    4 = too many frames
C    5 = error in byte unpacking
C    6 = cannot understand data section
  */
int isis_file::getframes(int data[], int frame, int num_frames)
{
  if (frame < 0 || frame >= nSpectra*nPeriods) return 3;
  if (frame+num_frames >= nSpectra*nPeriods) return 4;

// if (frame%100==0) DEBUG("getframe " << frame << "..." << frame+num_frames-1);
  if (compression == 0) {
    // Original version and new version without compression are identical
    // except for the offset in the data section of the first frame
    // not compressed --- read it directly
if (frame==0) DEBUG("seeking to " << frame_table << " in " << offset[DATA]);
    seek(DATA,frame_table + frame*nTimeChannels);
    for (int i=0; i < nTimeChannels*num_frames; i++) data[i] = getint();
  } else if (compression == 1) {
    // byte relative compression.
    static std::vector<signed char> buffer;
    buffer.resize(5*nTimeChannels); 
    for (int k=0; k<num_frames;k++) {
      // worst case: 5 bytes per value
if (frame+k==0) DEBUG("compressed: seeking to " << frame_table << " in " << offset[DATA]);
      seek(DATA,frame_table + 2*(frame+k));
      int length = getint();
      int start = getint();
      seek(DATA,start);
if (frame+k==0) DEBUG("data start,length=" << start << "," << length);
      getbytes((signed char *)(&buffer[0]),4*length);
      bool good = isis_byte_relative_expand((signed char *)(&buffer[0]),4*length,0,
			       data+k*nTimeChannels,nTimeChannels);
      if (!good) return 5;
    }
  } else {
    // unknown compression
    return 6;
  }
// if (frame%100 == 0) for (int i=0; i < nTimeChannels; i+=200) DEBUG(i << ": " << data[i] << " ");
//if (frame==0) for (int i=0; i < nTimeChannels; i+=1) DEBUG(i << ": " << data[i] << " ");

  return 0;
}

int isis_file::getframes(std::vector<int>& data, int frame, int num_frames)
{ 
  data.resize(num_frames * nTimeChannels);
  return getframes(&data[0],frame,num_frames); 
}

bool
isis_file::open(const char *filename)
{
  close();
  name = filename;
  fileid = ::open(filename,O_RDONLY|O_BINARY);
  DEBUG("open " << name << " in " << fileid); 
  if (fileid < 0) return false;
  DEBUG("open succeeded");

  // From src/io.f in the openGenie tree.
  //
  // Integers are 4 bytes little-endian.
  // 10 sections, each one starts with version number
  // Header:
  //    VER1:20  // file version at integer 20 in header
  //    Section offsets:21-30  //  10 integers giving section offsets
  //    file offset for section: offset[i] = (S[i]-1)*4
  //    version number for section: Vi = 1 int at pos[i]
  offset[HEAD] = 21;
  seek(HEAD,0);  version[HEAD] = getint();
  for (int i=1; i <= 5; i++) offset[i] = getint();
  if (version[HEAD] == 1) { /* No user */
    offset[USER] = version[USER] = 0;
    userLength = 0;
    offset[DATA] = getint();
    offset[NOTES] = getint();
  } else {
    offset[USER] = getint();
    offset[DATA] = getint();
    offset[NOTES] = getint();
  }
  DEBUG("offset[0]=" << offset[0] << ", offset[1]=" << offset[1]);

  // Section 1: RUN  
  //    size is 94 values
  //    RUN:1
  //    TITL:2  80 characters
  //    USER:22 8*20 characters
  //    RPB:62  32 values
  seek(RUN,0); version[RUN] = getint();
  run = getint();
  DEBUG("run = " << run);
  getbytes(title,80); title[80] = '\0';
  for (int i=79; i >=0 && title[i] == ' '; i--) title[i] = '\0';
  DEBUG("title = " << title);

  // Section 2: INSTRUMENT
  //    V1==1, size is 70+2*NMON+(6+NEFF)*NDET
  //    V1!=1, size is 70+2*NMON+(5+NEFF)*NDET
  //    NAME:1 8 characters
  //    NDET:67 
  //    NMON:68 
  //    NEFF:69
  // DEBUG("instrument");
  seek(INSTRUMENT,0); version[INSTRUMENT] = getint();
  seek(INSTRUMENT,67);
  nDetectors = getint();
  nMonitors = getint();

  // Section 3: SAMPLE_ENVIRONMENT
  //    NSEP: V3 == 1 ? 33 : 65
  // DEBUG("sample environment");
  seek(SAMPLE_ENVIRONMENT,0); version[SAMPLE_ENVIRONMENT] = getint();
  seek(SAMPLE_ENVIRONMENT, version[SAMPLE_ENVIRONMENT]==1?33:65);
  nSampleEnvironmentParameters = getint();

  // Section 4: DAE
  // Section 5: TCB
  //    NTRG:1  // Number of time regimes
  //    NFFP:2
  //    NPER:3  // Number of periods
  //    PMAP:4 256 values
  //    NSP1:260 // Number of spectra - 1
  //    NTC1:261 // Number of time channels - 1
  //    TCM1:262  5 values
  //    PRE1:287
  //    TCB1:288  NTC1+1 values
  // DEBUG("Time Channel Boundaries");
  seek(TCB,0); version[TCB] = getint();
  nTimeRegimes = getint();
  //nfpp = getint();
  nPeriods = getint();
  seek(TCB,260);  
  nSpectra = getint();
  nTimeChannels = getint();

  // Section 6: USER  // absent if VER1 == 1
  //    ULEN:1  // Length of USER section
  // DEBUG("User");
  if (offset[USER]) {
    seek(USER,0); version[USER] = getint();
    userLength = getint();
  }

  // Section 7: DATA  // 6 if VER1 == 1
  //    if V7 >= 2 data_header[0..31]:1
  //    if V7 < 2 data_header[0..31] = 0
  // DEBUG("Data");
  seek(DATA,0); version[DATA] = getint();
  if (version[DATA] >= 2) {
    // FIXME CURRENT.RUN isn't compressed even if it says it is
    compression = getint();
    getint();
    frame_table = getint(); // data starts at this location
  } else {
    compression = 0;
    frame_table = 1; // data starts at location 1
  }
  // Section 8: NOTES // 7 if VER1 == 1; absent if offset[SEC_NOTES] == 0


  DEBUG("Done open");
  return true;
}


// Detector solid angle as a function of pixel width and detector distance
static void 
set_delta(int Ny, double delta[], double pixelwidth, double detectordistance)
{
  // Set y coordinates
  for (int i=0; i < Ny; i++) 
    delta[i] = 2*atan2(pixelwidth*i,detectordistance);
}

bool SURF::open(const char *file)
{
  if (!isis_file::open(file)) return false;

  DEBUG("SURF open get time channel boundaries");
  getTimeChannelBoundaries();
  DEBUG("SURF open return from getTimeChannelBoundaries");

  for (int i=0; i <= nTimeChannels; i++) 
{ DEBUG(" tcb[i] == " << tcb[i]);
tcb[i]+=8.0;  // >>add 8 to tcb's (why???)
}
  // for (int i=0; i <= nTimeChannels; i+=100) DEBUG(i << ": " << tcb[i] << " ");

  DEBUG("SURF open set lambda");
  set_lambda();

  // for (int i=0; i < nTimeChannels; i+=100) DEBUG(i << ": " << lambda[i] << " ");
  DEBUG(nTimeChannels-1 << ": " << lambda[nTimeChannels-1] << " ");
  DEBUG("SURF open load monitor");
  load_monitor();
  // for (int i=0; i < nTimeChannels; i+=100) DEBUG(i << ": " << monitor[i] << " ");
  DEBUG("SURF open load all frames");
  load_all_frames();
  DEBUG("SURF open integrate counts");
  integrate_counts();
  DEBUG("SURF open normalize counts");
  normalize_counts();
  DEBUG("SURF open complete");
  return true;
}

void SURF::getframe(std::vector<double>& frame, int n)  // Return a particular frame
{
  frame.resize(Nx*Ny);
  const int offset = n * Nx*Ny;
  for (int i=0; i < Nx*Ny; i++) frame[i] = all_frames[offset+i];
}

void SURF::set_delta(void)
{
  delta.resize(Ny);
  ::set_delta(Ny,&delta[0],pixel,rsampdet);
}
 
void SURF::integrate_counts(void)
{
  // Reset counts vector
  counts.resize(Ny*nTimeChannels, 0);

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

  dcounts.resize(Ny*nTimeChannels);
  for (int i=0; i < Ny*nTimeChannels; i++) dcounts[i] = counts[i] != 0. ? sqrt(counts[i]) : 1.;
}

// Determine wavelength for each time channel from the center of the time bins.
void SURF::set_lambda(void)
{
  // Use the usual formula for TOF to lambda, *100. for units.
  lambda.resize(nTimeChannels);
  const double scale = Plancks_constant * 100.0 / (neutron_mass*detector_distance);
  for (int i=0; i < nTimeChannels; i++) {
    lambda[i] = 0.5 * (tcb[i] + tcb[i+1]) * scale;
    // FIXME incorrect formula for dlambda
    dlambda[i] = (tcb[i+1] - tcb[i])/sqrt(log10(256)) * scale; 
  }
}

// Load the monitor values and rebin to detector bins.
void SURF::load_monitor(void)
{
  // Load raw monitor counts
  std::vector<int> intmon(nTimeChannels);
  getframes(intmon,Nx*Ny+1,1);
  DEBUG("mon");
  for (int i=0; i < nTimeChannels; i+=100) DEBUG(i << ": " << intmon[i] << " ");

  // Convert to I,dI
  std::vector<double> rawmon(nTimeChannels), drawmon(nTimeChannels);
  for (int i=0; i < nTimeChannels; i++) {
    rawmon[i] = intmon[i];
    drawmon[i] = intmon[i] != 0 ? sqrt(intmon[i]) : 1.;
  }

  // Compute wavelengths at the time boundaries for detector and monitor
  std::vector<double> monitor_edges(nTimeChannels+1), detector_edges(nTimeChannels+1);
  for (int i = 0; i <= nTimeChannels+1; i++) {
    monitor_edges[i] = tcb[i]*Plancks_constant*100.0 / (neutron_mass*monitor_distance); 
    detector_edges[i] = tcb[i]*Plancks_constant*100.0 / (neutron_mass*detector_distance); 
  }

  // Rebin monitor to detector time boundaries.
  rebin_counts(monitor_edges,rawmon,drawmon,detector_edges,monitor,dmonitor);
}

// Compute I,dI from counts and monitors
void SURF::normalize_counts(void)
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

// Must load all frames at once with ISIS file format
void SURF::load_all_frames(void)
{
  std::vector<double> xdet(Nx), ydet(Ny);

  // Set detector indices
  xdet.resize(Nx); for (int i=0; i < Nx; i++) xdet[i] = i+1;
  ydet.resize(Ny); for (int i=0; i < Ny; i++) ydet[i] = i+1;

  // Load frames
  getframes(all_frames,0,Nx*Ny);

  // Transpose so we can easily return one frame at a time.
  transpose(nTimeChannels,Nx*Ny,&all_frames[0],&all_frames[0]);

  // for each frame applyDetectorEfficiencyCorrection(frame);
}

std::vector<int> 
SURF::sum_all_frames(void)
{
  std::vector<int> frame(Nx*Ny,0);
  for (int k = 0; k < nTimeChannels; k++) {
    const int offset = k * Nx * Ny;
    for (int i = 0; i < Nx*Ny; i++) frame[i] += all_frames[offset+i];
  }
  return frame;
}

void SURF::copy_frame(int from, int to)
{
  if (from == to) return;
  const int from_offset = from*Nx*Ny; 
  const int to_offset = to*Nx*Ny;
  for (int i=0; i < Nx*Ny; i++) all_frames[to_offset+i] = all_frames[from_offset+i];
  monitor[to] = monitor[from];
  dmonitor[to] = square(dmonitor[from]);
  counts[to] = counts[from];
  dcounts[to] = dcounts[from];
  I[to] = I[from];
  dI[to] = dI[from];
  tcb[to] = tcb[from];
}

void SURF::add_frame(int from, int to)
{
  const int from_offset = from*Nx*Ny;
  const int to_offset = to*Nx*Ny;
  for (int i=0; i < Nx*Ny; i++) all_frames[to_offset+i] += all_frames[from_offset+i];
  monitor[to] += monitor[from];
  dmonitor[to] += square(dmonitor[from]);
  counts[to] += counts[from];
  dcounts[to] += dcounts[from];
  I[to] += I[from];
  dI[to] += dI[from];
}

// Given a list [b_1 b_2 ... b_{n+1}], sum all data from b_i to b_{i+1}-1
// and save it if frame i.  Note that there are n+1 boundaries for n channels.
//
// The current implementation is defined to operate in-place, but there is
// no performance reason to do so.  In fact, because it resizes the memory
// down to the new size, it effectively does a copy.
void SURF::merge_frames(int n, int boundaries[])
{
  for (int k=0; k < n; k++) {
    copy_frame(boundaries[k], k);
    for (int i=boundaries[k]+1; i < boundaries[k+1]; i++) add_frame(i,k);
  }
  // Adding in quadrature; take square roots
  for (int k=0; k < n; k++) {
    dI[k] = sqrt(dI[k]);
    dcounts[k] = sqrt(dcounts[k]);
    dmonitor[k] = sqrt(dmonitor[k]);
  }
  // Throw away unneeded memory (really only need to do this for all_frames)
  all_frames.resize(n*Nx*Ny);
  I.resize(n);
  dI.resize(n);
  counts.resize(n);
  dcounts.resize(n);
  monitor.resize(n);
  dmonitor.resize(n);
  tcb[n] = tcb[boundaries[n]];
  tcb.resize(n+1);
  nTimeChannels = n;
  set_lambda();
}

void SURF::printframe(int n, std::ostream& out)
{
  out << "# " << name << ": " << title << std::endl;
  out << "# frame " << n << std::endl;
  const int offset = n*Nx*Ny;
  for (int i=0; i < Nx; i++) {
    for (int j=0; j < Ny; j++) out << std::setw(10) << all_frames[offset+j+i*Ny];
    out << std::endl;
  }
}

void SURF::printcounts(int n, std::ostream& out)
{
  for (int j=0; j < Ny; j++) out << " " << std::setw(10) << log10(1.+counts[n*Ny + j]);
  out << std::endl;
}

void SURF::printspectrum(int n, std::ostream& out)
{
  out << "# " << name << ": " << title << std::endl;
  out << "# spectrum " << n << std::endl;
  if (n < 0) n = Nx*Ny-1 + (-n);
  std::vector<int> frame;
  getframes(frame, n, 1);
  for (int j=0; j < nTimeChannels; j++) {
    out << std::setw(10) << lambda[j] << " " << std::setw(10) << frame[j] << std::endl;
  }
}

#if defined(STANDALONE)
static void
print_sum_all_frames(SURF& data, std::ostream& out = std::cout)
{
  out << "# " << data.name << ": " << data.title << std::endl;
  out << "# sum of all frames" << std::endl;
  std::vector<int> frame(data.sum_all_frames());
  for (int i=0; i < data.Nx; i++) {
    for (int j=0; j < data.Ny; j++) out << " " << std::setw(10) << frame[j+i*data.Ny];
    out << std::endl;
  }
}

static void
print_integrated_counts(SURF& data, std::ostream& out = std::cout)
{
  out << "# " << data.name << ": " << data.title << std::endl;
  out << "# integrated counts" << std::endl;
  for (int i=0; i < data.nTimeChannels; i++) data.printcounts(i, out);
}

static void
print_normalized_counts(SURF& data, std::ostream& out = std::cout)
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
print_monitor(SURF& data, std::ostream& out = std::cout)
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
  SURF data;
  if (argc > 1) {
    data.open(argv[1]);
    data.summary();
    for (int i=0; i < data.nTimeChannels; i+=50) {
      char filename[50]; sprintf(filename,"frame%03d.dat",i);
      WRITE(filename, data.printframe(i, out));
    }
    WRITE("spectrum300.dat", data.printspectrum(300, out));
    WRITE("spectrumend.dat", data.printspectrum(-1, out));
    WRITE("mon1.dat", data.printspectrum(-2, out));
    WRITE("mon2.dat", data.printspectrum(-3, out));
    WRITE("framesum.dat", print_sum_all_frames(data, out));
    WRITE("counts.dat", print_integrated_counts(data, out));
    WRITE("norm.dat", print_normalized_counts(data, out));
    WRITE("monitor.dat", print_monitor(data, out));
  }
}

#elif defined(USE_TCL)
#include <tcl.h>
#include "mx.h"

// command:
//   isis "filename" returns object
// methods:
//   close
//   Ny                returns int
//   Nx                returns int
//   Nt                returns int
//   frame i           returns matrix [Nx x Ny] as string
//   channels n [v1 v2 ... vn+1] integrate channels v_i..v_{i+1}-1
//   monitor/dmonitor  returns vector [Nt] as string
//   lambda/dlambda    returns vector [Nt] as string
//   counts/dcounts    returns matrix [Ny x Nt] as string
//   I/dI              returns matrix [Ny x Nt] as string
//   

static int int_result(Tcl_Interp *interp, int k)
{
  Tcl_Obj *result = Tcl_GetObjResult(interp);
  Tcl_SetIntObj(result, k);
  return TCL_OK;
}

static int real_result(Tcl_Interp *interp, double v)
{
  Tcl_Obj *result = Tcl_GetObjResult(interp);
  Tcl_SetDoubleObj(result, v);
  return TCL_OK;
}

template <class T> static int 
vector_result(Tcl_Interp *interp, int n, const T v[])
{
  Tcl_Obj *xobj = Tcl_NewByteArrayObj(NULL,0);
  if (!xobj) return TCL_ERROR;
  mxtype *x = (mxtype *)Tcl_SetByteArrayLength(xobj,n*sizeof(mxtype));
  for (int i=0; i < n; i++) x[i] = v[i];
  if (!x) return TCL_ERROR;
  Tcl_SetObjResult(interp,xobj);
  return TCL_OK;
}

template <class T> inline int
vector_result(Tcl_Interp *interp, const std::vector<T>& v)
{
  return vector_result(interp,v.size(), &v[0]);
}


// FIXME hack to make get_tcl_vector available --- put it in header
extern "C" const mxtype *
get_tcl_vector(Tcl_Interp *interp, const char *name,
	       const char *context, const char *role,int size);

static int
isis_method(ClientData isis_filep, Tcl_Interp *interp, int argc, Tcl_Obj *CONST argv[])
{
  DEBUG("entering isis_method");
  Tcl_ResetResult(interp);
  SURF *file = static_cast<SURF *>(isis_filep);
  const char *isis_name = Tcl_GetString(argv[0]);
  const char *method = "";
  if (argc >= 2) method = Tcl_GetString(argv[1]);
  DEBUG(isis_name << " method is " << method);
  if (strcmp(method, "Nx") == 0) {
    return int_result(interp, file->Nx);
  } else if (strcmp(method, "Ny") == 0) {
    return int_result(interp, file->Ny);
  } else if (strcmp(method, "Nt") == 0) {
    return int_result(interp, file->nTimeChannels);
  } else if (strcmp(method, "distance") == 0) {
    return real_result(interp, file->detector_distance);
  } else if (strcmp(method, "pixelwidth") == 0) {
    return real_result(interp, file->pixel);
  } else if (strcmp(method, "counts") == 0) {
    return vector_result(interp, file->counts);
  } else if (strcmp(method, "dcounts") == 0) {
    return vector_result(interp, file->dcounts);
  } else if (strcmp(method, "I") == 0) {
    return vector_result(interp, file->I);
  } else if (strcmp(method, "dI") == 0) {
    return vector_result(interp, file->dI);
  } else if (strcmp(method, "monitor") == 0) {
    return vector_result(interp, file->monitor);
  } else if (strcmp(method, "dmonitor") == 0) {
    return vector_result(interp, file->dmonitor);
  } else if (strcmp(method, "lambda") == 0) {
    return vector_result(interp, file->lambda);
  } else if (strcmp(method, "dlambda") == 0) {
    return vector_result(interp, file->dlambda);
  } else if (strcmp(method, "frame") == 0) {
    if (argc != 3) {
      Tcl_AppendResult(interp, isis_name, 
	 	    ": frame needs a frame number", NULL);
      return TCL_ERROR;
    }

    int k;
    if (Tcl_GetIntFromObj(interp,argv[2],&k) != TCL_OK) return TCL_ERROR;

    std::vector<int> frame;
    file->getframes(frame, k, 1);
    return vector_result(interp, frame);
  } else if (strcmp(method, "channels") == 0) {
    if (argc != 4) {
      Tcl_AppendResult( interp, isis_name, 
          		": channels needs 'n' and vector of n+1", NULL);
      return TCL_ERROR;
    }
    int k;
    const char *name = Tcl_GetString(argv[3]);
    const mxtype *channels;
    if (Tcl_GetIntFromObj(interp, argv[2],&k) != TCL_OK) return TCL_ERROR;
    channels = get_tcl_vector(interp, name, isis_name, "channels", k+1);
    if (channels == NULL) return TCL_ERROR;

    std::vector<int> ichannels(k+1);
    for (int i=0; i <= k; i++) ichannels[i] = int(channels[i]);
    file->merge_frames(k,&ichannels[0]);
    return TCL_OK;
  } else if (strcmp(method,"close") == 0) {
    file->close();
    return TCL_OK;
  } else {
    Tcl_AppendResult( interp, isis_name, 
                      ": expects close, Nx, Ny, Nt, monitor, frame i, counts, dcounts, active start stop, distance, pixelwidth, lambda, I or dI",
                      NULL);
     return TCL_ERROR;
  }
}

static void
isis_delete(ClientData h)
{
  SURF *file = static_cast<SURF *>(h);
  delete file;
}

static int 
isis_open(ClientData junk, Tcl_Interp *interp, int argc, Tcl_Obj *CONST argv[])
{
  static int isis_id = 0;
  if (argc != 2) {
    Tcl_SetResult( interp, "isis: expects filename", TCL_STATIC);
    return TCL_ERROR;
  }
  const char *filename = Tcl_GetString(argv[1]);
  SURF *isis_handle = new SURF;
  if (isis_handle->open(filename)) {
    char isis_name[30];
    sprintf(isis_name, "isis%d", ++isis_id);
DEBUG("function handle is " << isis_name);
    Tcl_CreateObjCommand( interp, isis_name, isis_method, &isis_handle, isis_delete );
DEBUG("command created");
 Tcl_AppendResult( interp, isis_name, NULL); 
  } else {
    delete isis_handle;
    Tcl_ResetResult(interp);
    Tcl_AppendResult( interp, "isis: could not open ", filename, NULL);
  }
  return TCL_OK;
}

extern "C" void isis_init(Tcl_Interp *interp)
{
  Tcl_CreateObjCommand( interp, "isis", isis_open, NULL, NULL );
}
#endif

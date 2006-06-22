
#include <iostream>
#include "isis_tofnref.h"
#include <napi.h>
#include "nexus_helper.h"

#include "NXtofnref_keys.icc"

void int2double(double v[], int n)
{
  int i;
  for (i=n-1; i >=0; i--) v[i] = ((int *)v)[i];
}

bool convert(const char infile[], const char outfile[])
{
  SURF data;
  
  if (!data.open(infile)) return false;
  data.summary();
  if (strcmp((char *)data.instrument,"SURF")!=0 
      && strcmp((char *)data.instrument,"CRISP")!=0) {
    printf("Only supports SURF and CRISP data.\n");
    return false;
  }

  /* Load data into an array of doubles */
  int pixels=data.Nx*data.Ny, channels = data.nTimeChannels;
  std::vector<double> frames(pixels*channels);
  data.getframes((int *)&frames[0],0,pixels);
  int2double((double *)&frames[0],pixels*channels);

  /* Convert data from isis order to NeXus order.
   * In NeXus, time is fastest varying, then y, then x.
   * In ISIS, time is fastest varying, then y, then x.
   * So we don't need any transform and can write the data directly.
   */
  int dims[3];
  dims[2]=data.nTimeChannels; dims[1]=data.Nx; dims[0]=data.Ny;
  
  
  /* Create nexus file */
  Nexus *file = nexus_open(outfile, "w");
  if (file == NULL) return false;

  nexus_addset(file,"data1","NXtofnref",1,0,
	       "http://www.nexus.anl.gov/instruments/xml/NXtofnref.xml");

  
  /* FIXME Need to get slits and angles from the user */
  double ws1,ws2,ws3,ws4,a1,a2,ds1,ds2,ds3,ds4,detector;
  ws1 = 1.0; ws2 = 0.75; ws3 = 2.0; ws4 = 2.0; /* Slits */
  a1 = a2 = 1.5;  /* Angles */
  if (strcmp((char *)data.instrument,"SURF")==0) {
    /* Surf - distances 'borrowed' from Crisp */
    ds1 = -2.586; ds2 = -.35; ds3 = 0.4; ds4 = 2.71;
    detector = ds4+0.13;
    nexus_writescalar(file, MODERATOR_DISTANCE, -9.0, NX_FLOAT32);
    nexus_writescalar(file, SAMPLE_ANGLE, a1, NX_FLOAT32);
    nexus_writescalar(file, DETECTOR_ANGLE, a2, NX_FLOAT32);
    nexus_writescalar(file, DETECTOR_DISTANCE, detector, NX_FLOAT32);
    nexus_writescalar(file, MONITOR_DISTANCE, 0.5, NX_FLOAT32);
    nexus_writeslit(file, PRE_SLIT1,  ds1, ws1, -1.);
    nexus_writeslit(file, PRE_SLIT2,  ds2, ws2, -1.);
    nexus_writeslit(file, POST_SLIT1, ds3, ws3, -1.);
    nexus_writeslit(file, POST_SLIT2, ds4, ws4, -1.);
  } else {
    /* Crisp: distances from the schematic */
    ds1 = -2.586; ds2 = -.35; ds3 = 0.4; ds4 = 1.733;
    detector = ds4 + 0.13;
    nexus_writescalar(file, MODERATOR_DISTANCE, -10.25, NX_FLOAT32);
    nexus_writescalar(file, SAMPLE_ANGLE, a1, NX_FLOAT32);
    nexus_writescalar(file, DETECTOR_ANGLE, a2, NX_FLOAT32);
    nexus_writescalar(file, DETECTOR_DISTANCE, detector, NX_FLOAT32);
    nexus_writescalar(file, MONITOR_DISTANCE, -0.33, NX_FLOAT32);
    nexus_writeslit(file, PRE_SLIT1,  ds1, ws1, -1.);
    nexus_writeslit(file, PRE_SLIT2,  ds2, ws2, -1.);
    nexus_writeslit(file, POST_SLIT1, ds3, ws3, -1.);
    nexus_writeslit(file, POST_SLIT2, ds4, ws4, -1.);
  }
  if (data.Nx*data.Ny > 1) {
    /* Multidetector data. */
    nexus_write(file, DETECTOR_DATA, &frames[0], 3, dims, NX_INT32);
    nexus_writescalar(file, PIXEL_WIDTH, 2.3, NX_FLOAT32);
    nexus_writescalar(file, PIXEL_HEIGHT, 2.3, NX_FLOAT32);
    nexus_writestr(file, SCAN_TYPE, "area");
  } else {
    /* Point detector data. */
    nexus_write(file, DETECTOR_DATA, &frames[0], 1, dims, NX_INT32);
    /* Don't care about pixel width and height for pencil detectors. */
  }

  nexus_writevector(file, TIME_CHANNEL_BOUNDARIES, &data.tcb[0],
		    data.tcb.size(), NX_FLOAT32);
  nexus_writevector(file, MONITOR_DATA, &data.monitor_raw[0],
		    data.nTimeChannels, NX_INT32);
  
  nexus_close(file);
  return true;
}



int main(int argc, char *argv[])
{
  for (int i = 1; i < argc; i++) {
    char outfile[100];

    // Extract file name without the path
    const char *file = strrchr(argv[i],'/');
    if (file == NULL) file = argv[i];
    else file++;
    assert(strlen(file) < sizeof(outfile)+4);
    strcpy(outfile, file);

    // Replace extension with '.nxs'
    char *ext = strrchr(outfile, '.');
    if (ext == NULL) strcat(outfile, ".nxs");
    else strcpy(ext,".nxs");

    convert(argv[i],outfile);
  }
}

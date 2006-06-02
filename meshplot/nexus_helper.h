#ifndef NEXUS_SIMPLE_H
#define NEXUS_SIMPLE_H

/* 

This interface presents a simplified model of nexus files.
It is appropriate for standard measurements on standard
instruments.  It is not a generic HDF file explorer.

A file consists of a sequence of entries.  Entries have the
following properties:

   entry name 
   definition and major/minor version
   instrument name

The user either cycles through all entries (if the names 
are not known) or requests a specific entry by name.

Once in an entry, individual pieces of information can be
extracted from the entry using a key indicating the
path from the entry group. 

Keys are structured names.  E.g.,

  NXinstrument:instrument/NXmirror:frame_overlap_mirror/cutoff_wavelength
  NXinstrument:instrument/NXmirror:frame_overlap_mirror/cutoff_wavelength.mode

Groups are separated by slashes.  The group name consists of
a nexus class and the group name separated by ':'.  Each key ends 
in a field or a field.attribute specification.

The group names are symbolic names which should be specified 
in nexus instrument definition standards.  Where identifiers
also make sense (such as the name of the instrument), there
will be a field within the group with the identifier.  For
example, the name and short name of the instrument are:

  NXinstrument:instrument/name
  NXinstrument:instrument/name.short_name


The data retrieved from a key is either a string, some dimensions, 
or a vector of doubles.

Related keys should be accessed together so that some optimization 
is possible, even if it is not implemented in the current version.

Typical usage:

  Nexus *file;
  file = nexus_open(filename, "r");
  while (nexus_entry(file)) {
    if (strcmp(file->definition,"NXmonoref") == 0) {
      // Processing monochromatic neutron reflectometry file
      NexusDimension dims;
      int points;
      double *theta, *twothetat;

      nexus_dims(file,"NXinstrument:instrument/NXdetector:detector/data",&dims);
      points = dims.size[dims.n-1];
      theta = malloc(points*sizeof(double));
      twotheta = malloc(points*sizeof(double));
      nexus_read(file,"NXsample:sample/polar_angle",points,theta);
      nexus_read(file,"NXinstrument:instrument/NXdetector:detector/polar_angle",
                 points,twotheta)
      
      
*/

#include <napi.h>

/* File handle structure */
typedef struct {
  NXhandle fid; /* File handle open to a particular group */
  NXname name;

  /* === Other fields we might load ===
     NXname filename;
     int nexus_major,nexus_minor,nexus_patch;
     int hdf_major,hdf_minor,hdf_patch; 
  */
  
  /* The current entry in the file */
  NXname entry;           /* Entry name */
  NXname definition;      /* Measurement type (e.g., "NXmonoref") */
  int major,minor,patch;  /* Measurement version tag */

  /* Private info */
  char _group[1024]; /* Currently open group */
  NXname _field;  /* Currently open field */
  int _depth; /* Number of closes need to get to NXentry */
} Nexus;


/* Return values for querying a key about its type */
#define MAXDIMS 10
typedef struct {
  int rank, kind;
  int size[MAXDIMS];
} NexusDim;


#ifdef __cplusplus
extern "C" {
#endif

/* Opening/closing */
Nexus *nexus_open(const char filename[], const char mode[]);
void nexus_close(Nexus *file);
void nexus_flush(Nexus *file);

/* Reading */
int nexus_openset(Nexus *file, const char name[]);
int nexus_nextset(Nexus *file);
int nexus_dims(Nexus *file, const char key[], NexusDim *dims);
int nexus_read(Nexus *file, const char key[], double data[], int len);
int nexus_readslab(Nexus *file, const char key[], double data[],
		   int start[], int size[]);
int nexus_readstr(Nexus *file, const char key[], char data[], int len);
int nexus_readslit(Nexus *file, const char key[],
		   double *distance, double *width, double *height);

/* Writing */
int nexus_addset(Nexus *file, const char name[],
		 const char definition[], int major, int minor,
		 const char URL[]);
int nexus_writescalar(Nexus *file, const char key[], double data, int kind);
int nexus_writevector(Nexus *file, const char key[], double data[], 
		      int n, int kind);
int nexus_write(Nexus *file, const char key[], double data[],
		int rank, int size[], int kind);
int nexus_createdata(Nexus *file, const char key[],
		 int rank, int size[], int kind);
int nexus_writeslab(Nexus *file, const char key[], double data[],
		    int start[], int size[]);
int nexus_writestr(Nexus *file, const char key[], const char data[]);
int nexus_writeslit(Nexus *file, const char key[],
		    double distance, double width, double height);


#ifdef __cplusplus
} ;
#endif


#endif /* NEXUS_SIMPLE_H */

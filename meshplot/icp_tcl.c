// This is a work of the United States Government and is not
// subject to copyright protection in the United States.

#include <string.h>
#include <limits.h>
#include <stdlib.h>
#include <tcl.h>
#include "tclvector.h"
#include "mx.h"
#include "icpread.h"

#if 0
#define DEBUG(a) do { printf("%s\n",a); } while (0)
#else
#define DEBUG(a) do { } while (0)
#endif


#define integrated_width(f) (f->transpose?f->Nx:f->Ny)
/* We will keep the following fields for the ICP file */
typedef struct ICP_STRUCT {
  FILE *file;
  Real *motors, *frames, *integral, *framesum;
  int Nx, Ny, Npts, Nmotors, line;
  int transpose; /* 1 if integrate rows, 0 if integrate columns */
  int lo,hi; /* lo-hi range for integration */
  int roi[4]; /* Region of interest x,y,dx,dy*/
  char header[80*60];
  char filename[PATH_MAX];
} Icp;

static int 
compose_error(Tcl_Interp *interp, Icp *icp, int status)
{
  char line[20];

  Tcl_ResetResult(interp);
  sprintf(line,"(%d) ",icp->line);
  Tcl_AppendResult(interp, "icp: ", icp->filename, line, icp_error(status), NULL);
  return TCL_ERROR;
}



static int
readfile(Icp *icp)
{
  Counts *frame;
  Real *motors, *frames, *integral, *framesum;
  int nv = icp->Nmotors, npts = icp->Npts;
  int nr = icp->Nx, nc = icp->Ny;
  int nd = nr*nc, width = integrated_width(icp);
  int pt, status;

  /* Return to the start of the file */
  status = icp_readheader(icp->file,sizeof(icp->header),icp->header,
	&pt,&(icp->line));
  if (status != ICP_GOOD) return status;

  /* Grab some space */
  frame = malloc(nd*sizeof(*frame));
  if (icp->frames == NULL) {
    frames = malloc(npts*nd*sizeof(*frames));
    integral = malloc(npts*width*sizeof(*integral) );
    motors = malloc(npts*nv*sizeof(*motors));
    framesum = malloc(nd*sizeof(*framesum));
    if (frames == NULL || integral == NULL || motors == NULL 
        || frame == NULL || framesum == NULL) {
      if (frames != NULL) free(frames);
      if (motors != NULL) free(motors);
      if (frame != NULL) free(frame);
      if (framesum != NULL) free(framesum);
      return ICP_MEMORY_ERROR;
    }
  } else {
    frames = icp->frames;
    integral = icp->integral;
    motors = icp->motors;
    framesum = icp->framesum;
  }


  /* Reset framesum */
  memset(framesum,0,sizeof(*framesum)*nd);

  /* Read the frames */
  for(pt = 0; pt < npts; pt++) {
    int status, j;
    // printf("reading pt %d\n",pt);fflush(stdout);

    /* Read motors */
    // printf("motors=%p, nv=%d, npts=%d, s=%d\n",motors,nv,npts,sizeof(*motors)); fflush(stdout);
    status = icp_readmotors(icp->file, nv, motors+pt*nv, &(icp->line));
    // printf("status after readmotors %d\n",status); fflush(stdout);
    if (status < 0) break;
    // for (j=0; j < nv; j++) printf("%g ",motors[j]); printf("\n"); fflush(stdout);

    /* Read frame */
    // printf("frame=%p, nr=%d, nc=%d, s=%d\n",frame,nr,nc,sizeof(*frame)); fflush(stdout);
    status = icp_readdetector(icp->file, nr, nc, frame, &(icp->line));
    // printf("status after readdetector %s\n",icp_error(status)); fflush(stdout);
    if (status < 0) break;
    // for (j=0; j < nr*nc; j++) printf(ICP_COUNT_FORMAT " ",frame[j]); printf("\n"); fflush(stdout);

    /* Store and accumulate frame */
    /* TODO: just store ROI? */
    // printf("saving frame %d\n",status); fflush(stdout);
    for (j=0; j < nd; j++) {
	frames[pt*nd+j] = frame[j];
	framesum[j] += frame[j];
    }

    // printf("integrating pt %d, width=%d, transpose=%d\n",pt, width,!icp->transpose); fflush(stdout);
    /* Integrate along one detector dimension */
    /* TODO: detector corrections first (efficiency, pixel width, rotation) */
    /* TODO: restrict integration to lo/hi pixels */
    mx_integrate(nr, nc, frames+pt*nd, icp->transpose?0:1,integral+pt*width);

  }
  icp->Npts = pt;

  free(frame);
  icp->motors = motors;
  icp->frames = frames;
  icp->integral = integral;
  // printf("done reading\n");

  /* Return 'Good' if we reach the end of the file. */
  /* TODO: what about if npts in header is an underestimate? */
  return (status == ICP_EOF)?ICP_GOOD:status;
}


// command:
//   icp "filename" returns object
// methods:
//   close
//   Ny                returns int
//   Nx                returns int
//   Npts              returns int
//   Nmotors           returns int
//   header            returns header text as string
//   motors            returns matrix [Npts x Nmotors] as string
//   image i           returns matrix [Nx x Ny] as string



static int
Ticp_method(ClientData h, Tcl_Interp *interp, int argc, Tcl_Obj *CONST argv[])
{
  Icp *file = (Icp *)h;
  int nr = file->Nx, nc=file->Ny, npts=file->Npts, nmotors=file->Nmotors;
  const char *file_name = Tcl_GetString(argv[0]);
  const char *method = "";

  DEBUG("entering icp_method");
  Tcl_ResetResult(interp);

  if (argc >= 2) method = Tcl_GetString(argv[1]);
  DEBUG(file_name << " (" << intptr_t(nexus_filep) <<") method is " << method);

  if (strcmp(method, "Nx") == 0) {
    return int_result(interp, nr);
  } else if (strcmp(method, "Ny") == 0) {
    return int_result(interp, nc);
  } else if (strcmp(method, "Npixels") == 0) {
    return int_result(interp, integrated_width(file));
  } else if (strcmp(method, "Nt") == 0) {
    return int_result(interp, npts);
  } else if (strcmp(method, "Npts") == 0) {
    return int_result(interp, npts);
  } else if (strcmp(method, "Nmotors") == 0) {
    return int_result(interp, nmotors);
  } else if (strcmp(method,"close") == 0) {
    icp_close(file->file);
    file->file = NULL;
  } else if (strcmp(method, "header") == 0) {
    Tcl_AppendResult(interp, file->header);
  } else if (strcmp(method, "read") == 0) {
    int status = readfile(file);
    if (status != ICP_GOOD) return compose_error(interp,file,status);
  } else if (strcmp(method, "motors") == 0) {
    return real_vector_result(interp, npts*nmotors, file->motors);
  } else if (strcmp(method, "counts") == 0) {
    return real_vector_result(interp, npts*integrated_width(file), file->integral);
  } else if (strcmp(method, "image") == 0) {
    if (argc != 3) {
      Tcl_AppendResult(interp, file_name, 
	 	    ": image needs an image number", NULL);
      return TCL_ERROR;
    }

    int k;
    if (Tcl_GetIntFromObj(interp,argv[2],&k) != TCL_OK) return TCL_ERROR;

    if (k > file->Npts || k < 0) {
      Tcl_AppendResult(interp, file_name,
		    ": image number must be 0 for sum or 1..Npts", NULL);
      return TCL_ERROR;
    }

    if (k > 0) {
      return real_vector_result(interp, nr*nc, file->frames+(k-1)*nr*nc);
    } else {
      return real_vector_result(interp, nr*nc, file->framesum);
    }

  } else if (strcmp(method, "geometry") == 0) {
#if 0
    int old_state = file->is_vertical;
    if (argc == 3) {
      const char *str = Tcl_GetStringFromObj(argv[2],NULL);
      if (strcmp("vertical",str) == 0) {
	file->set_geometry(1);
      } else if (strcmp("horizontal",str) == 0) {
	file->set_geometry(0);
      } else {
	Tcl_AppendResult(interp, file_name,
			 ": geometry ?vertical|horizontal", NULL);
	return TCL_ERROR;
      }
    }
    Tcl_AppendResult(interp, old_state?"vertical":"horizontal", NULL);
#else
    Tcl_AppendResult(interp, "not implemented", NULL);
    return TCL_ERROR;
#endif
  } else if (strcmp(method, "roi") == 0) {
    if (argc == 6) {
      int xlo, xhi, ylo, yhi;
      if (Tcl_GetIntFromObj(interp, argv[2],&xlo) != TCL_OK) return TCL_ERROR;
      if (Tcl_GetIntFromObj(interp, argv[3],&xhi) != TCL_OK) return TCL_ERROR;
      if (Tcl_GetIntFromObj(interp, argv[4],&ylo) != TCL_OK) return TCL_ERROR;
      if (Tcl_GetIntFromObj(interp, argv[5],&yhi) != TCL_OK) return TCL_ERROR;

      if (xlo < 0) xlo = 0;
      if (xhi > nr-1) xhi = nr-1;
      if (ylo < 0) ylo = 0;
      if (yhi > nc-1) yhi = nc-1;
      file->roi[0] = xlo;
      file->roi[1] = ylo;
      file->roi[2] = xhi-xlo+1;
      file->roi[3] = yhi-ylo+1;
    } else {
	Tcl_AppendResult(interp, file_name,
			 ": roi ?xlo ?xhi ?ylo ?yhi", NULL);
	return TCL_ERROR;
    }
  } else if (strcmp(method, "primary") == 0) {
    if (argc < 2 || argc > 3) {
      Tcl_AppendResult( interp, file_name,
			": primary ?x|y", NULL);
      return TCL_ERROR;
    }
    if (argc == 2) {
      // Return the primary dimension as 'x' or 'y'
      Tcl_AppendResult (interp, file->transpose?"y":"x", NULL);
    } else {
      // Convert a primary dimension from 'x' or 'y'
      const char *str = Tcl_GetStringFromObj(argv[2],NULL);
      if (str[0] == 'x') {
        file->transpose = 0;
      } else if (str[0] == 'y') {
        file->transpose = 1;
      } else {
	Tcl_AppendResult( interp, file_name,
			  ": primary ?x|y", NULL);
	return TCL_ERROR;
      }
    }
  } else {
    Tcl_AppendResult( interp, file_name, " ", method,
                      ": expects close, Nx, Ny, Npts, Nmotors, motors, frames",
                      NULL);
     return TCL_ERROR;
  }
  return TCL_OK;
}

static void
Ticp_delete(ClientData h)
{
  Icp *icp = (Icp *)h;
  if (icp->motors) free(icp->motors);
  if (icp->frames) free(icp->frames);
  if (icp->framesum) free(icp->framesum);
  if (icp->integral) free(icp->integral);
  icp_close(icp->file);
  free(icp);
}

static int 
Ticp_open(ClientData junk, Tcl_Interp *interp, int argc, Tcl_Obj *CONST argv[])
{
  static int id = 0;

  Icp *icp;
  const char *filename;
  int status;
  char commandname[15];

  /* Arg checking */
  if (argc != 2) {
    Tcl_SetResult( interp, "icp: expects filename", TCL_STATIC);
    return TCL_ERROR;
  }

  /* Allocate and initialize icp structure */
  icp = (Icp *)malloc(sizeof(*icp));
  if (icp == NULL) {
    Tcl_AppendResult( interp, "icp: out of memory", NULL);
    return TCL_ERROR;
  }
  icp->motors = icp->frames = icp->framesum = icp->integral = NULL;

  /* Open file */
  filename = Tcl_GetString(argv[1]);
  icp->file = icp_open(filename);
  if (icp->file == NULL) {
    free(icp);
    Tcl_AppendResult( interp, "icp: could not open ", filename, NULL);
    return TCL_ERROR;
  }

  /* Save the filename */
  strncpy(icp->filename,filename,sizeof(icp->filename));
  icp->filename[sizeof(icp->filename)-1] = '\0';

  /* Read header and count columns */
  status = icp_readheader(icp->file,sizeof(icp->header),icp->header,&(icp->Npts),&(icp->line));
  if (status < 0) {
    icp_close(icp->file);
    free(icp);
    compose_error(interp, icp, status);
    return TCL_ERROR;
  }
  status = icp_framesize(icp->file, &(icp->Nx), &(icp->Ny), &(icp->Nmotors));
  if (status < 0) {
    icp_close(icp->file);
    free(icp);
    compose_error(interp, icp, status);
    return TCL_ERROR;
  }

  /* Create the Tcl object */
  sprintf(commandname, "icp%d", ++id);
  Tcl_CreateObjCommand( interp, commandname, Ticp_method, icp, Ticp_delete );
  Tcl_AppendResult( interp, commandname, NULL); 
  return TCL_OK;
}

void icp_init(Tcl_Interp *interp)
{
  Tcl_CreateObjCommand( interp, "icp", Ticp_open, NULL, NULL );
}

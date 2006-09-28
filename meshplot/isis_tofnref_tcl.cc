#include <tcl.h>
#include "mx.h"
#include "isis_tofnref.h"
#include "tkmeter.h"

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
//   Nmonitor_raw      returns int
//   monitor_raw,dmonitor_raw,monitor_raw_lambda returns vector [Nmonitor_raw]
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

static mxtype* build_return_vector(Tcl_Interp *interp, size_t n)
{
  Tcl_Obj *xobj = Tcl_NewByteArrayObj(NULL,0);
  if (!xobj) return NULL;
  mxtype *x = (mxtype *)Tcl_SetByteArrayLength(xobj,n*sizeof(mxtype));
  if (x != 0) Tcl_SetObjResult(interp,xobj);
  return x;
}

template <class T> static int 
vector_result(Tcl_Interp *interp, size_t n, const T v[])
{
  DEBUG("vector_result returning " << n << " values at " << intptr_t(v));
  mxtype *x = build_return_vector(interp, n); 
  if (x == 0) return TCL_ERROR;
  for (size_t i=0; i < n; i++) x[i] = v[i];
  return TCL_OK;
}

template <class T> inline int
vector_result(Tcl_Interp *interp, const std::vector<T>& v)
{
  return vector_result(interp, v.size(), &v[0]);
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
  DEBUG(isis_name << " (" << intptr_t(isis_filep) <<") method is " << method);
  if (strcmp(method, "Nx") == 0) {
    return int_result(interp, file->Nx);
  } else if (strcmp(method, "Ny") == 0) {
    return int_result(interp, file->Ny);
  } else if (strcmp(method, "Npixels") == 0) {
    return int_result(interp, file->nTimeChannels);
  } else if (strcmp(method, "sampletodetector") == 0) {
    return real_result(interp, file->sample_to_detector);
  } else if (strcmp(method, "pixelwidth") == 0) {
    return real_result(interp, file->pixel_width);
  } else if (strcmp(method, "counts") == 0) {
    return vector_result(interp, file->counts);
  } else if (strcmp(method, "dcounts") == 0) {
    return vector_result(interp, file->dcounts);
  } else if (strcmp(method, "I") == 0) {
    return vector_result(interp, file->I);
  } else if (strcmp(method, "dI") == 0) {
    return vector_result(interp, file->dI);
  } else if (strcmp(method, "Nmonitor_raw") == 0) {
    return int_result(interp, file->monitor_raw.size());
  } else if (strcmp(method, "monitor_raw") == 0) {
    return vector_result(interp, file->monitor_raw);
  } else if (strcmp(method, "dmonitor_raw") == 0) {
    return vector_result(interp, file->dmonitor_raw);
  } else if (strcmp(method, "monitor_raw_lambda") == 0) {
    return vector_result(interp, file->monitor_lambda);
  } else if (strcmp(method, "monitor") == 0) {
    return vector_result(interp, file->monitor);
  } else if (strcmp(method, "dmonitor") == 0) {
    return vector_result(interp, file->dmonitor);
  } else if (strcmp(method, "lambda_edges") == 0) {
    return vector_result(interp, file->lambda_edges);
  } else if (strcmp(method, "lambda") == 0) {
DEBUG("lambda(" << file->lambda.size() << ") at " << intptr_t(&file->lambda[0]));
    return vector_result(interp, file->lambda);
  } else if (strcmp(method, "dlambda") == 0) {
    return vector_result(interp, file->dlambda);
  } else if (strcmp(method, "rebin") == 0) {
    ProgressMeter *meter = 0;
    if (argc == 3) {
      meter = new TkMeter(interp,argv[2]);
    } else {
      // meter = new NoMeter();
      meter = new TextMeter();
    }
    file->integrate_counts(meter);
    delete meter;
    file->normalize_counts();
  } else if (strcmp(method, "image") == 0) {
    if (argc != 3) {
      Tcl_AppendResult(interp, isis_name, 
	 	    ": image needs a frame number", NULL);
      return TCL_ERROR;
    }

    int k;
    if (Tcl_GetIntFromObj(interp,argv[2],&k) != TCL_OK) return TCL_ERROR;

    if (k > file->nTimeChannels || k < 0) {
      Tcl_AppendResult(interp, isis_name,
		    ": frame number must be 0 for sum or 1..Nt", NULL);
      return TCL_ERROR;
    }

    if (k > 0) {
      std::vector<double> frame;
      file->getframe(frame, k-1);
      return vector_result(interp, frame);
    } else {
      return vector_result(interp, file->sum_all_frames());
    }

  } else if (strcmp(method, "proportional_binning") == 0) {
    if (argc != 5) {
      Tcl_AppendResult( interp, isis_name,
			": proportional_binning needs lo hi step%", NULL);
      return TCL_ERROR;
    }
    double lo, hi, step;
    if (Tcl_GetDoubleFromObj(interp,argv[2],&lo) != TCL_OK) return TCL_ERROR;
    if (Tcl_GetDoubleFromObj(interp,argv[3],&hi) != TCL_OK) return TCL_ERROR;
    if (Tcl_GetDoubleFromObj(interp,argv[4],&step) != TCL_OK) return TCL_ERROR;
    file->load();
    file->merge_frames(lo, hi, step);
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
  } else if (strcmp(method,"close") == 0) {
    file->close();
  } else {
    Tcl_AppendResult( interp, isis_name, 
                      ": expects close, Nx, Ny, Nt, monitor, frame i, counts, dcounts, active start stop, distance, pixelwidth, lambda, I or dI",
                      NULL);
     return TCL_ERROR;
  }
  return TCL_OK;
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
DEBUG(isis_name << " (" << intptr_t(isis_handle) << ") lambda(" << isis_handle->lambda.size() << ") at " << intptr_t(&isis_handle->lambda[0]));
    Tcl_CreateObjCommand( interp, isis_name, isis_method, isis_handle, isis_delete );
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

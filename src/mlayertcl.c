/* recompile with -DEBUG to display debugging messages */
#ifdef EBUG
#define DEBUG 1
#else
#define DEBUG 0
#endif


#include <tcl.h>
#include <string.h>

#if DEBUG
#define debug_message printf
#else
#define debug_message ignore
void ignore TCL_VARARGS_DEF(CONST char *,arg1) {}
#endif

#include "genmulti.h"
#include "cleanUp.h"
#include "cdata.h"
#include "clista.h"
#include "genpsd.h"
#include "genpsi.h"
#include "genpsr.h"
#include "genpsc.h"
#include "genmem.h"
#include "glayi.h"
#include "glayd.h"
#include "genvac.h"
#include "dlconstrain.h"
/* #include "constraincpp.h" */
#include "queryString.h"
#include "caps.h"
#include "stopFit.h"
#include "dofit.h"
#include "cleanFree.h"
#include "genva.h"
#include "loadData.h"
#include "extres.h"
#include "genderiv.h"
#include "mlayer.h"

/* ============================================================ */
/* hacks to make mlayer think it is running as it was before */

/* mlayer was not designed as a Tcl extension so things like callbacks
 * and error messages are not propogated up and down the stack. Instead 
 * of rewriting it, I have replaced some of the internal routines with
 * Tcl-aware alternatives and pass info using global variables. Ugly
 * yes, but the quickest available hack without committing to a whole-
 * hearted tcl conversion.
 */

/* I don't know if we need to use Tcl's allocators within
 * tcl extensions, but this provides them.  In the makefile
 * I use -DMALLOC=gmlayer_alloc, and in the rest of the program I use 
 *    #ifndef MALLOC
 *    #define MALLOC malloc 
 *    #endif
 * When (if?) we fully commit to being a tcl extension, these
 * can go away.  Use ckalloc/ckfree instead of MALLOC/FREE.
 */
void *gmlayer_alloc(int n) { return Tcl_Alloc(n); }
void gmlayer_free(void *p) { Tcl_Free(p); }

/* Module data */
/* We don't need this anymore since we aren't using dynamic loading. */
/* However, the dynamic loading code is still around, so we need to */
/* define this (normally it resides in main, but we have no main. */
char *mlayer_SCCS_VerInfo = "@(#)mlayer	v1.46 05/24/2001";

/* mlayer got all its input from the user.  Now it gets it from 
 * the gmlayer command arguments.  Rather than rewriting the whole
 * gmlayer read-eval-print loop, I queue the command arguments and
 * replace the queryString function with one that gets the next
 * string from the queue rather than querying the user. */
static CONST char **queue = NULL;
static int queued = 0; /* length of the queue */
char *queryString(char *prompt, char *string, int length)
{
   if (string == NULL || length == 0) {
     static char buffer[FBUFFLEN];
     string = buffer;
     length = FBUFFLEN;
   }

   if (queued > 0) {
     strncpy (string, queue[0], length);
     string[length-1] = 0;
     queue++; queued--;
   } else {
     string[0] = 0;
   }
   debug_message("%d:%s > %s\n", queued, prompt, string);
   return (*string == 0) ? NULL : string;
}


/* mlayer uses printf to report errors directly to stdout.  We
 * need to return them from gmlayer.  So replace printf with
 * ERROR, which converts it to sprintf and indicates that the
 # command failed. */
static char error_message[1000];
static int failure;
void ERROR TCL_VARARGS_DEF(CONST char *,arg1)
{
  va_list argList;
  CONST char *format;

  format = TCL_VARARGS_START(CONST char *, arg1, argList);
  *error_message = '\0';
  vsnprintf (error_message, sizeof(error_message), format, argList);
  va_end(argList);
  failure = 1;
}


/* Process all outstanding Tcl events. */
int flushqueue(void)
{
  while (Tcl_DoOneEvent(TCL_DONT_WAIT)) ;
  return TCL_OK;
}

/* Fitting: we need a fit cycle routine to check if the fit has
 * been aborted (fit_callback), and an interpreter to evaluate it in
 * (fit_interp).  Similarly, we need a routine to apply constraints
 * (fit_constraints).
 *
 * We modified dofit.c so that each fit cycle ipc_fitupdate is called.
 *
 * Rather than no_constraints, we use tclconstraints which calls back
 * to the tcl interpreter with a constraints script.
 */
static Tcl_Interp *fit_interp = NULL;
static CONST char *fit_callback = NULL;
static char *fit_constraints = NULL;
int ipc_fitupdate(void)
{
  debug_message("ipc_fitupdate with %s\n", fit_callback);
  Tcl_Eval(fit_interp, fit_callback);
  /* XXX FIXME XXX if fit speed improves, we may not want to evaluate
   * this every time --- leave it to the fit_callback code to decide?
   */
  flushqueue();
  return TCL_OK;
}
static void tclconstraints(int del, double a[], int nt, int nm, int nr, int nb)
{
  debug_message("tclconstraints with %s\n", fit_constraints);
  if (*fit_constraints)
    Tcl_Eval(fit_interp, fit_constraints);
  debug_message("done constraints\n");
  /* XXX FIXME XXX why did I want to run the event loop during constraints? */
  /* flushqueue(); */
}


/* ===================================================================== */
/* communicate parameters to/from gmlayer */

/* I am currently passing strings to and from gmlayer containing lists
 * of parameters, etc.  I need to communicate using objects.  In 
 * particular, I may want to populate blt vectors directly, or better yet, 
 * use blt vectors internally so that no copying is required.  This will 
 * require a big reworking of the code.  Eventually the fitting code will
 * be split off from the modelling code.  When that happens we can change
 * the interface.
 */

static void sendpars(Tcl_Interp *interp)
{
  char value[100];
  double t;
  int i;

  sprintf(value, "%d %d %d %d %d", ntlayer+nmlayer+nblayer+1,
	  ntlayer, nmlayer, nblayer, nrepeat);
  Tcl_AppendResult(interp, value, NULL);

  sprintf(value, " %15g %15g %15g %15g %15g",
	  bmintns, bki, thedel, lamdel, lambda);
  Tcl_AppendResult(interp, value, NULL);

  t = 0.0;
  for (i=0; i < nrough; i++) t += 0.5*zint[i];
  sprintf(value, " %15g %d", t, nrough);
  Tcl_AppendResult(interp, value, NULL);

  for (i=0; i <= ntlayer; i++) {
    sprintf(value, " %15g %15g %15g %15g",
	    tqcsq[i],tmu[i],trough[i],td[i]);
    Tcl_AppendResult(interp, value, NULL);
  }
  for (i=1; i <= nmlayer; i++) {
    sprintf(value, " %15g %15g %15g %15g",
	    mqcsq[i],mmu[i],mrough[i],md[i]);
    Tcl_AppendResult(interp, value, NULL);
  }
  for (i=1; i <= nblayer; i++) {
    sprintf(value, " %15g %15g %15g %15g",
	    bqcsq[i],bmu[i],brough[i],bd[i]);
    Tcl_AppendResult(interp, value, NULL);
  }
}


static void sendvector(Tcl_Interp* interp, double *x, int n, int step)
{
  char value[50];
  int j;

debug_message("sending vector of length %d as step %d\n",n,step);
  Tcl_AppendResult(interp,"{",NULL);
  if (n>0) {
    for (j=0; j<n; j++) {
      if (step) sprintf(value, "%.15g %.15g", x[j], x[j]);
      else sprintf(value, "%.15g", x[j]);
      Tcl_AppendResult(interp," ",value,NULL);
    }
  }
  Tcl_AppendResult(interp,"}",NULL);
}

static void sendreflect(Tcl_Interp* interp, double *x, double *y, int n)
{
  sendvector(interp,x,n,0);
  Tcl_AppendResult(interp, " ", NULL);
  sendvector(interp,y,n,0);
}

static void senddata(Tcl_Interp* interp)
{
  if (loaded) {
      sendvector(interp,xdat,npnts,0);
      Tcl_AppendResult(interp, " ", NULL);
      sendvector(interp,ydat,npnts,0);
      Tcl_AppendResult(interp, " ", NULL);
      sendvector(interp,srvar,npnts,0);
  } else {
      Tcl_AppendResult(interp, "{} {} {}",NULL);
  }
}

static void sendprofile(Tcl_Interp* interp, int step)
{
  register int j;
  double thick;
  char value[20];

debug_message("sendprofile nglay=%d, gd=%p,gmu=%p\n",nglay,gd,gmu);

  thick = -vacThick(trough,zint,nrough);
  Tcl_AppendResult(interp,"{",NULL);
  for (j = 0; j < nglay; j++) {
    sprintf(value, " %.15g", thick);
    Tcl_AppendResult(interp,value,NULL);
    thick += gd[j];
    if (step) {
      sprintf(value, " %.15g", thick);
      Tcl_AppendResult(interp,value,NULL);
    }
  }
  Tcl_AppendResult(interp,"} ",NULL);
  sendvector(interp,gmu,nglay,step);
  Tcl_AppendResult(interp, " ", NULL);
  sendvector(interp,gqcsq,nglay,step);
}

static void sendfit (Tcl_Interp *interp)
{
  int j;
  for (j=0; j < mfit; j++) {
    char result[150], varName[10];
    genva(listA + j, 1, varName);
    sprintf(result, "{ %7s %.15g %.15g }", varName, a[listA[j]], DA[listA[j]]);
    Tcl_AppendResult(interp, result, " ", NULL);
  }
}


/* ==================================================================== */
/* define the gmlayer command */
static int
gmlayer_TclCmd(ClientData data, Tcl_Interp *interp,
	   int argc, CONST char *argv[])
{
  static int fitting;

  int i;
  CONST char *what;

#if DEBUG
  for (i=0; i < argc; i++) { debug_message(argv[i]); debug_message(" ");}
  debug_message("\n");
#endif

  if (argc < 2) {
    interp->result = "gmlayer cmd ?args?";
    return TCL_ERROR;
  }
  if (argc < 3) what = "";
  else what = argv[2];

  if (strcmp(argv[1], "halt") == 0) {
    abortFit = 1;

  } else if (strcmp(argv[1], "fit") == 0) {
    /* XXX FIXME XXX shouldn't need 'fitting' */
    fitting = 1;
    fit_interp = interp;
    fit_callback = what;
    fitReflec("FRG ");
    fitting = 0;

    sendfit(interp);

  } else if (strcmp(argv[1], "constraints") == 0) {
    if (fit_constraints != NULL) Tcl_Free(fit_constraints);
    if (*what != '\0') {
	Constrain = tclconstraints;
	fit_constraints = Tcl_Alloc(strlen(what)+1);
	strcpy(fit_constraints, what);
    } else {
	Constrain = noconstraints;
    }

  } else if (strcmp(argv[1], "set") == 0) {
    interp->result = "gmlayer recv is not implemented";
    return TCL_ERROR;

  } else if (strcmp(argv[1], "send") == 0) {
    if (strcmp(what, "datafile") == 0) {
      interp->result = infile;
    } else if (strcmp(what, "parfile") == 0) {
      interp->result = parfile;
    } else if (strcmp(what, "constraints") == 0) {
      if (argc > 3) {
         cleanFree((double **)&ConstraintScript);
         if (strlen(argv[3])) {
            ConstraintScript = Tcl_Alloc(strlen(argv[3])+1);
            strcpy(ConstraintScript, argv[3]);
         }
      } else if (ConstraintScript != NULL)
         interp->result = ConstraintScript;
    } else if (strcmp(what, "mkconstrain") == 0) {
#if 0
      char version[15];
      sprintf(version, "0x%08lx", MAJOR|MINOR);
      Tcl_AppendResult(interp,makeconstrain," \"",constrainScript,
		       "\" \"", constrainModule,"\" ",version,
		       " \"", prototype, "\"", NULL);
#endif
    } else if (strcmp(what, "varying") == 0) {
      genva(listA, mfit, fitlist);
      interp->result = fitlist;
    } else if (strcmp(what, "pars") == 0) {
      sendpars(interp);
    } else if (strcmp(what, "data") == 0) {
      if (*infile) loadData(infile);
      senddata(interp);
    } else if (strcmp(what, "refl") == 0) {
      if (fitting)
	sendreflect(interp,xdat,ymod,npnts);
      else if (0) {
	/* Ideally, we would work on a subset of the
	   points until so that the user gets partial
	   feedback while dragging.  These points would
	   lie in the current zoom window.  When the
	   user stops dragging, the complete dataset would
	   be calculated.  This has to happen without
	   making the rest of the interface clunky, either
	   with some sort of abort call or by calculating
	   one section at a time. For now this is too
	   complicated.
	*/
	int refinement;
	if (argc>3) {
	  if (strcmp(argv[3], "max") == 0)
	    refinement = -1;
	  else if (Tcl_GetInt(interp, argv[3], &refinement) != TCL_OK)
	    return TCL_ERROR;
	} else {
	  refinement = -1;
	}
	sendreflect(interp,xtemp,ytemp,npnts);
      } else if (loaded) {
	extend(xdat, npnts, lambda, lamdel, thedel);
	genderiv(xdat, yfit, npnts, 0);
	sendreflect(interp,xdat,yfit,npnts);
      } else {
	/* Send calculated reflectivity to GUI */
	double qstep;
	int j;

	allocCdata(npnts); /* XXX FIXME XXX - not checking alloc failure */
	qstep = (qmax - qmin) / (double) (npnts - 1);
	for (j = 0; j < npnts; j++)
	  xtemp[j] = (double) j * qstep + qmin;

	/* XXX FIXME XXX - not checking for memory allocation failure */
	extend(xtemp, npnts, lambda, lamdel, thedel);
	genderiv(xtemp, yfit, npnts, 0);

	sendreflect(interp,xtemp,yfit,npnts);
      }
    } else if (strcmp(what, "chisq") == 0) {
      char value[40];
      double ret;
      if (fitting) ret = chisq/(double)(npnts-mfit);
      else if (loaded) ret=calcChiSq(npnts,yfit,ydat,srvar)/(double)(npnts-1);
      else ret = -1.0;
      sprintf(value,"%.15g",ret);
      Tcl_AppendResult(interp,value,NULL);
    } else if (strcmp(what, "prof") == 0) {
      if (!fitting)
	genmulti(tqcsq, mqcsq, bqcsq, tqcmsq, mqcmsq, bqcmsq,
		 td, md, bd, trough, mrough, brough, tmu, mmu, bmu,
		 nrough, ntlayer, nmlayer, nblayer, nrepeat, proftyp);
      sendprofile(interp,argc>3);
    } else {
      interp->result = "gmlayer send ?: expected pars, work, ...";
      return TCL_ERROR;
    }

  } else if (strcmp(argv[1],"msg") == 0) {
    printf("%s\n",what);
  } else {
    queue = argv+1;
    queued = argc-1;
    failure = 0;
    mlayer();
    if (failure) {
      interp->result = error_message;
      return TCL_ERROR;
    }
  }
  return TCL_OK;
}

void gmlayer_TclEnd(ClientData data)
{
  debug_message("gmlayer cleanup\n");
  cleanUp();
}


int Gmlayer_Init(Tcl_Interp* interp)
{
  static int initialized = 0;
  Tcl_Obj *version;
  int r;

#if 0
  out = Tcl_GetChannel(interp, "stdout", NULL);
    if (out == NULL) {
	interp->result = "could not find stdout";
	return TCL_ERROR;
    }
#endif

#if DEBUG
  fit_interp = interp;
#endif

  debug_message("gmlayer init\n");

  if (initialized) {
    interp->result = "Only one copy of gmlayer is allowed";
    return TCL_ERROR;
  }

#ifdef USE_TCL_STUBS
  Tcl_InitStubs(interp, "8.0", 0);
#endif
  version = Tcl_SetVar2Ex(interp, "gmlayer_version", NULL,
			  Tcl_NewDoubleObj(0.1), TCL_LEAVE_ERR_MSG);
  if (version == NULL)
    return TCL_ERROR;
  r = Tcl_PkgProvide(interp, "gmlayer", Tcl_GetString(version));

  strcpy(parfile, "mlayer.staj");
  Constrain = noconstraints;
  Tcl_CreateCommand(interp, "gmlayer",
		    gmlayer_TclCmd,
		    (ClientData)NULL,
		    gmlayer_TclEnd);

  return r;
}

int Gmlayer_SafeInit(Tcl_Interp* interp)
{
  interp->result = "gmlayer is not a safe command";
  return TCL_ERROR;

  // Until we remove commands to read/write files, we are not safe...
  // return gmlayer_Init(interp);
}

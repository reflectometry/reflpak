/* recompile with -DEBUG to display debugging messages */
#ifdef EBUG
#define DEBUG 1
#else
#define DEBUG 0
#endif


#include <tcl.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>

#if DEBUG
#define debug_message printf
#else
#define debug_message ignore
void ignore TCL_VARARGS_DEF(CONST char *,arg1) {}
#endif

#include "genlayers.h"
#include "ngenlayers.h"
#include "mgenlayers.h"
#include "cleanUp.h"
#include "allocData.h"
#include "ipc.h"
#include "cdata.h"
#include "clista.h"
#include "genpsd.h"
#include "genpsi.h"
#include "genpsr.h"
#include "genpsc.h"
#include "genmem.h"
#include "glayi.h"
#include "glayd.h"
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
#include "gmagpro4.h"
#include "genpsl.h"
#include "genderiv4.h"
#include "magblocks4.h"

int loaded; /* false if no dataset has been loaded */

/* ============================================================ */
/* hacks to make gj2 think it is running as it was before */

/* gj2 was not designed as a Tcl extension so things like callbacks
 * and error messages are not propogated up and down the stack. Instead 
 * of rewriting it, I have replaced some of the internal routines with
 * Tcl-aware alternatives and pass info using global variables. Ugly
 * yes, but the quickest available hack without committing to a whole-
 * hearted tcl conversion.
 */

/* I don't know if we need to use Tcl's allocators within
 * tcl extensions, but this provides them.  In the makefile
 * I use -DMALLOC=gmlayer_alloc.  When (if?) we fully commit 
 * to being a tcl extension, these can go away.  Use 
 * ckalloc/ckfree instead of malloc/free.
 */
void *gmlayer_alloc(int n) { return Tcl_Alloc(n); }
void *gmlayer_realloc(void *p, int n) { return Tcl_Realloc(p,n); }
void gmlayer_free(void *p) { Tcl_Free(p); }

/* Module data */
/* We don't need this anymore since we aren't using dynamic loading. */
/* However, the dynamic loading code is still around, so we need to */
/* define this (normally it resides in main, but we have no main. */
char *gj2_SCCS_VerInfo = "@(#)mlayer	v1.46 05/24/2001";

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

static int parsevar(const char name[], int **pi, double **pd)
{
  int nl;

  *pi = NULL;
  *pd = NULL;
  if (name[0] == 'n') {
    if (strcmp(name,"nl") == 0) *pi = &nlayer;
    else return 0;
  } else if (name[0] == 'b') {
    if (strcmp(name,"bk") == 0) *pd = &bki;
    else if (strcmp(name,"bi") == 0) *pd = &bmintns;
    else return 0;
  } else if (name[0] == 'v') {
    if (strcmp(name,"vqc") == 0) *pd = qcsq;
    else if (strcmp(name,"vqm") == 0) *pd = qcmsq;
    else if (strcmp(name,"vmu") == 0) *pd = mu;
    else return 0;
  } else {
    /* associate prefix with vector */
    if (name[0] == 'd') {
      *pd = d;
    } else if (name[0] == 'm' && name[1] == 'u') {
      *pd = mu;
    } else if (name[0] == 'q' && name[1] == 'c') {
      *pd = qcsq;
    } else if (name[0] == 'q' && name[1] == 'm') {
      *pd = qcmsq;
    } else if (name[0] == 'r' && name[1] == 'o') {
      *pd = rough;
    } else if (name[0] == 'r' && name[1] == 'm') {
      *pd = mrough;
    } else if (name[0] == 't' && name[1] == 'h') {
      *pd = the;
    } else return 0;
    /* convert numeric portion of name 
     * if 'd', then pd==d and the name prefix is one character, otherwise 
     * the name prefix has two characters. */
    nl = atoi(name+(*pd!=d?2:1));
    
    if (nl > 0 && nl <= MAXLAY) *pd += nl;
    else return 0;
  }
  return 1;
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
void ipc_fitupdate(void)
{
  debug_message("ipc_fitupdate with %s\n", fit_callback);
  Tcl_Eval(fit_interp, fit_callback);
  Tcl_ResetResult(fit_interp);
  /* XXX FIXME XXX if fit speed improves, we may not want to evaluate
   * this every time --- leave it to the fit_callback code to decide?
   */
  flushqueue();
  /* How do we interrupt a fit? */
  /*  return TCL_OK; */
}
static void tclconstraints(int del, double a[], int nl)
{
  if (fit_constraints) {
    Tcl_Eval(fit_interp, fit_constraints);
    Tcl_ResetResult(fit_interp);
  }
  /* XXX FIXME XXX why did I want to run the event loop during constraints? */
  /* flushqueue(); */
}


/* ===================================================================== */
/* communicate parameters to/from gj2 */

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

  sprintf(value, "%d", nlayer+1);
  Tcl_AppendResult(interp, value, NULL);

  sprintf(value, " %15g %15g %15g %15g %15g",
	  bmintns, bki, thedel, lamdel, lambda);
  Tcl_AppendResult(interp, value, NULL);

  t = 0.0;
  for (i=0; i < nrough; i++) t += 0.5*zint[i];
  sprintf(value, " %15g %d", t, nrough);
  Tcl_AppendResult(interp, value, NULL);

  /* proc layer in mlayer.tcl defines the order */
  for (i=0; i <= nlayer; i++) {
    sprintf(value, " %15g %15g %15g %15g %15g %15g %15g %15g",
	    qcsq[i],mu[i],rough[i],d[i],qcmsq[i],the[i],mrough[i],dm[i]);
    Tcl_AppendResult(interp, value, NULL);
  }
}


static void sendvector(Tcl_Interp* interp, const double *x, int n, int step)
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

static void sendreflect(Tcl_Interp* interp, const double *x, const double *y, 
			const int n, const int *using)
{
  int i;
  sendvector(interp,x,n,0);
  for (i=0; i<4; i++) {
    if (using[i]) {
      Tcl_AppendResult(interp, " ", NULL);
      sendvector(interp,y,n,0);
      y+=n;
    } else {
      Tcl_AppendResult(interp, " {}", NULL);
    }
  }
}

static void senddata(Tcl_Interp* interp, char what)
{
  int i;
  if (loaded) {
    int offset = 0;
    for (i=0; i < what-'a'; i++) if (xspin[i]) offset += npntsx[i];
    if (xspin[i]) { 
      sendvector(interp,xdat+offset,npntsx[i],0);
      Tcl_AppendResult(interp, " ", NULL);
      sendvector(interp,ydat+offset,npntsx[i],0);
      Tcl_AppendResult(interp, " ", NULL);
      sendvector(interp,srvar+offset,npntsx[i],0);
      return;
    }
  }
  Tcl_AppendResult(interp, "{} {} {}",NULL);
}

static void sendprofile(Tcl_Interp* interp, int step)
{
  register int j;
  double thick;
  char value[20];

debug_message("sendprofile nglay=%d, gd=%p,gmu=%p\n",nglay,gd,gmu);

  thick = -vacThick(rough,zint,nrough);
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
  Tcl_AppendResult(interp, " ", NULL);
  sendvector(interp,gthe,nglay,step);
  Tcl_AppendResult(interp, " ", NULL);
  sendvector(interp,gqmsq,nglay,step);
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

/* XXX FIXME XXX this duplicates code in genReflect */
static void build_q4x (void)
{
  double qmin, qmax, qstep;
  int j;

  /* Determine number of points and spacing */
  qmin = 0.0;
  qmax = 0.4;
  n4x = 40;
  for (j = 0; j < 4; j++)
    if (xspin[j]) {
      n4x = npntsx[j];
      qmin = qminx[j];
      qmax = qmaxx[j];
      break;
    }
  
  /* XXX FIXME XXX - not checking alloc failure */
  allocDatax(n4x,&xtemp,&q4x,&y4x,&yfita);

  qstep = (qmax - qmin) / (double) (n4x - 1);
  for (j = 0; j < n4x; j++)
    q4x[j] = (double) j * qstep + qmin;
}



/* ==================================================================== */
/* define the gmlayer command */
static int
gmlayer_TclCmd(ClientData data, Tcl_Interp *interp,
	   int argc, CONST char *argv[])
{
  static int fitting;

  CONST char *what;

#if DEBUG
  int i;
  for (i=0; i < argc; i++) { debug_message(argv[i]); debug_message(" ");}
  debug_message("\n");
#endif

  if (argc < 2) {
    Tcl_AppendResult(interp,"gmlayer cmd ?args?",NULL);
    return TCL_ERROR;
  }
  if (argc < 3) what = "";
  else what = argv[2];

  if (strcmp(argv[1], "halt") == 0) {
    abortFit = 1;

  } else if (strcmp(argv[1], "fit") == 0) {
    /* XXX FIXME XXX shouldn't need 'fitting' */
    fitting = 1;
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
	Constrain = loadConstrain(NULL);
	fit_constraints = NULL;
    }

  } else if (strcmp(argv[1], "set") == 0) {
    double *pd; int *pi;
    char result[20];
    if (!parsevar(what,&pi,&pd)) {
      Tcl_AppendResult(interp,"gmlayer variable ",what," is not defined",NULL);
      return TCL_ERROR;
    }
    if (argc > 3) {
      if (pi != NULL && Tcl_GetInt(interp,argv[3],pi) != TCL_OK)
	return TCL_ERROR;
      if (pd != NULL && Tcl_GetDouble(interp,argv[3],pd) != TCL_OK)
	return TCL_ERROR;
    }
    if (pi != NULL) { sprintf(result,"%d",*pi); }
    if (pd != NULL) { sprintf(result,"%.15g",*pd); }
    Tcl_SetResult(interp,result,TCL_VOLATILE);

  } else if (strcmp(argv[1], "send") == 0) {
    if (strcmp(what, "datafile") == 0) {
      Tcl_SetResult(interp,infile,TCL_STATIC);
    } else if (strcmp(what, "parfile") == 0) {
      Tcl_SetResult(interp,parfile,TCL_STATIC);
    } else if (strcmp(what, "constraints") == 0) {
      if (argc > 3) {
         cleanFree((void **)&ConstraintScript);
         if (strlen(argv[3])) {
            ConstraintScript = Tcl_Alloc(strlen(argv[3])+1);
            if (ConstraintScript)
                strcpy(ConstraintScript, argv[3]);
         }
      } else if (ConstraintScript != NULL)
         Tcl_SetResult(interp,ConstraintScript,TCL_VOLATILE);
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
      Tcl_SetResult(interp,fitlist,TCL_STATIC);
    } else if (strcmp(what, "pars") == 0) {
      sendpars(interp);
    } else if (strncmp(what, "data",4) == 0) {
      if (what[4] < 'a' || what[4] > 'd') {
	Tcl_AppendResult(interp,"expected gmlayer send datax, with x in [abcd]");
	return TCL_ERROR;
      }
      senddata(interp,what[4]);
    } else if (strcmp(what, "refl") == 0) {
      if (fitting) {
	/* If fitting, then the reflectivity is calculated and we
	   are ready to send. */
      } else if (0) {
#if 0
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
#endif
      } else {
	if (!loaded) build_q4x();
	/* XXX FIXME XXX - not checking alloc failure */
	extend(q4x, n4x, lambda, lamdel, thedel);
	genderiv4(q4x, y4x, n4x, 0);
      }
      sendreflect(interp,q4x,y4x,n4x,xspin);
    } else if (strcmp(what, "chisq") == 0) {
      char value[40];
      double ret;
      if (fitting) ret = chisq/(double)(npntsa+npntsb+npntsc+npntsd-mfit);
      else if (loaded) ret=onlyCalcChiSq(NULL);
      else ret = -1.0;
      sprintf(value,"%.15g",ret);
      Tcl_AppendResult(interp,value,NULL);
    } else if (strcmp(what, "prof") == 0) {
      if (!fitting) {
	ngenlayers(qcsq, d,  rough, mu,nlayer,zint,rufint,nrough,proftyp);
	mgenlayers(qcmsq,dm,mrough,the,nlayer,zint,rufint,nrough,proftyp);
	gmagpro4();
      }
      sendprofile(interp,argc>3);
    } else {
      Tcl_AppendResult(interp,"gmlayer send ?: expected pars, work, ...",NULL);
      return TCL_ERROR;
    }

  } else if (strcmp(argv[1],"msg") == 0) {
    printf("%s\n",what);
  } else if (strcmp(argv[1],"gd") == 0) {
    if (*infile) {
      loadData(infile,xspin);
      loaded = !failure;
    }
  } else {
    queue = argv+1;
    queued = argc-1;
    failure = 0;
    magblocks4();
    if (failure) {
      Tcl_AppendResult(interp,error_message,TCL_STATIC);
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


int Gj_Init(Tcl_Interp* interp)
{
  static int initialized = 0;
  Tcl_Obj *version;
  int r;

#if 0
  out = Tcl_GetChannel(interp, "stdout", NULL);
    if (out == NULL) {
      Tcl_AppendResult(interp, "could not find stdout", NULL);
      return TCL_ERROR;
    }
#endif

  fit_interp = interp;

  debug_message("gmlayer init\n");

  if (initialized) {
    Tcl_AppendResult(interp, "Only one copy of gmlayer is allowed", NULL);
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

  /* Global variable initialization */
  strcpy(parfile, "mlayer.staj");
  Constrain = loadConstrain(NULL);
  loaded = 0; /* No data loaded yet */

  Tcl_CreateCommand(interp, "gmlayer",
		    gmlayer_TclCmd,
		    (ClientData)NULL,
		    gmlayer_TclEnd);


  return r;
}

int Gj_SafeInit(Tcl_Interp* interp)
{
  Tcl_AppendResult(interp, "gmlayer is not a safe command", NULL);
  return TCL_ERROR;

  // Until we remove commands to read/write files, we are not safe...
  // return gmlayer_Init(interp);
}


#include <math.h>
#include <tcl.h>

#if defined(__MINGW32__)

/* MinGW is missing some of the C99 functions still.  Pull them in
 * from Sun Microsystem's fdlibm */
extern double __ieee754_acosh(double);
extern double __ieee754_atanh(double);
extern double asinh(double);
extern double expm1(double);
#define acosh __ieee754_acosh
#define atanh __ieee754_atanh

#endif

#define CONSTANT(name) expr_register_constant(interp,#name,&name);
#define NULLARY(name) expr_register_nullary(interp,#name,name);
#define UNARY(name) expr_register_unary(interp,#name,name);
#define BINARY(name) expr_register_binary(interp,#name,name);
#define TERNARY(name) expr_register_ternary(interp,#name,name);

typedef double (*NullaryFn)(void);
typedef double (*UnaryFn)(double);
typedef double (*BinaryFn)(double, double);
typedef double (*TernaryFn)(double, double, double);

static int constant(ClientData val, Tcl_Interp *interp,
		      Tcl_Value *args, Tcl_Value *resultPtr)
{
  resultPtr->doubleValue = *(double *)val;
  resultPtr->type = TCL_DOUBLE;
  return TCL_OK;
}

static int nullary(ClientData fn, Tcl_Interp *interp,
		      Tcl_Value *args, Tcl_Value *resultPtr)
{
  resultPtr->doubleValue = (*(NullaryFn)fn)();
  resultPtr->type = TCL_DOUBLE;
  return TCL_OK;
}

static int unary(ClientData fn, Tcl_Interp *interp,
		      Tcl_Value *args, Tcl_Value *resultPtr)
{
  resultPtr->doubleValue = 
    (*(UnaryFn)fn)(args[0].doubleValue);
  resultPtr->type = TCL_DOUBLE;
  return TCL_OK;
}

static int binary(ClientData fn, Tcl_Interp *interp,
		  Tcl_Value *args, Tcl_Value *resultPtr)
{
  resultPtr->doubleValue = 
    (*(BinaryFn)fn)(args[0].doubleValue,args[1].doubleValue);
  resultPtr->type = TCL_DOUBLE;
  return TCL_OK;
}

static int ternary(ClientData fn, Tcl_Interp *interp,
		   Tcl_Value *args, Tcl_Value *resultPtr)
{
  resultPtr->doubleValue = 
    (*(TernaryFn)fn)(args[0].doubleValue,args[1].doubleValue,args[2].doubleValue);
  resultPtr->type = TCL_DOUBLE;
  return TCL_OK;
}

void expr_register_constant(Tcl_Interp *interp, const char *name, double *val)
{
  Tcl_CreateMathFunc(interp, name, 0, NULL, constant, val);
}

void expr_register_nullary(Tcl_Interp *interp, const char *name, NullaryFn fn)
{
  Tcl_CreateMathFunc(interp, name, 0, NULL, constant, fn);
}

void expr_register_unary(Tcl_Interp *interp, const char *name, UnaryFn fn)
{
  Tcl_ValueType sig[1] = {TCL_DOUBLE};
  Tcl_CreateMathFunc(interp, name, 1, sig, unary, fn);
}

void expr_register_binary(Tcl_Interp *interp, const char *name, BinaryFn fn)
{
  Tcl_ValueType sig[2] = { TCL_DOUBLE, TCL_DOUBLE };
  Tcl_CreateMathFunc(interp, name, 2, sig, binary, fn);
}

void expr_register_ternary(Tcl_Interp *interp, const char *name, TernaryFn fn)
{
  Tcl_ValueType sig[3] = { TCL_DOUBLE, TCL_DOUBLE, TCL_DOUBLE };
  Tcl_CreateMathFunc(interp, name, 3, sig, ternary, fn);
}

static double signgamma(double x)
{
  return ( x < 0. && (int)(x-1.)%2 ) ? -1. : 1.;
}

void C99_expr(Tcl_Interp *interp)
{
#ifdef NEED_C99_MATH_PROTOTYPES 
  /* These are defined by default in C99 math.h */
  extern double exp2(double);
  extern double fdim(double,double);
  extern double fma(double,double,double);
  extern double fmax(double,double);
  extern double fmin(double,double);
  extern double log2(double);
  extern double nearbyint(double);
  extern double tgamma(double);
  extern double trunc(double);
#endif
  static double pi,e;
  pi = 4.0*atan(1.0);
  e = exp(1.0);

  /* Skip the builtin functions: */
  /* abs ceil floor fmod round exp log log10 pow sqrt hypot */
  /* acos cos cosh asin sin sinh atan atan2 tan tanh */
  CONSTANT(pi);
  CONSTANT(e);
  UNARY(acosh);
  UNARY(asinh);
  UNARY(atanh);
  UNARY(cbrt);
  BINARY(copysign);
  UNARY(erf);
  UNARY(erfc);
  UNARY(exp2);
  UNARY(expm1);
  UNARY(fabs);
  BINARY(fdim);
  TERNARY(fma);
  BINARY(fmax);
  BINARY(fmin); 
  /* fpclassify - return integer constant */
  /* frexp - modifies its arguments */
  /* ilogb - returns integer */
  /* isfinite isinf isnan isnormal */
  /* isgreater isgreaterequal isless islessequal islessgreater isunordered */
  /* ldexp - second arg is integer */ 
  UNARY(lgamma);
  UNARY(signgamma);
  /* llrint llround */
  UNARY(log1p);
  UNARY(log2);
  UNARY(logb); 
  /* lrint lround */
  /* modf - modifies its args */
  /* nan - requires string */
  UNARY(nearbyint);
  BINARY(nextafter);
  /* nexttoward - send arg is long */ 
  BINARY(remainder);
  /* remquo - modifies its args */
  UNARY(rint);
  /* scalbn scalbln - second arg is integer */
  /* signbit - macro */
  UNARY(tgamma);
  UNARY(trunc);
}

int Scifun_Init(Tcl_Interp* interp)
{
  Tcl_Obj *version;
  int r;

#ifdef USE_TCL_STUBS
  Tcl_InitStubs(interp, "8.0", 0);
#endif
  version = Tcl_SetVar2Ex(interp, "scifun_version", NULL,
			  Tcl_NewDoubleObj(VERSION), TCL_LEAVE_ERR_MSG);
  if (version == NULL)
    return TCL_ERROR;
  r = Tcl_PkgProvide(interp, "scifun", Tcl_GetString(version));

  C99_expr(interp);

  return r;
}

int Scifun_SafeInit(Tcl_Interp* interp)
{
  return Scifun_Init(interp);
}

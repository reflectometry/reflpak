Adds (some of the) missing C99 functionality to Tcl's expr.
Available from a safe interpreter.

The following are builtin functions:

  abs ceil floor fmod round exp log log10 pow sqrt hypot
  acos cos cosh asin sin sinh atan atan2 tan tanh

The following are added:

  pi()		= 4*atan(1)
  e()		= exp(1)
  acosh asinh atanh  - inverse hyperbolic functions
  cbrt(x)	= x^{1/3}
  copysign(x,y)	= sign(y) * |x|
  erf(x)	= 2 / sqrt(\pi) \int_0^x exp(-t*t) dt
  erfc(x)	= 1 - erf(x) 
  exp2(x)	= 2^x
  expm1(x)	= e^x-1
  fabs(x)	= |x|
  fdim(x,y)	= max(x-y,0)
  fma(x,y,z)    = x*y + z
  fmax(x,y)	= max(x,y)
  fmin(x,y)	= min(x,y)
  remainder(x,y)	= x - round(x/y)*y 
  trunc(x)	= sign(x) * floor(abs(x))
  tgamma(x)	= \Gamma(x)
  lgamma(x)	= ln(\Gamma(x)) 
  signgamma(x)	= sign(\Gamma(x)) 
  log1p(x)	= ln(1+x)
  log2(x)	= log_2(x) 
  logb(x)	= floor(log_2(x))

Rather than signgam as a value, I've defined it as a function:

  signgamma(x) = (x<0 && int(x-1.)%2 ? -1. : 1.)

The following are missing:

  fpclassify 	 - returns integer constant
  frexp 	 - modifies its arguments
  ilogb 	 - returns integer
  isgreater isgreaterequal isless islessequal islessgreater isunordered 
			isfinite isinf isnan isnormal
	         - tcl doesn't support inf/nan.
  ldexp  	 - second arg is integer 
  llrint llround lrint lround
		 - return integers
  modf 		 - modifies its args
  nan 		 - requires string
  nearbyint rint - use round instead
  nextafter	 - conflicts with expr's 'ne' processing
  nexttoward 	 - second arg is long 
  remquo 	 - modifies its args
  scalbn scalbln - second arg is integer 
  signbit 	 - macro

There is no reason not to add more of these, but doing so will require
a bit more work in the code.

Installation is a bit tricky since it requires compiling an app using
a C99 compliant compiler.  For now, I'm leveraging off the hand-tooled
build rules for another project.  You will need to role your own.

This code is in the public domain.

Paul Kienzle
pkienzle@users.sf.net

## tol = run_tol(x1, x2, fuzz=0.0195)
##
## Determine range which tolerance for deciding if x values correspond to
## the same point.  This is the minimum spacing of values in x1 and x2,
## times some percentage of fuzz.
function tol = run_tol(x1, x2, fuzz)
  if (nargin < 3) fuzz = 0.0195; end
  tol = fuzz * min( [ diff(x1(:)); diff(x2(:)) ] );
endfunction

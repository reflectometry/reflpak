## tol = run_tol(x1, x2, fuzz=0.0195)
##
## Determine tolerance for deciding if x values correspond to the 
## same point.
##
## XXX FIXME XXX scrap this function...it is broken conceptually.
## We should instead use tolerance based on the resolution of the
## instrument.  It used to be based on the minimum difference between
## points, but that doesn't work very well if points are repeated
## or if there is only one point.
function tol = run_tol(x1, x2, fuzz)
    tol = 100*eps;
endfunction

## r = run_poisson_avg(r1 [,r2])
## Join run 1 and run 2, averaging the points that are near to each other.
## If only one run is given, then nearby points will be averaged.
##
## To average y1, ..., yn, use:
##     w = sum( y/dy^2 )
##     y = sum( (y/dy)^2 )/w
##     dy = sqrt ( y/w )
## Note that pavg(y1,...,yn) == pavg(y1,avg(y2, ..., avg(yn-1,yn)...))
## to machine precision, as tested against for example
##     pavg(logspace(-10,10,10))
##
## To process slitscans, we need to carry around an extra vector m which
## indicates the slit position for each x value.  Only x values with
## identical m values may be averaged.  On exit, the new m vector contains
## points corresponding to the new x values.  It is assumed that m values
## are linear in x so that they can be averaged when similar x values are
## averaged.
##
## XXX FIXME XXX This function assumes that the slits are correct.
function [ run ] = run_poisson_avg (run1, run2)

  ## XXX FIXME XXX what to use for step size when only one run?
  if isempty(run2) || nargin == 1
    run = run1;
    tol = 10*eps;
  elseif isempty(run1)
    run = run2;
    tol = 10*eps;
  else
    run = run1;
    run.x = [ run1.x ; run2.x ];
    run.y = [ run1.y ; run2.y ];
    run.dy = [ run1.dy; run2.dy ];
    if struct_contains(run1,'m') && struct_contains(run2,'m')
      run.m = [ run1.m ; run2.m ];
    endif
    tol = run_tol(run1.x,run2.x);
  endif

  [x, idx] = sort(run.x);
  y = run.y(idx);
  dy = run.dy(idx);
  use_m = struct_contains(run,'m');
  if use_m, m = run.m(idx); endif
  
  
  ## merge values with nearly identical x coordinates
  ## XXX FIXME XXX clusters are formed when consecutive x-values
  ## are within some tolerance.  Consider the points x-tol, x, x+tol
  ## which are in the same cluster even though (x+tol)-(x-tol) > tol.
  near = diff(x) <= tol;
  if any(near)
    ## put each value in a different row
    r = [1:length(x)]';
    ## put each cluster in a different column
    c = r-cumsum([0; near]);

    ## average the x values
    
    ## Simple version which averages clustered values, but also
    ## 'averages' singletons y with relative error 0 < err < 10*eps.
    x = spsum(sparse(r,c,x))'./spsum(sparse(r,c,1))';
    if use_m, m = spsum(sparse(r,c,m))'./spsum(sparse(r,c,1))'; endif
    ## poisson statistics for y, dy
    weight = spsum(sparse(r,c,y./dy.^2))';
    weight(weight == 0) = 1;
    y = spsum(sparse(r,c,(y./dy).^2))' ./ weight;
    dy = sqrt ( y ./ weight );
    dy(dy == 0) = 1;
    
    ## ## More complicated version which only averages the clusters.
    ## ## Not debugged.  Doesn't handle empty matrices
    ## near = [0; near] | [near; 0];
    ## r = r(near);
    ## c = c(near);
    ## xn = x(near);
    ## yn = y(near);
    ## dyn = dy(near);
    ## ## average the x values
    ## xn = spsum(sparse(r,c,xn))'./spsum(sparse(r,c,1))';
    ## ## poisson statistics for y, dy
    ## weight = spsum(sparse(r,c,yn./dyn.^2))';
    ## weight(weight == 0) = 1;
    ## yn = spsum(sparse(r,c,(yn./dyn).^2))'./weight;
    ## dyn = sqrt(yn ./ weight);
    ## dyn(dyn == 0) = 1;
    ## ## merge the clustered points with the non-clustered points by
    ## ## first removing the clustered points from the set and then
    ## ## sorting back in the non-clustered points
    ## x(near) = [];
    ## y(near) = [];
    ## dy(near) = [];
    ## [x, idx] = sort([xn;x]);
    ## y = [yn;y](idx);
    ## dy = [dyn;dy](idx);
  endif
  
  run.x = x;
  run.y = y;
  run.dy = dy;
  if use_m, run.m = m; endif
  ## run = runlog(run1,"join",run2);

  if nargout == 0
    plotrunop(run,run1,run2);
  else
    ret = run;
  endif

endfunction

## r = run_avg(r1,r2)
## Join run 1 and run 2, averaging the points that are near to each other.
## Uses gaussian statistics.
function [ run ] = run_avg (run1, run2)

  error("get cluster code from run_poisson_avg");
  if isempty(run1)
    run = run2;
  elseif isempty(run2)
    run = run1;
  else
    [x, idx] = sort([ run1.x ; run2.x ]);
    y = [ run1.y ; run2.y ](idx);
    dy = [ run1.dy ; run2.dy ](idx);
    
    ## merge values with nearly identical x coordinates
    tol = run_tol(run1.x,run2.x);
    idx = find(diff(x) < tol);
    if !isempty(idx)
      if any(idx==idx+1)
	error("samples spaced to closely for tolerance");
      endif
      ## usual average of x1 and x2 -> x1
      x(idx) = (x(idx)+x(idx+1))/2;
      ## error-weighted average of y1 and y2 -> y1
      weight = 1./dy(idx).^2 + 1./dy(idx+1).^2;
      y(idx) = (y(idx)./dy(idx).^2 + y(idx+1)./dy(idx+1).^2) ./ weight;
      dy(idx) = 1./sqrt(weight);
      ## remove x2,y2,y2err
      x(idx+1) = [];
      y(idx+1) = [];
      dy(idx+1) = [];
    endif

    run.x = x;
    run.y = y;
    run.dy = dy;
    ## run = runlog(run1,"join",run2);
  endif

  if nargout == 0
    plotrunop(run,run1,run2);
  else
    ret = run;
  endif

endfunction

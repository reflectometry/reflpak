## run = run_interp(run, x)
##
## Resample the values in run so that they correspond to the points in x.
## Only include points of x that are within the domain of run.  Note that
## the domain of the run includes one interval before the first and after the
## last x value of run, wherein values are extrapolated.  Only linear
## interpolation is supported, although at some point some sort of weighted
## spline with variable tension may be used.

function run = run_interp(run,x,method)

  if length(run.x) < 2
    error("run_interp requires at least two points to interpolate");
  endif

  ## XXX FIXME XXX if we change this to use interp1err, be sure to
  ## fix the hack for extrapolation --- we don't want the error
  ## outside the measured range to be smaller than that inside the
  ## range.

  ## Repeat the end points.  That way linear extrapolation will yield
  ## the same values no matter how far things are extrapolated.
  if (columns(run.x) == 1)
    run.x = [run.x(1)-1; run.x; run.x(length(run.x))+1];
    run.y = [run.y(1); run.y; run.y(length(run.y))];
    run.dy = [run.dy(1); run.dy; run.dy(length(run.dy))];
  else
    run.x = [run.x(1)-1, run.x, run.x(length(run.x))+1];
    run.y = [run.y(1), run.y, run.y(length(run.y))];
    run.dy = [run.dy(1), run.dy, run.dy(length(run.dy))];
  endif


  ## linear interpolation from run values to new x values
  ## note: extrapolation is limited to runtolerance so it is safe
  y = interp1 (run.x, run.y, x, 'linear', 'extrap');

  ## estimate error on interpolated values
  ## XXX FIXME XXX linear interpolation on the error can't be right!
  ## How about sqrt(run1.y) after the interpolation?
  dy = interp1 (run.x, run.dy, x, 'linear', 'extrap');

  run.x = x;
  run.y = y;
  run.dy = dy;
  ## run = runlog(run, "interpolating", x);

endfunction

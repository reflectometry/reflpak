
## run = run_trunc(run, x)
##
## Chop the range of the run so that it is within the range of x.
##
## Example
##    run2 = run_interp(run2, run1.x);
##    run1 = run_trunc(run1, run2.x);
##    run = run_sub(run1, run2);
function run = run_trunc(run, x)

  s1 = run.x(1); e1 = run.x(length(run.x)); 
  s2 = x(1); e2 = x(length(x));
  if s1 < s2 || e1 > e2
    msg = sprintf("truncating range from [%f,%f] to [%f,%f]",s1,e1,s2,e2);
    ## run = runlog(run, msg);
    warning(msg);
    idx = (run.x < s2 | run.x > e2);
    run.x(idx) = [];
    run.y(idx) = [];
    run.dy(idx) = [];
  endif

  ## runlog(run, "truncating", [x(1), x(length(x))])
endfunction

## r = run_sub (r1, r2)
##
## Subtract the signal in r2 from r1. Unless there is an exact correspondance
## r2 should first be interpolated to the points in r1 using run_interp, and
## r1 should be truncated to the range of r2 using run_trunc.
function run1=run_sub (run1,run2)

  assert(run1.x, run2.x);

  ## do the subraction
  run1.dy = sqrt (run1.dy .^2 + run2.dy .^ 2);
  run1.y -= run2.y;

  ## run1 = runlog(run1, "subtracting", run2);

endfunction

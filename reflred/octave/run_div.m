## r = run_div(r1, r2)
##
## Divide the y values in r1 by the y values in r2.  This assumes the
## domain of r1 matches the domain of r2.  If not, call run_interp and
## or run_trunc beforehand.

function run1 = run_div(run1,run2)

  assert(run1.x,run2.x);

  ## do the division
  run1.dy = sqrt ( (run1.dy./run2.y) .^2 + (run1.y.*run2.dy./run2.y.^2) .^ 2 );
  run1.y = run1.y ./ run2.y;

  ## run1 = runlog(run1, "dividing", run2);

endfunction

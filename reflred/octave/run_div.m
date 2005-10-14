## r = run_div(r1, r2)
##
## Divide the y values in r1 by the y values in r2.  This assumes the
## domain of r1 matches the domain of r2.  If not, call run_interp and
## or run_trunc beforehand.

function run = run_div(run1,run2)

  ## do the division
  if isempty(run1) || isempty(run2)
    run = [];
  elseif isfield(run1,'A') && isfield(run2,'A')
    run.A = run_div(run1.A,run2.A);
    run.B = run_div(run1.B,run2.B);
    run.C = run_div(run1.C,run2.C);
    run.D = run_div(run1.D,run2.D);
  elseif isfield(run1,'A')
    run.A = run_div(run1.A,run2);
    run.B = run_div(run1.B,run2);
    run.C = run_div(run1.C,run2);
    run.D = run_div(run1.D,run2);
  elseif isfield(run2,'A')
    run.A = run_div(run1,run2.A);
    run.B = run_div(run1,run2.B);
    run.C = run_div(run1,run2.C);
    run.D = run_div(run1,run2.D);
  else
    assert(run1.x,run2.x);
    run.x = run1.x;
    run.dy = sqrt ( (run1.dy./run2.y) .^2 + (run1.y.*run2.dy./run2.y.^2) .^ 2 );
    run.y = run1.y ./ run2.y;
  end

endfunction

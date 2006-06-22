## r = run_scale(r,k,dk)
## Scale run r by factor k which has uncertainty dk.
## To scale by 1/k, use k=1/k, dk=dk/k^2
##
## If you do not know the scale factor a priori, you can use calcscale 
## to estimate it from the overlapping region of two runs that you wish
## to join.
function run = run_scale(run,k,dk)

  if nargin<2 || nargin>3, usage("r=run_scale(r,k,dk)"); end
  if isempty(run), return; end
  if !isstruct(run), error("run_scale expects a run"); end
  if isfield(run,'A')
     if nargin == 2, dk = 0.; end
     run.A = run_scale(run.A,k,dk);
     run.B = run_scale(run.B,k,dk);
     run.C = run_scale(run.C,k,dk);
     run.D = run_scale(run.D,k,dk);
     return;
  endif


  if (nargin == 2)
    run.dy *= k;
  else
    run.dy = sqrt ( k^2 * run.dy .^2 + run.y .^2 * dk^2 );
  end
  run.y *= k;

  ## run = logrun(run, sprintf ("scaling by %f +/- %f", k, dk));

endfunction

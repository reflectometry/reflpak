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

  if (nargin == 2)
    run.dy *= k;
  else
    run.dy = sqrt ( k^2 * run.dy .^2 + run.y .^2 * dk^2 );
  endif
  run.y *= k;

  ## run = logrun(run, sprintf ("scaling by %f +/- %f", k, dk));

endfunction

## r = run_invscale(r, v, dv)
##   Divide r by v with uncertainty.
function run=run_invscale(run,v,dv)
  run = run_scale(run, 1/v, dv/v^2);

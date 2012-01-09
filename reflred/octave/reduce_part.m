## Build a polarization run from a summed set of parts
function part = reduce_part(part,run,monitor,pol)
  if isempty(part)
    if nargin > 3 && !isempty(pol)
      part.polarized = 1;
      part.A = part.B = part.C = part.D = [];
      part.(pol) = run_scale(run,monitor);
    else
      part = run_scale(run,monitor);
      part.polarized = 0;
    endif
  else
    if part.polarized != (nargin>3 && !isempty(pol))
      error("cannot mix polarized and unpolarized datasets");
    endif
    if part.polarized
      part.(pol) = run_poisson_avg(part.(pol),run_scale(run,monitor));
    else
      part = run_poisson_avg(part,run_scale(run,monitor));
    endif
  endif  
endfunction
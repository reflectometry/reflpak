## run_include(run,cond)
## Only include values in run for which cond is true
function r = run_include(r, cond)
  idx = find(cond);
  r.x = r.x(idx);
  r.y = r.y(idx);
  r.dy = r.dy(idx);
  if isfield(r,'m'), r.m = r.m(idx); endif
endfunction

1;
function y = G(x,p)
  y = p(1)*exp(-(p(2)-x).^2/p(3));
end
function y = dG(x,p)
  A = exp(-(p(2)-x).^2/p(3));
  y = [
    A, ...
    p(1)*A.*(-2*(p(2)-x))/p(3), ...
    p(1)*A.*((p(2)-x).^2/p(3).^2)
  ];
end
function chisq = gchisq(p,x,y)
  chisq = sumsq(G(x,p)-y);
end

function [p,chisq] = gfit(x,y,dy)
  [val,idx] = max(y);
  p0 = [val*1.1;x(idx)+0.5;sqrt(x(idx)-x(1))*0.9];
  if 0
    minstep = 1e-3*ones(3,1);
    maxstep = 0.8*ones(3,1);
    options = [minstep,maxstep];
    [f,p] = leasqr(x,y,p0,"G",1e-10,100,dy,[1;1;1]*1e-3,"dfdp",options);
    chisq = sumsq(G(x,p)-y);
  else
    [p,chisq] = nelder_mead_min("Gchisq",list(p0,x,y));
  endif
end
function p = gfitdemo,
  A = 0.5;
  c = 0;
  w = 5;
  x = [-10.5:10.5]';
  y = G(x,[A;c;w]);
  dy = sqrt(100*y+10)/110;
  y += randn(size(y)).*dy;
  errorbar(x,y,dy);
  p = Gfit(x,y,dy);
  t = linspace(min(x),max(x),200);
  f = G(t,p);
  hold on; plot(t,f,';fit;'); hold off;
end

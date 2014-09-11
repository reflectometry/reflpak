function h_out = fitslits(r)

  if isempty(r) || isempty(r.A) || isempty(r.B) || isempty(r.C) || isempty(r.D)
    h_out = [];
    return
  endif

  %# remember data
  h.Ia = r.A;
  h.Ib = r.B;
  h.Ic = r.C;
  h.Id = r.D;

  %# remember range
  all_s = [r.A.x;r.B.x;r.C.x;r.D.x];
  h.lo = min(all_s);
  h.hi = max(all_s);

  %# determine the order of the model for each slit
  h.A = testlinslit(r.A);
  h.B = testlinslit(r.B);
  h.C = testlinslit(r.C);
  h.D = testlinslit(r.D);

  %# if any of the models are quadratic, check if a quad-linear
  %# model is supported
  if any([h.A.p(1), h.B.p(1), h.C.p(1), h.D.p(1)])
    %# z = minimize('slitmin', list((h.lo+h.hi)/2, h), 'maxev', 1000);
    z = fminbnd(@(z)slitmin(z,h), h.lo, h.hi);
    %# if quadlinear is supported for any models, use it for all
    [prA, qlA] = testquadslit(r.A,h.A,z);
    [prB, qlB] = testquadslit(r.B,h.B,z);
    [prC, qlC] = testquadslit(r.C,h.C,z);
    [prD, qlD] = testquadslit(r.D,h.D,z);
    if any([prA,prB,prC,prD] > 0.95)
      h.A = qlA; h.B = qlB; h.C = qlC; h.D = qlD;
    end
  end

  %# plot or return
  if nargout, h_out = h; else slitplot(h); end

end

function v = slitmin(z,h)
  v = 0;
  if h.A.p(1), v = v + qlslit(z,h.Ia); end
  if h.B.p(1), v = v + qlslit(z,h.Ib); end
  if h.C.p(1), v = v + qlslit(z,h.Ic); end
  if h.D.p(1), v = v + qlslit(z,h.Id); end
end

%# Use chisq test to see if A.x,A.y,A.dy is best fit to a linear
%# or a quadratic.  Return the best fit.
function ret = testlinslit(A)
  n = length(A.x);
  if n < 1
    error('fitslits: no points!');
  elseif n == 1
    warning('check uncertainty calculated when n=1');
    ret.S = struct('R',eye(3), 'df',1, 'normr',tinv(1-erf(1/sqrt(2))/2,1));
    ret.p = [0;0;A.y];
    ret.z = min(A.x);
  else
    [lin,Slin] = wpolyfit(A.x,A.y,A.dy,1);
    if n > 2
      [quad,Squad] = wpolyfit(A.x,A.y,A.dy,2);
      F = (Slin.normr^2 - Squad.normr^2)/(Squad.normr^2/Squad.df);
      prob = fcdf(F,1,Squad.df);
    else
      prob = 0;
    end
    if (prob > 0.95)
      ret.S = Squad;
      ret.p = quad;
      ret.z = max(A.x);
    else
      ret.S = Slin;
      ret.S.R = eye(3);
      ret.S.R(2:3,2:3) = Slin.R;
      ret.p = [0;lin(:)];
      ret.z = min(A.x);
    end
  end
end

%# Use chisq test to see if A.x,A.y,A.dy is best fit to a quadratic
%# or a quad-linear with cross-over point z.  The result of the 
%# quadratic fit is assumed to already be in quad.  Return the
%# probability that the quad-linear fit is better, and return the
%# parameters of the fit.
function [prob, ret] = testquadslit(A,quad,z)
  [junk,p,S] = qlslit(z,A);
  ret.S = S;
  ret.p = p;
  ret.z = z;
  if quad.p(1) != 0   % data don't support anything beyond linear
    F = (quad.S.normr^2 - S.normr^2)/(S.normr^2/S.df);
    prob = fcdf(F,1,S.df);
  else
    prob = 0.0;
  end
end

%# Find the best quad-linear parameters p for a given z
function [v,p,s] = qlslit(z,A)
  x = A.x(:);
  Q = ones(length(x),3);
  Q(:,1) = x.^2 - (x>z).*(x-z).^2;
  Q(:,2) = x;
  [p,s] = wsolve(Q,A.y(:),A.dy(:));
  s.df--;
  v = s.normr.^2;
end


%# plot the slits and the fits to the slits
function slitplot(h)
  clg;
  sf = linspace(h.lo,h.hi,100);
  semilogy(sf,feval('qlconf',sf,h.A.p,h.A.z,h.A.S),'-g;A;',
	   sf,feval('qlconf',sf,h.B.p,h.B.z,h.B.S),'-b;B;',
	   sf,feval('qlconf',sf,h.C.p,h.C.z,h.C.S),'-m;C;',
	   sf,feval('qlconf',sf,h.D.p,h.D.z,h.D.S),'-r;D;');
  hold on;
 if 0
  semilogy(h.Ia.x,h.Ia.y,'*g;;',0);
  semilogy(h.Ib.x,h.Ib.y,'*b;;',0);
  semilogy(h.Ic.x,h.Ic.y,'*m;;',0);
  semilogy(h.Id.x,h.Id.y,'*r;;',0);
 else
  semilogyerr(h.Ia.x,h.Ia.y,h.Ia.dy,'g;;');
  semilogyerr(h.Ib.x,h.Ib.y,h.Ib.dy,'b;;');
  semilogyerr(h.Ic.x,h.Ic.y,h.Ic.dy,'m;;');
  semilogyerr(h.Id.x,h.Id.y,h.Id.dy,'r;;');
 end
  hold off;
end


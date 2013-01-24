% [p,z,s] = qlfit(x,y,dy,z)
% [p,z,s] = qlfit([x,y,dy],z)
% [p,z,s] = qlfit(struct(x,y,dy),z)
%
% Use linear regression to fit a piece-wise quadratic+linear
% function to weighted data.  Below z the function is quadratic
% but above z the function is linear.  The function is smooth at z.
%
% If z is not given, use a nonlinear minimization routine to fit z.
% If z is purely linear z=min(x). If z is purely quadratic, z=max(x).
%
% Useful subfunctions (available with feval):
%   qlfit:plt(x,y,dy,p,z,s) 
%     Plot the fit
%   [x,y,dy] = qlfit:gen(z,p,n)
%     Generate random data in [0,20].  If z is present, it specifies
%     the position in the range. If p is present, it scales the
%     default polynomial (variance=|x|, so smaller p means higher
%     relative uncertainty).  If n is present, it specifies the
%     number of points in the range, or if it is a vector, the
%     x values to use.
%   [y,dy] = qlfit:conf(x,p,z,s)
%     Generate fit values and confidence for selected x.
%
% You can do something similar for any set of piece-wise
% polynomials.  Here are the equations for a variety of them:
%
%   lin-lin:    a0 + a1 x + a2 Rz(x)
%   lin-lin*:   a0 + a1 x + a2 Rz1(x) + a3 Rz2(x) + ...
%   lin-quad:   a0 + a1 x + a2 Rz(x)^2
%   quad-lin:   a0 + a1 x + a2 (x^2 - Rz(x)^2)
%   quad-quad:  a0 + a1 x + a2 x^2 + a3 Rz(x)^2
%   quad-quad*: a0 + a1 x + a2 x^2 + a3 Rz1(x)^2 + a4 Rz2(x)^2 + ...
%   cubic*:     a0 + a1 x + a2 x^2 + a3 x^3 + a4 Rz1(x)^3 + ...
%
% where Rz is shorthand for the shifted ramp function: 
%
%   Rz(x) = (x>z).*(x-z)
%
% Here is how to solve quad-lin:
%
%   A = ones(length(x),3);
%   A(:,1) = x.^2 - (x>z).*(x-z).^2;
%   A(:,2) = x;
%   p = wsolve(A,y,dy);
%
% And to plot the result:
%
%   t = linspace(x(1),x(end),150);
%   f = polyval(p,t) - p(1)*(t>z).*(t-z).^2;
%   plot(t,f);
%
% To find the optimal knot position z qlfit uses the a nonlinear 
% search bfgsmin.
%
% function chisq = f(z,x,y,dy)
%   A = ones(length(x),3);
%   A(:,1) = (x.^2 - (x>z).*(x-z).^2);
%   A(:,2) = x;
%   [p,s] = wsolve(A,y,dy);
%   chisq = s.normr^2;
% end
% bfgsmin('f',{mean(x),x,y,dy},{10,1,1,1});

function [p_out,z,S] = qlfit(x,y,dy,z)

  if nargin < 1, usage("[p,z,s] = qlfit(x,y,dy [,z])"); end

  % simplify inputs
  if nargin < 3,
    if nargin == 2, z=y; end
    
    if isstruct(x)
      if isfield(x,'dy') dy = x.dy;
      else dy = [];
      end
      y = x.y;
      x = x.x;
    elseif columns(x) == 3
      dy = x(:,3);
      y = x(:,2);
      x = x(:,1);
    elseif columns(x) == 2
      dy = [];
      y = x(:,2);
      x = x(:,1);
    else
      error('qlfit expects x,y,dy or [x,y,dy] or s.x,s.y,s.dy');
    end
  end

  % test for linearity
  n = length(x);
  if n>1
    [lin,Slin] = wpolyfit(x,y,dy,1);
    [quad,Squad] = wpolyfit(x,y,dy,2);
    F = (Slin.normr^2 - Squad.normr^2)/(Squad.normr^2/Squad.df);
    prob = fcdf(F,1,Squad.df);
  endif
  if n==1
    warning('check uncertainty calculated for n=1');
    S.R=eye(3);
    S.df = 1;
    S.normr = tinv(1-erf(1/sqrt(2))/2,1);
    p = [0;0;y];
    z = min(x);
  elseif prob > 0.95
    if nargin > 3
      qlz = z;
    else 
      [qlz,v] = minimize('qlfun',list(mean(x),x,y,dy),'maxev',1000);
    end
    [junk,ql,Sql] = qlfun(qlz,x,y,dy);
    F = (Squad.normr^2 - Sql.normr^2)/(Sql.normr^2/Sql.df);
    prob = fcdf(F,1,Sql.df);
    if prob > 0.95 || nargin > 3
      S = Sql;
      p = ql;
      z = qlz;
    else
      S = Squad;
      p = quad;
      z = max(x);
    end
  else
    S = Slin;
    S.R = eye(3);
    S.R(2:3,2:3) = Slin.R;
    p = [0;lin(:)];
    z = min(x);
  end

  if nargout == 0,
    plt(x,y,dy,p,z,S);
  else
    p_out = p;
  end
end

function [v,p,s] = qlfun(z,x,y,dy)
  x = x(:); y = y(:); dy = dy(:);
  A = ones(length(x),3);
  A(:,1) = x.^2 - (x>z).*(x-z).^2;
  A(:,2) = x;
  [p,s] = wsolve(A,y,dy);
  s.df--;
  v = s.normr.^2;
end

function plt(x,y,dy,p,z,s)
  sym = setstr((p>=0)*toascii('+') + (p<0)*toascii('-'));
  printf("%g (x^2 - Hz(x-%g)^2) %s %g x %s %g\n", ...
	 p(1), z, sym(2), abs(p(2)), sym(3), abs(p(3)));
  xh = linspace(min(x),max(x),150)';
  [yh,dyh] = qlconf(xh,p,z,s);
  if p(1) == 0 || z <= min(x)
    shape='linear';
  elseif z >= max(x)
    shape='quadratic';
  else
    shape='quadratic-linear';
  endif
  plot(xh,yh,['-b;',shape,';'],xh,[yh+dyh,yh-dyh],'-g;;');
  hold on; errorbar(x,y,dy,'~'); hold off;

  if strcmp(deblank(input("Plot residuals? ","s")),"y")
    grid on; plot(xh,[dyh,-dyh],'g.;;');
  hold on; errorbar(x,y-qlconf(x,p,z,s),dy,'~'); hold off;
  end

  if strcmp(deblank(input("Plot p(z)? ","s")),"y")
    lo = min(x); hi = max(x);
    v = zi = linspace((99*lo+hi)/100,hi,100);
    for i=1:length(zi), v(i) = qlfun(zi(i),x,y,dy); end
    vbest = qlfun(z,x,y,dy);
    v = 100*(1-chisquare_cdf(v,length(x)-4));
    vbest = 100*(1-chisquare_cdf(vbest,length(x)-4));
    plot(zi,v,'-b;p(z);',z,vbest,'xr;best z;');
  end

end

function [x,y,dy] = gen(z,p,n)
  if nargin < 3, n=15; end
  if isscalar(n), x = linspace(0,20,n)'; else x = n; end
  if nargin < 2, p = [15,83,390]; end
  if nargin < 1, z = mean(x); end
  if isscalar(p), p = p*[15,83,390]; end
  y = polyval(p,x) - p(1)*(x>z).*(x-z).^2;
  dy = sqrt(y); % Poisson statistics
  y += randn(size(y)).*dy;
end


%!demo
%! p = 10*[.5,2,15]; z=8;
%! x = linspace(0,20,15)';
%! y = polyval(p,x) - p(1)*(x>z).*(x-z).^2;
%! dy = sqrt(abs(y)); % Poisson statistics
%! y += randn(size(y)).*dy;
%! qlfit(x,y,dy);

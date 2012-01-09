## -*- texinfo -*-
## @deftypefn {Function File} {[@var{p}, @var{s}] =} wpolyfit (@var{x}, @var{y}, @var{dy}, @var{n}, 'origin')
## Return the coefficients of a polynomial @var{p}(@var{x}) of degree
## @var{n} that minimizes
## @iftex
## @tex
## $$
## \sum_{i=1}^N (p(x_i) - y_i)^2
## $$
## @end tex
## @end iftex
## @ifinfo
## @code{sumsq (p(x(i)) - y(i))},
## @end ifinfo
## to best fit the data in the least squares sense.  The standard error
## on the observations @var{y} if present are given in @var{dy}.
##
## The returned value @var{p} contains the polynomial coefficients 
## suitable for use in the function polyval.  The structure @var{s} returns
## information necessary to compute uncertainty in the model.
##
## If no output arguments are requested, then wpolyfit plots the data,
## the fitted line and polynomials defining the standard error range.
##
## If 'origin' is specified, then the fitted polynomial will go through
## the origin.  This is generally ill-advised.  Use with caution.
##
## To compute the predicted values of y with uncertainty use
## @example
## [y,dy] = polyconf(p,x,s,'ci');
## @end example
## You can see the effects of different confidence intervals and
## prediction intervals by calling the wpolyfit internal plot
## function with your fit:
## @example
## feval('wpolyfit:plt',x,y,dy,p,s,0.05,'pi')
## @end example
## Use @var{dy}=[] if uncertainty is unknown.
##
## You can estimate the uncertainty in the polynomial coefficients 
## themselves using
## @example
## dp = sqrt(sumsq(inv(s.R'))'/s.df)*s.normr;
## @end example
## but the high degree of covariance amongst them makes this a questionable
## operation.
##
## Example
## @example
## x = linspace(0,4,20);
## dy = (1+rand(size(x)))/2;
## y = polyval([2,3,1],x) + dy.*randn(size(x));
## wpolyfit(x,y,dy,2);
## @end example
##
## Hocking, RR (2003). Methods and Applications of Linear Models.
## New Jersey: John Wiley and Sons, Inc.
##
## @end deftypefn
##
## @seealso{polyfit,polyconf}

## This program is in the public domain.
## Author: Paul Kienzle <pkienzle@users.sf.net>

function [p_out, s] = wpolyfit (varargin)

  ## strip 'origin' of the end
  args = length(varargin);
  if args>0 && ischar(varargin{args})
    origin = varargin{args};
    args--;
  else
    origin='';
  endif
  ## strip polynomial order off the end
  if args>0
    n = varargin{args};
    args--;
  else
    n = [];
  end
  ## interpret the remainder as x,y or x,y,dy or [x,y] or [x,y,dy]
  if args == 3
    x = varargin{1};
    y = varargin{2};
    dy = varargin{3};
  elseif args == 2
    x = varargin{1};
    y = varargin{2};
    dy = [];
  elseif args == 1
    A = varargin{1};
    [nr,nc]=size(A);
    if all(nc!=[2,3])
      error("wpolyfit expects vectors x,y,dy or matrix [x,y,dy]");
    endif
    dy = [];
    if nc == 3, dy = A(:,3); endif
    y = A(:,2);
    x = A(:,1);
  else
    usage ("wpolyfit (x, y [, dy], n [, 'origin'])");
  end

  if (length(origin) == 0)
    through_origin = 0;
  elseif strcmp(origin,'origin')
    through_origin = 1;
  else
    error ("wpolyfit: expected 'origin' but found '%s'", origin)
  endif

  if any(size (x) != size (y))
    error ("wpolyfit: x and y must be vectors of the same size");
  endif
  if length(dy)>1 && length(y) != length(dy)
    error ("wpolyfit: dy must be a vector the same length as y");
  endif

  if (! (isscalar (n) && n >= 0 && ! isinf (n) && n == round (n)))
    error ("wpolyfit: n must be a nonnegative integer");
  endif

  k = length (x);

  ## observation matrix
  if through_origin
    ## polynomial through the origin y = ax + bx^2 + cx^3 + ...
    A = (x(:) * ones(1,n)) .^ (ones(k,1) * (n:-1:1));
  else
    ## polynomial least squares y = a + bx + cx^2 + dx^3 + ...
    A = (x(:) * ones (1, n+1)) .^ (ones (k, 1) * (n:-1:0));
  endif

  [p,s] = wsolve(A,y(:),dy(:));

  if through_origin
    p(n+1) = 0;
  endif

  if nargout == 0
    good_fit = 1-chisquare_cdf(s.normr^2,s.df);
    printf("Polynomial: %s  [ p(good)=%.2f%% ]\n", polyout(p,'x'), good_fit*100);
    plt(x,y,dy,p,s,'ci');
  else
    p_out = p;
  endif
end

function plt(x,y,dy,p,s,varargin)

  if iscomplex(p)
    # XXX FIXME XXX how to plot complex valued functions?
    # Maybe using hue for phase and saturation for magnitude
    # e.g., Frank Farris (Santa Cruz University) has this:
    # http://www.maa.org/pubs/amm_complements/complex.html
    # Could also look at the book
    #   Visual Complex Analysis by Tristan Needham, Oxford Univ. Press
    # but for now we punt
    return
  end

  ## decorate the graph
  grid('on');
  xlabel('abscissa X'); ylabel('data Y');
  title('Least-squares Polynomial Fit with Error Bounds');

  ## draw fit with estimated error bounds
  xf = linspace(min(x),max(x),150)';
  [yf,dyf] = polyconf(p,xf,s,varargin{:});
  plot(xf,yf+dyf,"g.;;", xf,yf-dyf,"g.;;", xf,yf,"g-;fit;");

  ## plot the data
  hold on;
  if (isempty(dy))
    plot(x,y,"x;data;");
  else
    if isscalar(dy), dy = ones(size(y))*dy; end
    errorbar (x, y, dy, "~;data;");
  endif
  hold off;

  if strcmp(deblank(input('See residuals? [y,n] ','s')),'y')
    clf;
    if (isempty(dy))
      plot(x,y-polyval(p,x),"x;data;");
    else
      errorbar(x,y-polyval(p,x),dy, '~;data;');
    endif
    hold on;
    grid on;
    ylabel('Residuals');
    xlabel('abscissa X'); 
    plot(xf,dyf,'g.;;',xf,-dyf,'g.;;');
    hold off;
  endif
end

%!demo % #1  
%!     x = linspace(0,4,20);
%!     dy = (1+rand(size(x)))/2;
%!     y = polyval([2,3,1],x) + dy.*randn(size(x));
%!     wpolyfit(x,y,dy,2);
  
%!demo % #2
%!     x = linspace(-i,+2i,20);
%!     noise = ( randn(size(x)) + i*randn(size(x)) )/10;
%!     P = [2-i,3,1+i];
%!     y = polyval(P,x) + noise;
%!     wpolyfit(x,y,2)


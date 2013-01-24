## [y,dy] = confidence(A,p,s)
##
##   Produce prediction intervals for the fitted y. The vector p
##   and structure s are returned from wsolve. The matrix A is
##   the set of observation values at which to evaluate the
##   confidence interval.
##
## confidence(...,['ci'|'pi'])
##
##   Produce a confidence interval (range of likely values for the
##   mean at x) or a prediction interval (range of likely values 
##   seen when measuring at x).  The prediction interval tells
##   you the width of the distribution at x.  This should be the same
##   regardless of the number of measurements you have for the value
##   at x.  The confidence interval tells you how well you know the
##   mean at x.  It should get smaller as you increase the number of
##   measurements.  Error bars in the physical sciences usually show 
##   a 1-alpha confidence value of erfc(1/sqrt(2)), representing
##   one standandard deviation of uncertainty in the mean.
##
## confidence(...,1-alpha)
##
##   Control the width of the interval. If asking for the prediction
##   interval 'pi', the default is .05 for the 95% prediction interval.
##   If asking for the confidence interval 'ci', the default is 
##   erfc(1/sqrt(2)) for a one standard deviation confidence interval.
##
## Confidence intervals for linear system are given by:
##    x' p +/- sqrt( Finv(1-a,1,df) var(x' p) )
## where for confidence intervals,
##    var(x' p) = sigma^2 (x' inv(A'A) x)
## and for prediction intervals,
##    var(x' p) = sigma^2 (1 + x' inv(A'A) x)
##
## Rather than A'A we have R from the QR decomposition of A, but
## R'R equals A'A.  Note that R is not upper triangular since we
## have already multiplied it by the permutation matrix, but it
## is invertible.  Rather than forming the product R'R which is
## ill-conditioned, we can rewrite x' inv(A'A) x as the equivalent
##    x' inv(R) inv(R') x = t t', for t = x' inv(R)
## Since x is a vector, t t' is the inner product sumsq(t).
## Note that LAPACK allows us to do this simultaneously for many
## different x using sqrt(sumsq(X/R,2)), with each x on a different row.
##
## Note: sqrt(F(1-a;1,df)) = T(1-a/2;df)
##
## For non-linear systems, use x = dy/dp and ignore the y output.
function [y,dy] = confidence(A,p,s,alpha,typestr)
  if nargin < 3, s = []; end
  if nargin < 4, alpha = []; end
  if nargin < 5, typestr = 'ci'; end
  y = A*p(:);
  switch typestr, 
    case 'ci', pred = 0; default_alpha=erfc(1/sqrt(2));
    case 'pi', pred = 1; default_alpha=0.05;
    otherwise, error("use 'ci' or 'pi' for interval type");
  end
  if isempty(alpha), alpha = default_alpha; end
  n = tinv(1-alpha/2,s.df)*s.normr/sqrt(s.df); 
  dy = n*sqrt(pred+sumsq(A/s.R,2));
end
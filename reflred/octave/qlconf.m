function [y,dy] = qlconf(x,p,z,s)
  x = x(:);
  A = ones(length(x),3);
  A(:,1) = x.^2 - (x>z).*(x-z).^2;
  A(:,2) = x;
  [y,dy] = confidence(A,p,s);

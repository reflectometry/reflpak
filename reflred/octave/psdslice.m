## Return nearest values in the psd z,dz given
## a spacing of Qz in the rows, a slope of
## m Qz/bin and an intercept at bin b.  This
## does not do linear interpolation.
##
## Test by:
##    Qz=[0.1,0.2,0.3];
##    z=reshape(1:12,3,4);
##    dz = ones(size(z));
##    [x,y,dy] = psdslice(Qz,z,dz,
function [x, Qzv, y, dy] = psdslice(Qz,z,dz,skew,qzcross,bincross)

  ## Find Qz values for slice
  if (isinf(skew)) x=y=dy=[]; return; endif
  x = [1:columns(z)];
  Qzv = (x-bincross)*skew + qzcross;
  
  ## Find rowest corresponding the Qz values
  n = length(Qz);
  Qz = Qz(:);
  if n > 1
    Qzidx = lookup([(3*Qz(1) - Qz(2))/2;
		    (Qz(1:n-1)+Qz(2:n))/2;
		    (3*Qz(n) - Qz(n-1))/2], Qzv);
  elseif (Qz == 0)
    Qzidx = lookup([0,1,1+eps],Qzv);
  else
    Qzidx = lookup([Qz/2, 3*Qz/2, 3*Qz/2*(1+eps)], Qzv);
  endif

  ## Return the valid values
  in = (Qzidx > 0 & Qzidx <= n);
  x = x(in);
  Qzv = Qzv(in);
  zidx = (x-1)*n+Qzidx(in);
  do_fortran_indexing = 1;
  y = z(zidx);
  dy = dz(zidx);

endfunction

function foot = footprint_gen(refl,p,dp,Qmin,Qmax)
  if isempty(refl)
    foot = [];
  elseif isfield(refl,'A')
  refl
    foot.A = footprint_gen(refl.A,p,dp,Qmin,Qmax)
    foot.B = footprint_gen(refl.B,p,dp,Qmin,Qmax)
    foot.C = footprint_gen(refl.C,p,dp,Qmin,Qmax)
    foot.D = footprint_gen(refl.D,p,dp,Qmin,Qmax)
  else
    ## order min and max correctly
    t = abs([Qmin,Qmax]);
    Qmin = min(t); Qmax = max(t);

    ## linear between Qmin and Qmax
    foot.x = refl.x;
    foot.y = polyval(p,abs(refl.x));
    foot.dy = sqrt(polyval(dp.^2,refl.x.^2));
    fpQmax = polyval(p,Qmax);
    dfpQmax = sqrt(polyval(dp.^2,Qmax.^2));

    ## ignore values below Qmin
    foot.y(abs(refl.x) < Qmin) = 1;
    foot.dy(abs(refl.x) < Qmin) = 0;
    ## stretch Qmax to the end of the range
    foot.y(abs(refl.x) > Qmax) = fpQmax;
    foot.dy(abs(refl.x) > Qmax) = dfpQmax;
  end

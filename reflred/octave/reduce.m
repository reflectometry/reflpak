function [sub,div,cor] = reduce(spec,back,slit,FRratio,dopolcor)
  sub=div=cor=[];

  ## Find subtracted data
  if isempty(spec) && isempty(back)
    sub = [];
  elseif isempty(spec)
    sub = back;
  elseif isempty(back)
    sub = spec;
  else
    sub = run_sub(spec,run_interp(back,spec));
  endif

  ## Calculate polarization correction
  if !isempty(slit) && slit.polarized
    fit = fitslits(slit);
    if !isempty(fit)
      cor = polfit(fit,FRratio);
      cor.raw = polraw(fit,FRratio);
      cor.z = fit.A.z;
    end
  else
    fit = [];
  end

  if isempty(slit)
    ## No slit scan, just return subtracted
    div = sub;
  elseif isempty(sub)
    ## No subtracted, just return slit scan
    div = slit;
  elseif !isfield(slit,'A')
    ## Slit is not polarized, so simple division
    if !isfield(sub,'A')
      [div,slit] = slitdivide(sub,slit);
    else !isfield(sub,'A')
      [div.A,slit] = slitdivide(sub.A,slit);
      div.B = slitdivide(sub.B,slit);
      div.C = slitdivide(sub.C,slit);
      div.D = slitdivide(sub.D,slit);
    end
  elseif isempty(fit) || !dopolcor
    ## Polarized, but not doing polarization correction
    div.A = slitdivide(sub.A,slit.A);
    div.B = slitdivide(sub.B,slit.B);
    div.C = slitdivide(sub.C,slit.C);
    div.D = slitdivide(sub.D,slit.D);
    div.polarized = 1;
  else
    ## Polarization correction
    div = polcor(fit, FRratio,sub);
  endif

end


function [div,slit] = slitdivide(sub,slit)

  if isempty(sub)
    ## no subtracted data, so no divided data
    div = [];

  elseif isempty(slit)
    ## no slits so assume 1.
    div = sub;

  elseif !isfield(sub,'m')
    ## No slit info in subtracted data, so assume fixed slits at the
    ## beginning and matching slits for all remaining points.  This
    ## fails if there are fixed slits at the end of the data or if
    ## the slits are not taken at every point as the data in the varying
    ## region.
    send('message "no slit 1 info in specular --- using dumb heuristic for slits"');
    slit.y = prepad(slit.y,length(slit.x),slit.y(1));
    slit.dy = prepad(slit.dy,length(slit.x),slit.dy(1));
    slit.x = sub.x;
    slit = run_interp(slit,sub);
    div = run_div(sub,slit);
    
  elseif length(slit.x) > 1
    ## Normal slit scan --- divide the data

    ## interpolate over slit scan region
    [y,dy]=interp1err(slit.x,slit.y,slit.dy,sub.m);
    
    ## extrapolate with a constant
    y(sub.m<slit.x(1)) = slit.y(1);
    dy(sub.m<slit.x(1)) = slit.dy(1);
    y(sub.m>slit.x(length(slit.x))) = slit.y(length(slit.x));
    dy(sub.m>slit.x(length(slit.x))) = slit.dy(length(slit.x));
    ## replace the (s,y,dy) with interpolated (q,y,dy)
    slit.x = sub.x;
    slit.y = y;
    slit.dy = dy;
    #slit = run_interp(slit,sub);
    ## XXX FIXME XXX put in qlfit code here.
    div = run_div(sub,slit);

  elseif all(abs(slit.x-sub.m) < 100*eps*slit.x)
    ## Fixed slits and single point slit scan
    slit.y = slit.y*ones(size(sub.m));
    slit.dy = slit.dy*ones(size(sub.m));
    slit.x = sub.x;
    #slit = run_interp(slit,sub);
    div = run_div(sub,slit);

  else
    ## XXX FIXME XXX this needs to be reduce_message
    send('message "slit scan slit does not match specular slit"')
    div = [];

  endif
  
end

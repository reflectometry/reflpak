function [sub,div,cor] = reduce(spec,back,slit,FRratio)
  sub=div=cor = [];
  if isempty(spec) && isempty(back)
    sub = [];
    div = slit;
    if !isempty(slit) && isfield(slit,'A')
      fit = fitslits(slit);
      if isempty(fit)
	cor = [];
      else
        cor = polfit(fit,FRratio);
        cor.raw = polraw(fit,FRratio);
        cor.z = fit.A.z;
      end
    end
    return
  end

  if isempty(spec)
    sub = back;
  elseif isempty(back)
    sub = spec;
  else
    sub = run_sub(spec,run_interp(back,spec));
  endif
  
  if isempty(slit)
    div = sub;
  else
    if isfield(slit,'A')
      fit = fitslits(slit);
      if isempty(fit)
	cor = [];
	div = sub;
      else
	cor = polfit(fit,FRratio);
	cor.raw = polraw(fit,FRratio);
	cor.z = fit.A.z;
	div = polcor(fit,FRratio,sub);
      end
    elseif isfield(sub,'m')
      if length(slit.x) > 1
	## interpolate over slit scan region
        [y,dy]=interp1err(slit.x,slit.y,slit.dy,sub.m);
	
	## extrapolate with a constant
        y(spec.m<slit.x(1)) = slit.y(1);
        dy(spec.m<slit.x(1)) = slit.dy(1);
        y(spec.m>slit.x(length(slit.x))) = slit.y(length(slit.x));
        dy(spec.m>slit.x(length(slit.x))) = slit.dy(length(slit.x));
	## replace the (s,y,dy) with interpolated (q,y,dy)
        slit.x = sub.x;
        slit.y = y;
        slit.dy = dy;
	slit = run_interp(slit,sub);
	## XXX FIXME XXX put in qlfit code here.
        div = run_div(sub,slit);
	cor.x = slit.x(:); cor.beta = slit.y(:);
      elseif all(abs(slit.x-sub.m) < 100*eps)
	## XXX FIXME XXX condition depends on slit.x less than 100
	## Single point slit scan
	slit.y = slit.y*ones(size(spec.m));
	slit.dy = slit.dy*ones(size(spec.m));
	slit.x = spec.x;
	slit = run_interp(slit,sub);
        div = run_div(sub,slit);
	cor.x = slit.x(:); cor.beta = slit.y(:);
      else
	## XXX FIXME XXX this needs to be reduce_message
	send('message "slit scan slit does not match specular slit"')
	slit = [];
      endif
    else
      ## XXX FIXME XXX XXX FIXME XXX XXX FIXME XXX
      ## this slitscan reduction will not work in general!!!
      send('message "no slit 1 info in specular --- using dumb heuristic for slits"');
      slit.y = prepad(slit.y,length(slit.x),slit.y(1));
      slit.dy = prepad(slit.dy,length(slit.x),slit.dy(1));
      slit.x = sub.x;
      slit = run_interp(slit,sub);
      div = run_div(sub,slit);
      cor = [slit.x(:), slit.y(:)];
    endif
  endif

function ret=load_gfit(file)
  x=load(file);
  r.step=x(:,1);
  r.center=x(:,2);
  r.height=x(:,3);
  r.width=x(:,4);
  r.area=x(:,5);
  r.chisq=x(:,6);
  r.i = r.chisq<max(r.chisq)/20;

  r.istep=r.step(r.i);
  r.icenter=r.center(r.i);
  r.iheight=r.height(r.i);
  r.iwidth=r.width(r.i);

  figure(1);
  title(file);
  gset lmargin 10;
  subplot(211);
  plot(r.istep,r.iwidth,'-+;width;');
  subplot(212);
  title("");
  plot(r.istep,r.iheight,'-+;height;');

  figure(2);
  subplot(211);
  title(file);
  r.p=wpolyfit(r.icenter,r.istep,1);
  plot(r.icenter,r.istep-polyval(r.p,r.icenter),';residuals;');
  subplot(212);
  title("");
  plot(r.step,r.area,';integrated area;');

  if nargout > 0, ret = r; end
end

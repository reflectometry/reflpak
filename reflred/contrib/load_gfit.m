function ret=load_gfit(file)
  automatic_replot = 0;
  x=load(file);
  r.step=x(:,1);
  r.center=x(:,2);
  r.height=x(:,3);
  r.width=x(:,4);
  r.area=x(:,5);
  r.chisq=x(:,6);

  figure(1);
  title(file);
  __gnuplot_set__ lmargin 10;
  subplot(211);
  plot(r.step,r.width,'-+;width;');
  subplot(212);
  title("");
  plot(r.step,r.height,'-+;height;');

  figure(2);
  subplot(211);
  title(file);
  r.p=wpolyfit(r.center,r.step,1);
  plot(r.step,r.step-polyval(r.p,r.center),';center offset;');
  subplot(212);
  title("");
  plot(r.step,r.area,';integrated area;');

  if nargout > 0, ret = r; end
end

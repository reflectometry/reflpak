function plotrunop(run, run1, run2)

  if nargin == 3

    graw("reset\n");

    global __multiplot_mode__;
    __multiplot_mode__ = 1;
    gset multiplot;
    gset origin 0, 0
    gset size 1, 1
    graw("clear\n");
    gset origin 0, 0.5;
    gset size 0.5, 0.4;
    axis;
    xlabel(run1.xlabel);
    ylabel(run1.ylabel);
    title(run1.title);
    errorbar(run1.x,run1.y,run1.dy,'~b;;');

    gset origin 0.5, 0.5;
    gset size 0.5, 0.4;
    axis;
    xlabel(run2.xlabel);
    ylabel(run2.ylabel);
    title(run2.title);
    errorbar(run2.x,run2.y,run2.dy,'~r;;');

    gset origin 0, 0;
    gset size 1.0, 0.4;

  elseif nargin == 2
    subplot(211);
    xlabel(run1.xlabel);
    ylabel(run1.ylabel);
    title(run1.title);
    subplot(212);

  elseif nargin == 1
    oneplot;

  else
    usage("plotrunop(run [, run1 [, run2]])");
  endif

  axis;
  xlabel(run.xlabel);
  ylabel(run.ylabel);
##  title(caar(run.log));
  errorbar(run.x, run.y, run.dy, '~g;;');

endfunction

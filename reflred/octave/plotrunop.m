## plotrunop(result,in1,in2)
## Plot input values and results for a run operation.  Supports unary
## operations if only one input value is provided in addition to the
## result.
function plotrunop(run, run1, run2)

  axis;
  if nargin == 3

    subplot(221);
    xlabel(run1.xlabel);
    ylabel(run1.ylabel);
    title(run1.title);
    errorbar(run1.x,run1.y,run1.dy,'~b;;');

    subplot(222);
    xlabel(run2.xlabel);
    ylabel(run2.ylabel);
    title(run2.title);
    errorbar(run2.x,run2.y,run2.dy,'~r;;');

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

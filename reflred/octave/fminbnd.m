## Copyright (C) 2000 Ben Sapp.  All rights reserved.
## Modification by Andreas Helms
## This program is free software; you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by the
## Free Software Foundation; either version 2, or (at your option) any
## later version.
##
## This is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
## for more details.

## -*- texinfo -*-
## @deftypefn {Function File} {[@var{x}] =} fminbnd(@var{f},@var{lb},@var{ub},@var{[options]},@var{P1},@var{P2}, ...)
## 
## Find the minimum of a scalar function with the Golden Search method.
## 
## @strong{Inputs}
## @table @var 
## @item f 
## A string contining the name of the function to minimiz
## @item lb
## Value to use as an initial lower bound on @var{x}.
## @item ub 
## Value to use as an initial upper bound on @var{x}.
## @item options
## Vector with control parameters (For compatibily with MATLAB, not used 
## here) 
## @item P1,P2, ...
## Optional parameter for function @var{f} 
##
## @end table
## @end deftypefn

## 2001-09-24 Andreas Helms <helms@astro.physik.uni-potsdam.de>
## * modified for use with functions of more than one parameter

function min = fminbnd(_func,lb,ub, options, varargin)

  delta = 1e-17;
  gr = (sqrt(5)-1)/2;
  width = (ub-lb);
  out = [ lb:(width/3):ub ];
  out(2) = out(4)-gr*width;
  out(3) = out(1)+gr*width;
  upper = feval(_func,out(3), varargin{:});
  lower = feval(_func,out(2), varargin{:});
  while((out(3)-out(2)) > delta) #this will not work for symmetric funcs
    if(upper > lower)
      out(4) = out(3);
      out(3) = out(2);
      width = out(4)-out(1);
      out(2) = out(4)-gr*width;
      upper = lower;
      lower = feval(_func,out(2), varargin{:});
    else
      out(1) = out(2);
      out(2) = out(3);
      width = out(4)-out(1);
      out(3) = out(1)+width*gr;
      lower = upper;
      upper = feval(_func,out(3), varargin{:});
    endif
  endwhile
  min = out(2);
endfunction

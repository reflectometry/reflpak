## runlog(run)
##   Display the runlog for the given run.
## run = runlog(run, message [, run2])
##   Add the message to the end of the current run log.  If a second run 
##   is given, its log will be associated with the message. E.g.,
##   run = runlog(run, "adding", run2) will log the fact that run2 is
##   being added to run.
## These functions operate on an existing log field in the run structure.
## If no log field exists, then no messages will be logged.  Set run.log=list()
## to initiate logging or rmfield(run,"log") to terminate it.
function run = runlog(run, message, run2)

  if nargin == 3
    if struct_contains(run,"log")
      if struct_contains(run2,"log")
	l = list(message, run2.log);
      else
	l = list(message, list("x=", run2.x, "y=", run2.y, "dy=", run2.dy));
      endif
      run.log(length(run.log)+1) = l;
    endif
  elseif nargin == 2
    if struct_contains(run,"log")
      run.log(length(run.log)+1) = list(message);
    endif
  elseif nargin == 1
    if struct_contains(run,"log")
      run.log
    else
      disp("no log available")
    endif
  else
    usage("run = runlog(run, message [, run2]) OR runlog(run)")
  endif

endfunction

function run_send(name, val)
  if isempty(val)
    send(sprintf(name,'x'),[]);
    send(sprintf(name,'y'),[]);
    send(sprintf(name,'dy'),[]);
    send(['run_send clear ',sprintf(name,'')]);
  elseif !isempty(val.polarization)
    run_send(sprintf(name,'A%s'),val.A);
    run_send(sprintf(name,'B%s'),val.B);
    run_send(sprintf(name,'C%s'),val.C);
    run_send(sprintf(name,'D%s'),val.D);
  else
    send(sprintf(name,'x'),val.x);
    send(sprintf(name,'y'),val.y);
    send(sprintf(name,'dy'),val.dy);
    if struct_contains(val,'m')
      send(sprintf(name,'m'),val.m); 
    endif
    send(['run_send set ',sprintf(name,'')]);
  endif
endfunction

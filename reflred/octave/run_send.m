function run_send(name,val)
  if isempty(val)
    send(sprintf(name,'x'),[]);
    send(sprintf(name,'y'),[]);
    send(sprintf(name,'dy'),[]);
    send(sprintf(name,'m'),[]);
    send(['run_send clear ',sprintf(name,'')]);
  else
    send(sprintf(name,'x'),val.x);
    send(sprintf(name,'y'),val.y);
    send(sprintf(name,'dy'),val.dy);
    if struct_contains(val,'m')
      send(sprintf(name,'m'),val.m); 
    else
      send(sprintf(name,'m'),[]);
    endif
    send(['run_send set ',sprintf(name,'')]);
  endif
end

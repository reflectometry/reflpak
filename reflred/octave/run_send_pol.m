function run_send_pol(name, val)
  plain = A = B = C = D = [];
  if !isempty(val)
    if isfield(val,'A')
      A = val.A; B=val.B; C=val.C; D=val.D;
      plain = [];
    else
      A = B = C = D = [];
      plain = val;
    end
  end

  run_send(name,plain);
  run_send(sprintf(name,'%sA'), A);
  run_send(sprintf(name,'%sB'), B);
  run_send(sprintf(name,'%sC'), C);
  run_send(sprintf(name,'%sD'), D);
endfunction

function foot = footprint_interp(div,fd)
  ## interpolated footprint curve
  if isfield(div,'A')
    foot.x = div.A.x;
  else
    foot.x = div.x;
  end
  [foot.y, foot.dy] = interp1err(fd.x,fd.y,fd.dy,foot.x);
  foot.y(isnan(foot.y)) = 1.0;
  foot.dy(isnan(foot.dy)) = 0.0;
  ## [fpQmax,dfpQmax] = interp1err(fd.x,fd.y,fd.dy,Qmax);
end
function foot = footprint_interp(div,fd)
  ## interpolated footprint curve
  foot = div;
  [foot.y, foot.dy] = interp1err(fd.x,fd.y,fd.dy,div.x);
  foot.y(isnan(foot.y)) = 1.0;
  foot.dy(isnan(foot.dy)) = 0.0;
  ## [fpQmax,dfpQmax] = interp1err(fd.x,fd.y,fd.dy,Qmax);

function [p,dp] = footprint_fit(run,lo,hi,kind)
run
  if isempty(run)
    p=[0;1]; dp=[0;0];
  elseif struct_contains(run,'A')
    [p,dp] = footprint_fit(run.A,lo,hi,kind);
  else
    if lo>hi, t=hi; hi=lo; lo=t; end
    idx = find(run.x >= lo & run.x <= hi);
    if length(idx) < 2,
      p=[0;1]; dp=[0;0];
    else switch kind,
      case 'plateau',
        [p,s] = wpolyfit(abs(run.x(idx)),run.y(idx),run.dy(idx),0);
        dp = sqrt(sumsq(inv(s.R'))'/s.df)*s.normr;
        p = [0;p(:)]; dp = [0;dp(:)];
      case 'slope',
        [p,s] = wpolyfit(abs(run.x(idx)),run.y(idx),run.dy(idx),1,'origin');
        dp = sqrt(sumsq(inv(s.R'))'/s.df)*s.normr;
        dp = [dp(:);0];
      case 'line',
        [p,s] = wpolyfit(abs(run.x(idx)),run.y(idx),run.dy(idx),1);
        dp = sqrt(sumsq(inv(s.R'))'/s.df)*s.normr;
        p = p(:); dp = dp(:);
      otherwise error('unknown footprint type "%s"',kind);
    end; end
  end

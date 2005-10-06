% [A,B,C,D] = polcor(fit,FRratio,sub)
%   A,B,C,D are the background subtracted specular cross-sections.
%   slits is a piecewise linear function mapping q values to slit values
%   FRratio is the front/back polarizer efficiency ratio (default is 0.5).
%
% Cross sections are three column data: value counts uncertainty.
function data = polcor(fit,FRratio,sub)
  do_plot = nargout == 0;

  %# determine which slits we are using
  if nargin < 3 || nargin > 7
    usage('cor = polcor(slitfit,FRratio,sub)')
  end

  if isempty(fit), data = sub; return; end

  [q,idxA,idxD] = common_values(sub.A.x,sub.D.x,1e-5);
  s = interp1(sub.A.x,sub.A.m,q);
  if fit.lo == fit.hi, % XXX FIXME XXX need better handling of low n
    I = ones(length(s),1);
    Ia = fit.Ia.y*I; dIa = fit.Ia.dy*I;
    Ib = fit.Ib.y*I; dIb = fit.Ib.dy*I;
    Ic = fit.Ic.y*I; dIc = fit.Ic.dy*I;
    Id = fit.Id.y*I; dId = fit.Id.dy*I;
  elseif nargin < 4, % use fit
    [Ia,dIa] = qlconf(s,fit.A.p,fit.A.z,fit.A.S);
    [Ib,dIb] = qlconf(s,fit.B.p,fit.B.z,fit.B.S);
    [Ic,dIc] = qlconf(s,fit.C.p,fit.C.z,fit.C.S);
    [Id,dId] = qlconf(s,fit.D.p,fit.D.z,fit.D.S);
  else % use raw
    q = interp1(sub.A.m,sub.A.x,fit.Ia.x);
    s = fit.Ia.x;
    Ia = fit.Ia.y; dIa = fit.Ia.dy;
    [Ib,dIb] = interp1err(fit.Ib.x, fit.Ib.y, fit.Ib.dy, s);
    [Ic,dIc] = interp1err(fit.Ic.x, fit.Ic.y, fit.Ic.dy, s);
    [Id,dIc] = interp1err(fit.Id.x, fit.Id.y, fit.Id.dy, s);
  endif

  [beta, F, R, x, y, reject] = polcorpar(FRratio,Ia,Ib,Ic,Id,1);

  if do_plot
    automatic_replot = 0;
    oneplot();
    hold off; clg
    subplot(211);
    semilogy(s,beta,'-;Io C;');
    hold on;
    semilogyerr(fit.Ia.x,fit.Ia.y,fit.Ia.dy,'g;;');
    semilogyerr(fit.Ib.x,fit.Ib.y,fit.Ib.dy,'b;;');
    semilogyerr(fit.Ic.x,fit.Ic.y,fit.Ic.dy,'m;;');
    semilogyerr(fit.Id.x,fit.Id.y,fit.Id.dy,'r;;');
    hold off;
    subplot(212);
    plot(s,F,'r-;F;',s,R,'g-;R;',s,(1-x)/2,'b-;f;',s,(1-y)/2,'m-;r;');
  endif

  if 0 && (isempty(sub.B) || isempty(sub.C))
    ## XXX FIXME XXX  What if we don't have all four cross-sections?
    warning('B and/or C missing from polarization correction');
    rbeta.x = q;
    rbeta.y = 2*beta;
    rbeta.dy = zeros(size(beta));
    A = run_div(sub.A, run_interp(rbeta,sub.A));
    D = run_div(sub.D, run_interp(rbeta,sub.D));
    if isempty(sub.B), B = [];
    else B = run_div(sub.B, run_interp(rbeta,sub.B));
    end
    if isempty(sub.C), C = [];
    else C = run_div(sub.C, run_interp(rbeta,sub.C));
    end
    data = struct('A',A,'B',B,'C',C,'D',D);
    return
  end

  %# Construct a set of matrices for 
  %# each row of H is a matrix to solve
  Fx = F.*x;
  Ry = R.*y;
  H = [(1+F).*(1+R), (1+Fx).*(1+R), (1+F).*(1+Ry), (1+Fx).*(1+Ry), ...
       (1-F).*(1+R), (1-Fx).*(1+R), (1-F).*(1+Ry), (1-Fx).*(1+Ry), ...
       (1+F).*(1-R), (1+Fx).*(1-R), (1+F).*(1-Ry), (1+Fx).*(1-Ry), ...
       (1-F).*(1-R), (1-Fx).*(1-R), (1-F).*(1-Ry), (1-Fx).*(1-Ry) ];
  
  %# find the corresponding
  [A,dA] = interp1err(sub.A.x,sub.A.y,sub.A.dy,q);
  [D,dD] = interp1err(sub.D.x,sub.D.y,sub.D.dy,q);
  if isempty(sub.B) && isempty(sub.C)
    B = C = zeros(size(q));
    dB = dC = ones(size(q));
  elseif isempty(sub.B)
    [C,dC] = interp1err(sub.C.x,sub.C.y,sub.C.dy,q);
    B = C; dB = dC;
  elseif isempty(sub.C)
    [B,dB] = interp1err(sub.B.x,sub.B.y,sub.B.dy,q);
    C = B; dC = dB;
  else
    [B,dB] = interp1err(sub.B.x,sub.B.y,sub.B.dy,q);
    [C,dC] = interp1err(sub.C.x,sub.C.y,sub.C.dy,q);
  endif

  %# each column of Y is a 
  Y = [ A./beta,B./beta,C./beta,D./beta ];
  dY = [ dA./beta,dB./beta,dC./beta,dD./beta ];

  %# XXX FIXME XXX  John's code has an extra factor of four here, 
  %# which roughly corresponds to the elements of sqrt(diag(inv(Y'Y))), 
  %# the latter giving values in the order of 3.9 for one example 
  %# dataset.  Is there an analytic reason it should be four?

  X = zeros(size(Y));
  dX = zeros(size(dY));
%cnd = zeros(size(q));
%cov = zeros(4);
  p = zeros(4,1);
  for i=1:length(q)
    %# Extract the next equation
    A = reshape(H(i,:),4,4);
    y = Y(i,:)';
    dy = dY(i,:)';
    [p,s] = wsolve(A,y,dy);
%send(sprintf('puts "A=%s\ny=%s\ndy=%s\np=%s\n"',
%     num2str(A(:)'),num2str(y'),num2str(dy'),num2str(p')));
%cnd(i) = cond(A./(dy * ones (1, 4)));
%cov += inv(s.R'*s.R);
    X(i,:) = p';
    dX(i,:) = sqrt(sumsq(inv(s.R')));
%[dy./dX(i,:)']
  end
%cov /= length(q),X
%if do_plot
%input("condition numbers");
%oneplot; clg; plot(q,cnd);
%end
  r.A.x = q; r.A.y = X(:,1); r.A.dy = dX(:,1);
  r.B.x = q; r.B.y = X(:,2); r.B.dy = dX(:,2);
  r.C.x = q; r.C.y = X(:,3); r.C.dy = dX(:,3);
  r.D.x = q; r.D.y = X(:,4); r.D.dy = dX(:,4);
  if 0
  A = [q,X(:,1),dX(:,1)];
  B = [q,X(:,2),dX(:,2)];
  C = [q,X(:,3),dX(:,3)];
  D = [q,X(:,4),dX(:,4)];
  if do_plot && strcmp(input("Plot old and new data? ","s"),"y")
    subplot(221); 
    semilogyerr(q,X(:,1),dX(:,1),';out;',a(:,1),a(:,2),a(:,3),';in;');
    subplot(222); 
    semilogyerr(q,X(:,2),dX(:,2),';out;',b(:,1),b(:,2),b(:,3),';in;');
    subplot(223); 
    semilogyerr(q,X(:,3),dX(:,3),';out;',c(:,1),c(:,2),c(:,3),';in;');
    subplot(224); 
    semilogyerr(q,X(:,4),dX(:,4),';out;',d(:,1),d(:,2),d(:,3),';in;');
  end
  if 0 && do_plot && strcmp(input("New data alone? ","s"),"y")
    oneplot; clg;
    subplot(221); 
    errorbar(q,X(:,1),dX(:,1),';out;');
    subplot(222); 
    errorbar(q,X(:,2),dX(:,2),';out;');
    subplot(223); 
    errorbar(q,X(:,3),dX(:,3),';out;');
    subplot(224); 
    errorbar(q,X(:,4),dX(:,4),';out;');
  end
  end

  if isempty(sub.B) && isempty(sub.C) r.B = r.C = []; end
  if nargout, data = r; end
end

function cor = polraw(fit,FRratio)
  if isempty(fit), cor = []; return; end
  if nargin < 2, FRratio = 0.5; end
  s = fit.Ia.x;
  Ia = fit.Ia.y; dIa = fit.Ia.dy;
  if length(s) > 1,
    [Ib,dIb] = interp1err(fit.Ib.x, fit.Ib.y, fit.Ib.dy, s);
    [Ic,dIc] = interp1err(fit.Ic.x, fit.Ic.y, fit.Ic.dy, s);
    [Id,dId] = interp1err(fit.Id.x, fit.Id.y, fit.Id.dy, s);
  else
    Ib = fit.Ib.y; dIb = fit.Ib.dy;
    Ic = fit.Ic.y; dIc = fit.Ic.dy;
    Id = fit.Id.y; dId = fit.Id.dy;
  endif
  [beta, F, R, x, y] = polcorpar(FRratio,Ia,Ib,Ic,Id,0);
  cor.x = s;
  cor.polf = F;
  cor.polr = R;
  cor.flipf = (1-x)/2;
  cor.flipr = (1-y)/2;
  cor.beta = beta;
  cor.slitA = Ia;
  cor.slitB = Ib;
  cor.slitC = Ic;
  cor.slitD = Id;

  if 0,
    [Ia,dIa] = qlconf(s,fit.A.p,fit.A.z,fit.A.S);
    [Ib,dIb] = qlconf(s,fit.B.p,fit.B.z,fit.B.S);
    [Ic,dIc] = qlconf(s,fit.C.p,fit.C.z,fit.C.S);
    [Id,dId] = qlconf(s,fit.D.p,fit.D.z,fit.D.S);
    [beta, F, R, x, y] = polcorpar(FRratio,Ia,Ib,Ic,Id,0);
    automatic_replot = 0;
    subplot(211);
    title('Residuals');
    plot(s,log(cor.slitA)-log(Ia),'-@;A;',s,log(cor.slitB)-log(Ib),'-@;B;',...
	 s,log(cor.slitC)-log(Ic),'-@;C;',s,log(cor.slitD)-log(Id),'-@;D;',...
	 s,log(cor.beta)-log(beta),'-@;beta;');
    subplot(212);
    plot(s,cor.flipf - (1-x)/2,'-@;front flipper;',...
	 s,cor.flipr - (1-y)/2,'-@;back flipper;',...
	 s,cor.polf - F,'-@;front polarizer;',...
	 s,cor.polr - R,'-@;back polarizer;');
  endif
end

function cor = polfit(fit,FRratio)
  if isempty(fit), cor = []; return; end
  if nargin < 2, FRratio = 0.5; end
  if fit.lo == fit.hi,
    s = fit.lo;
  else
    s = linspace(fit.lo,fit.hi,100);
  end
  [Ia,dIa] = qlconf(s,fit.A.p,fit.A.z,fit.A.S);
  [Ib,dIb] = qlconf(s,fit.B.p,fit.B.z,fit.B.S);
  [Ic,dIc] = qlconf(s,fit.C.p,fit.C.z,fit.C.S);
  [Id,dId] = qlconf(s,fit.D.p,fit.D.z,fit.D.S);
  [beta, F, R, x, y] = polcorpar(FRratio,Ia,Ib,Ic,Id,0);
  cor.x = s;
  cor.polf = F;
  cor.polr = R;
  cor.flipf = (1-x)/2;
  cor.flipr = (1-y)/2;
  cor.beta = beta;
  cor.slitA = Ia;
  cor.slitB = Ib;
  cor.slitC = Ic;
  cor.slitD = Id;
end


function [beta,F,R,x,y,reject] = polcorpar(FRratio,Ia,Ib,Ic,Id,clip)
  persistent min_efficiency=0.9;
  persistent min_intensity=1e-10;

  %# Keep track of which values exceed ranges
  reject = [];

  %# Can we meaningfully propagate uncertainties through the
  %# the following?  There are an awful lot covariance effects
  %# we will need to keep track of.  For now, we won't try.
  %# (see KOD code --- he has done the calculations, but without
  %# using FRratio).

  %# Beam intensity normalization. XXX FIXME XXX check if we compute the
  %# beam intensity directly, or instead compute Io C = 2 beta.
  beta = 0.5 * (Ia.*Id - Ib.*Ic ) ./ (Ia + Id - Ib - Ic);
  %num = Ia .* Id - Ib .* Ic;
  %den = 2*(Ia + Id - Ib - Ic);
  %Vnum = (Ia.*dId).^2 + (Id.*dIa).^2 + (Ib.*dIc).^2 + (Ic.*dId).^2;
  %Vden = 4*(dIa.^2 + dIb.^2 + dIc.^2 + dId.^2); 
  %dbeta = sqrt((beta./num).^2 .* Vnum + (beta./den).^2 .* Vden); 
  %# XXX FIXME XXX what if Ib+Ic >= Ia+Id or IbIc > IaId
  [beta, Ireject] = polclip(beta,min_intensity,Inf);

  %# F and R are the front and rear polarizer efficiencies.  Each 
  %# is limited below by min_efficiency and above by 1 (since they 
  %# are not neutron sources).  Keep a list of points that are 
  %# rejected because they are outside this range.
  FRratio = polclip(FRratio,0,1);
  FR = Ia./(2*beta) - 1;
  [FR, FRreject] = polclip(FR,min_efficiency^2,1);
  F = FR.^FRratio;
  R = FR ./ F;

  %# f and r are the front and rear flipper efficiencies.  Each
  %# is again limited below by min_efficiency and above by 1.
  %# We don't compute f and r directly, but instead x, y, Fx and Fy:
  %#    x = 1-2f => 1-2*min_effiency > x > -1
  %#    y = 1-2r => 1-2*min_effiency > y > -1
  x = (Ib./(2*beta) - 1)./FR;
  y = (Ic./(2*beta) - 1)./FR;

  %# For plotting purposes, what would it be without clipping?
  if clip
    [x, xreject] = polclip(x,-1,1-2*min_efficiency);
    [y, yreject] = polclip(y,-1,1-2*min_efficiency);
  else
    xreject = yreject = [];
  end

  %[F,R,x,y,beta]
  if 0
    pa = x .* (Ic-Ia) + (Ib-Id);
    pb = Ic.*(1-FR.*x) - Ia.*(1-FR.*x.*y) + Ib.*(1-FR.*y) - Id.*(1-FR);
    pc = ((Id - Ic) + y.*(Ia-Ib)).*FR;
    F = (-pb+sqrt(pb.^2 - 4*pa.*pc))./(2*pa);
    R = (-pb-sqrt(pb.^2 - 4*pa.*pc))./(2*pa);
    F(F<0) = R(F<0);
  endif
  reject = unique([FRreject(:);Ireject(:);xreject(:);yreject(:)]);
end


function [field,reject] = polclip(field,lo,hi,nanval)
  fieldname = inputname(1);
  nan_idx = find(isnan(field));
  lo_idx = find(field<lo);
  hi_idx = find(field>hi);
  if ~isempty(nan_idx)
    warning('%d points of %s are NaN',length(nan_idx),fieldname);
    if nargin >= 4, field(nan_idx) = 1.; end
  end
  if ~isempty(lo_idx)
    warning('%d points of %s < %g',length(lo_idx),fieldname,lo); 
    field(lo_idx) = lo;
  end
  if ~isempty(hi_idx)
    warning('%d points of %s > %g',length(hi_idx),fieldname,hi); 
    field(hi_idx) = hi;
  end
  reject = [nan_idx(:); lo_idx(:); hi_idx(:)];
end

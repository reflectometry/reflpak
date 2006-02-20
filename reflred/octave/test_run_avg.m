## test_run_avg(Na,Ma,Nb,Mb)
##
## Print the average counts per monitor given Na counts for Ma monitors
## and Nb counts for Mb monitors.  This shows the effects of different 
## algorithms, such as using monitor uncertainty and using Gaussian vs. 
## Poisson error propogation.
##
## Ideally, the average of two measurements should be the value of a single
## measurement with combined counts and monitors.
##
## Try it for realistic values of Na,Ma,Nb,Mb such as:
## * monitor is 10% of counts
##   Na=20400, Ma=2000, Nb=39500, Mb=4000, test_run_avg(Na,Ma,Nb,Mb)
## * counts entering region where Gaussian approximation works
##   Na = 7, Ma=2000, Nb=13, Mb=4000, test_run_avg(Na,Ma,Nb,Mb)
## * counts in Poisson region
##   Na = 3, Ma=2000, Nb=8, Mb=4000, test_run_avg(Na,Ma,Nb,Mb)
##
## Also try counting in lots of little chunks and combining the result
##   N = randp(5,50,1);
##   M = randp(25,50,1);
##   y=N./M; dy=sqrt((1+N./M).*N./M.^2); dy(N==0) = 1./M(N==0);
##   r=y(1); dr=dy(1);
##   for i=2:length(y)
##     w = r/dr^2 + y(i)/dy(i)^2;
##     r = ((r/dr)^2 + (y(i)/dy(i))^2)/w;
##     dr = sqrt(r/w);
##   end
##   Nt=sum(N); Mt=sum(M); t=Nt/Mt; dt=sqrt((1+Nt/Mt)*Nt/Mt^2);
##   [t,dt,r,dr,norm(t-r)/t,norm(dt-dr)/dt]

function test_run_avg(Na,Ma,Nb,Mb)
  ## target value
  rc=(Na+Nb)/(Ma+Mb); 
  drc = sqrt((1+(Na+Nb)/(Ma+Mb))*(Na+Nb)/(Ma+Mb)^2);
  disp("target values (y,dy)");
  disp([rc,drc]);

  disp("use monitor uncertainty (y, dy, y error, dy error)");
  ra=Na/Ma; dra = sqrt((1+Na/Ma)*Na/Ma^2);
  rb=Nb/Mb; drb = sqrt((1+Nb/Mb)*Nb/Mb^2);
  w = ra/dra^2 + rb/drb^2;
  y = ((ra/dra)^2 + (rb/drb)^2)/w; dy = dy = sqrt(y/w);
  disp([y,dy,norm(y-rc)/rc, norm(dy-drc)/drc])
  
  disp("no monitor uncertainty (y, dy, y error, dy error)");
  ra=Na/Ma; dra = sqrt(Na)/Ma;
  rb=Nb/Mb; drb = sqrt(Nb)/Mb;
  w = ra/dra^2 + rb/drb^2;
  y = ((ra/dra)^2 + (rb/drb)^2)/w; dy = dy = sqrt(y/w);
  disp([y,dy,norm(y-rc)/rc, norm(dy-drc)/drc])

  disp("gaussian error prop, use monitor uncertainty (y, dy, y error, dy error)");
  ra=Na/Ma; dra = sqrt((1+Na/Ma)*Na/Ma^2);
  rb=Nb/Mb; drb = sqrt((1+Nb/Mb)*Nb/Mb^2);
  w = 1/dra^2 + 1/drb^2;
  y = (ra/dra^2 + rb/drb^2)/w; dy = dy = sqrt(1/w);
  disp([y,dy,norm(y-rc)/rc, norm(dy-drc)/drc])
  
  disp("gaussian error prop, no monitor uncertainty (y, dy, y error, dy error)");
  ra=Na/Ma; dra = sqrt(Na)/Ma;
  rb=Nb/Mb; drb = sqrt(Nb)/Mb;
  w = 1/dra^2 + 1/drb^2;
  y = (ra/dra^2 + rb/drb^2)/w; dy = dy = sqrt(1/w);
  disp([y,dy,norm(y-rc)/rc, norm(dy-drc)/drc])

 
end

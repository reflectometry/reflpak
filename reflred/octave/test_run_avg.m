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

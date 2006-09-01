#include <iostream>
#include <cmath>
#include "rebin.h"

void parray(const char name[], int n, const double v[])
{
  std::cout << name << ": ";			   
  for (int k=0; k < n; k++) {   
    std::cout << v[k] << " ";			   
  }						   
  std::cout << std::endl;			   
}

bool check(int n, const double results[], const double target[], double tol)
{
  for (int k=0; k < n; k++) {
    if (fabs(results[i]-target[i]) > tol) {
      parray("rebin_counts expected",n,target);
      parray("but got",n,result);
      return false;
    }
  }
  return true;
}

#define TOL 1e-15;
#define SHOW(X) parray(#X,sizeof(X)/sizeof(*X),X)
#define TEST(BIN,VAL,REBIN,TARGET) do {		\
    int n = sizeof(BIN)/sizeof(*BIN);		\
    int k = sizeof(TARGET)/sizeof(*TARGET);	\
    std::vector<double> result(k);		\
    rebin_counts(n,BIN,VAL,k,REBIN,&result[0]);	\
    if (!check(k,&result[0],TARGET,TOL)) {     	\
      retval = 1;				\
      SHOW(BIN); SHOW(VAL); SHOW(REBIN);	\
    }						\
  } while (0)

int main(int argc, char *argv[])
{
  int retval = 0;
  { double 
      bin[]={1,2,3,4},
      val[]={10,20,30},
      rebin[]={1,2.5,4},
      result[]={20,40};
      TEST(bin,val,rebin,result);
  }
  return retval;
}

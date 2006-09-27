#include "progress.h"

void compute(ProgressMeter *meter)
{

  meter->start("ProgressMeter demonstration",-5,34);
  for (int i=-5; i <= 34; i++) {
    if (!meter->step(i)) break;
  }
  meter->stop();
}

int main(int argc, char *argv[])
{
  TextMeter meter;
  compute(&meter);
}

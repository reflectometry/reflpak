/* Averages parameters in GENSUB and GENVAC */

#include <gAverage.h>

double gAverage(double param[], int layer, double rufint)
{
   return  .5 * (
      param[layer] + param[layer - 1]
      + (param[layer] - param[layer - 1]) * rufint
   );
}


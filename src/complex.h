/* Defines complex number type and basic arithmetic */

#ifndef _COMPLEX_H
#define _COMPLEX_H

/* For NULL */
#include <stddef.h>

typedef struct COMPLEX {double real, imag;} complex;

complex makeComplex(double real, double imag);
complex conjComplex(complex number);
complex addComplex(complex a, complex b);
complex subComplex(complex a, complex b);
complex addComplexes(complex *addend, ...);
complex negComplex(complex number);
complex scaleComplex(complex a, double b);
complex mulComplex(complex a, complex b);
double magnComplex(complex number);
double mag2Complex(complex number);
complex divComplex(complex a, complex b);
complex mulComplexes(complex *factor, ...);
complex recpComplex(complex number);
complex sqrtComplex(complex number);
complex expComplex(complex number);

#endif /* _COMPLEX_H */



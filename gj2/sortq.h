/* Subroutine sorts through the Q values of the four cross sections stored */
/* in XDAT and returns an array Q4X containing all of the Q values that need */
/* to be evaluated for all of the cross sections. */
/* John Ankner 4 August 1992 */

#ifndef _SORTQ_H
#define _SORTQ_H

int sortq(double *xdat, int npntsx[4], double *q4x, int *nqx[4]);

#endif /* _SORTQ_H */


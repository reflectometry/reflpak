#ifndef _TRANSPOSE_H
#define _TRANSPOSE_H

/* From Robin Becker <robin@jessikat.fsnet.co.uk>
 * Posted to sci.math.num-analysis on Dec 6 2003, 2:24 pm
 * He does not remember who is the original author.
 */
template <class Real> void 
transpose(int n, int m, Real a[], Real *b = NULL)
{
  int size = m*n;
  if(b!=NULL && b!=a){ /* out of place transpose */
    Real *bmn, *aij, *anm;
    bmn = b + size; /*b+n*m*/
    anm = a + size;
    while(b<bmn) for(aij=a++;aij<anm; aij+=n ) *b++ = *aij;
  }
  else if(n!=1 && m!=1){ /* in place transpose */
    /* PAK: use (n!=1&&m!=1) instead of (size!=3) to avoid vector transpose */
    int i,row,column,current;
    for(i=1, size -= 2;i<size;i++){
      current = i;
      do {
        /*current = row+n*column*/
        column = current/m;
        row = current%m;
        current = n*row + column;
      } while(current < i);

      if (current>i) std::swap(a[i], a[current]);
    }
  }
}

#if 0
// Swap between fortran and C indexing in a 3 dimensional array.
// Should be a clever way to do this in one pass, but instead
// we transpose each matrix separately then swap the ordering of
// the channels. 
template <class Real> void 
c_to_fortran_indexing(int n, int m, int l, Real a[], Real *b = NULL)
{
  if (b==NULL) b=a;
  transpose(l,n*m,a,b);
  for (int i=0; i < l; i++) transpose(n,m,b+i*n*m,b+i*n*m);
}
template <class Real> void 
fortran_to_c_indexing(int n, int m, int l, Real a[], Real *b = NULL)
{
  if (b==NULL) b=a;
  for (int i=0; i < l; i++) transpose(m,n,a+i*n*m,b+i*n*m);
  transpose(n*m,l,b,b);
}
#endif


#endif // _TRANSPOSE_H

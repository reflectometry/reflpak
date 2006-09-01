#ifndef _REBIN_H
#define _REBIN_H

#include <vector>

// rebin_counts(Nx, x, Ix, dIx, Ny, y, Iy, dIy)
// Rebin from the bin edges in x to the bin edges in y where
// I is the counts in each bin and dI is the uncertainty. x and y
// should be of length Nx+1 and Ny+1 respectively.  I and dI should
// be of length Nx and Ny respectively.
template <class Real> void
rebin_counts(const int Nold, const Real xold[], const Real Iold[],
             const int Nnew, const Real xnew[], Real Inew[])
{
  // Note: inspired by rebin from OpenGenie, but using counts per bin rather than rates.

  // Clear the new bins
  for (int i=0; i < Nnew; i++) Inew[i] = 0.;

  // Traverse both sets of bin edges; if there is an overlap, add the portion 
  // of the overlapping old bin to the new bin.
#if 0
  Real xold_lo = xold[0];
  Real xold_hi = xold[1];
  Real xnew_lo = xnew[0];
  Real xnew_hi = xnew[1];
  int iold(1), inew(1);
  while (inew <= Nnew && iold <= Nold) {
    if ( xnew_hi <= xold_lo ) {
      // new must catch up to old
      xnew_lo = xnew_hi;
      xnew_hi = xnew[++inew];
    } else if ( xold_hi <= xnew_lo ) {
      // old must catch up to new
      xold_lo = xold_hi;
      xold_hi = xold[++iold];
    } else {
      // delta is the overlap of the bins on the x axis
      const Real delta = std::min(xold_hi, xnew_hi) - std::max(xold_lo, xnew_lo);
      const Real width = xold_hi - xold_lo;
      const Real portion = delta/width;

      Inew[inew-1] += Iold[iold-1]*portion;
      if ( xnew_hi > xold_hi ) {
	xold_lo = xold_hi;
	xold_hi = xold[++iold];
      } else {
	xnew_lo = xnew_hi;
	xnew_hi = xnew[++inew];
      }
    }
  }
#else
  int iold(0), inew(0);
  while (inew < Nnew && iold < Nold) {
    const Real xold_lo = xold[iold];
    const Real xold_hi = xold[iold+1];
    const Real xnew_lo = xnew[inew];
    const Real xnew_hi = xnew[inew+1];
    if ( xnew_hi <= xold_lo ) inew++;      // new must catch up to old
    else if ( xold_hi <= xnew_lo ) iold++; // old must catch up to new
    else {
      // delta is the overlap of the bins on the x axis
      const Real delta = std::min(xold_hi, xnew_hi) - std::max(xold_lo, xnew_lo);
      const Real width = xold_hi - xold_lo;
      const Real portion = delta/width;

      Inew[inew] += Iold[iold]*portion;
      if ( xnew_hi > xold_hi ) iold++;
      else inew++;
    }
  }
#endif
}

template <class Real> inline void
rebin_counts(const std::vector<Real> &xold, const std::vector<Real> &Iold,
             const std::vector<Real> &xnew, std::vector<Real> &Inew)
{
  assert(xold.size()-1 == Iold.size());
  Inew.resize(xnew.size()-1);
  rebin_counts(Iold.size(), &xold[0], &Iold[0],
               Inew.size(), &xnew[0], &Inew[0]);
}

// rebin_counts(Nx, x, Ix, dIx, Ny, y, Iy, dIy)
// Rebin from the bin edges in x to the bin edges in y where
// I is the counts in each bin and dI is the uncertainty. x and y
// should be of length Nx+1 and Ny+1 respectively.  I and dI should
// be of length Nx and Ny respectively.
template <class Real> void
rebin_intensity(const int Nold, const Real xold[], const Real Iold[], const Real dIold[],
		const int Nnew, const Real xnew[], Real Inew[], Real dInew[])
{
  // Note: inspired by rebin from OpenGenie, but using counts per bin rather than rates.

  // Clear the new bins
  for (int i=0; i < Nnew; i++) dInew[i] = Inew[i] = 0.;

  // Traverse both sets of bin edges, and if there is an overlap, add the portion 
  // of the overlapping old bin to the new bin.
  int iold(0), inew(0);
  while (inew < Nnew && iold < Nold) {
    const Real xold_lo = xold[iold];
    const Real xold_hi = xold[iold+1];
    const Real xnew_lo = xnew[inew];
    const Real xnew_hi = xnew[inew+1];
    if ( xnew_hi <= xold_lo ) inew++;      // new must catch up to old
    else if ( xold_hi <= xnew_lo ) iold++; // old must catch up to new
    else {
      // delta is the overlap of the bins on the x axis
      const Real delta = std::min(xold_hi, xnew_hi) - std::max(xold_lo, xnew_lo);
      const Real width = xold_hi - xold_lo;
      const Real portion = delta/width;

      Inew[inew] += Iold[iold]*portion;
      dInew[inew] += square(dIold[iold]*portion);  // add in quadrature
      if ( xnew_hi > xold_hi ) iold++;
      else inew++;
    }
  }

  // Convert variance to standard deviation.
  for (int i=0; i < Nnew; i++) dInew[i] = sqrt(dInew[i]);
}

template <class Real> inline void
rebin_intensity(const std::vector<Real> &xold, 
		const std::vector<Real> &Iold, const std::vector<Real> &dIold,
		const std::vector<Real> &xnew, 
		std::vector<Real> &Inew, std::vector<Real> &dInew)
{
  assert(xold.size()-1 == Iold.size());
  assert(xold.size()-1 == dIold.size());
  Inew.resize(xnew.size()-1);
  dInew.resize(xnew.size()-1);
  rebin_intensity(Iold.size(), &xold[0], &Iold[0], &dIold[0],
		  Inew.size(), &xnew[0], &Inew[0], &dInew[0]);
}

template <class Real> inline void
compute_uncertainty(const std::vector<Real> &counts, 
		    std::vector<Real> &uncertainty)
{
  uncertainty.resize(counts.size());
  for (size_t i=0; i < counts.size(); i++)
    uncertainty[i] = counts[i] != 0 ? sqrt(counts[i]) : 1.;
}


#endif // _REBIN_H

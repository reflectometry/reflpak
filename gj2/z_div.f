C	Function which implements intrinsic complex multiply
C
C	It's being replaced because the version supplied in libftn.so
C	incorrectly calls abort(3F) when divisor is zero.
C
C	This version lets fp unit determine what to do.  Usually,
C	returns (nan,nan).  Fp unit may be configured to cause an
C	exception, though.  Each call will generate a maximum of 5
C	invalid operation exceptions, but no divide-by-zero exceptions.
C
C	We use the same name as the version in Fortran library, so
C	existing code can still use the Fortran a / b (i.e, no
C	explicit function call required!)
C
C	Kevin O'Donovan    Oct 13, 2000
C
C       XXX FIXME XXX
C       Shouldn't (a+bi)/0 be the same as (a/0) + (b/0)i, which depending 
C       on a and b would be some combination of NaNs and signed infinities.

	double complex FUNCTION z_div(a, b)

	double complex a, b
	double precision ratio, denom

        if (dabs(dreal(b)) .le. dabs(dimag(b))) then
C	   Alternate approaches to handling zero denominator
C	   have been commented out.  FP unit determines all activity.
C	   if (dabs(dimag(b)) .eq. 0.) then
C	      ratio = dsign(1.,dreal(b)*dreal(a))
C	      denom = dimag(b)
C	      ratio = 1.
C	      denom = dimag(b)
C	   else
	      ratio = dreal(b)/dimag(b)
	      denom = dimag(b)*(ratio * ratio + 1.)
C	   endif
	   z_div = dcmplx((dreal(a)*ratio + dimag(a)) / denom,
     ,                    (dimag(a)*ratio - dreal(a)) / denom)
	else
	   ratio = dimag(b)/dreal(b)
	   denom = dreal(b)*(ratio * ratio + 1.)
	   z_div = dcmplx((dreal(a) + dimag(a)*ratio) / denom,
     ,                    (dimag(a) - dreal(a)*ratio) / denom)
	endif
	return 
	end

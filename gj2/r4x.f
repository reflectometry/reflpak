C Modification of C.F. Majrkzak's progam gepore.f for calculating
C reflectivities of four polarization states of neutron reflectivity data.
C This version allows non-vacuum incident and substrate media and has
C been converted into a subroutine.
C This version allows for negative Q by reversing the sample
C /** Note:  this subroutine does not deal with any component of sample **/
C /**        moment that may lie out of the plane of the film.  Such a  **/
C /**        perpendicular component will cause a neutron presession,   **/
C /**        therefore an additional spin flip term.  If reflectivity   **/
C /**        data from a sample with an out-of-plane moment is modeled  **/
C /**        using this subroutine, one will obtain erroneous results,  **/
C /**        since all of the spin flip scattering will be attributed   **/
C /**        to in-plane moments perpendicular to the nuetron           **/

C Compile with -DAMPLITUDE or add #define AMPLITUDE to this file to
C generate the routine R4XA, which returns complex YA, YB, YC, YD
C rather than real magnitude YA, YB, YC, YD

C Kevin O'Donovan 26 Mar 2001

C 2002-01-08 Paul Kienzle
C * optimizations
C * combine r4x and r4xa

#ifdef AMPLITUDE
#define R4X R4XA
#endif

        subroutine R4X(Q,YA,YB,YC,YD,NPNTS,LAMBDA,
     *                 GQCSQ,GMU,GD,GQMSQ,GTHE,NGLAY)

c       implicit double precision (A-H,O-Z)
        implicit none

C       paramters
        integer MAXGEN
#ifdef MINUSQ
        parameter (MAXGEN=8192)
#else
        parameter (MAXGEN=4096)
#endif
        integer NGLAY,NPNTS,NQ,I,J,L
        double precision GQCSQ(MAXGEN),GMU(MAXGEN),GD(MAXGEN)
        double precision GQMSQ(MAXGEN),GTHE(MAXGEN)
        double precision LAMBDA,Q(NPNTS)
#ifdef AMPLITUDE
        double complex YA(NPNTS),YB(NPNTS),YC(NPNTS),YD(NPNTS)
#else
        double precision YA(NPNTS),YB(NPNTS),YC(NPNTS),YD(NPNTS)
#endif

        
C       variables calculating S1, S3, COSH and SINH
        double complex ARG1(MAXGEN),ARG2(MAXGEN)
        double complex EXPPTH(MAXGEN),EXPMTH(MAXGEN)
        double precision EPA, EMA, COSB, SINB
        double complex S1,S3,COSHS1,COSHS3,SINHS1,SINHS3

C       completely unrolled matrices for B=A*B update
        double complex A11,A12,A13,A14,A21,A22,A23,A24
        double complex A31,A32,A33,A34,A41,A42,A43,A44
        double complex B11,B12,B13,B14,B21,B22,B23,B24
        double complex B31,B32,B33,B34,B41,B42,B43,B44
        double complex C1,C2,C3,C4

c       variables for translating resulting B into a signal
        double complex W11,W12,W21,W22,V11,V12,V21,V22
        double complex DETW
        double complex ZI,ZS,X,Y

c       constants
        double precision PI
        double complex CR,CI
        parameter (PI=3.14159265358979)
        parameter (CI=(0.0,1.0),CR=(1.0,0.0))

#ifdef MINUSQ
        integer TOP,BOTTOM,FRONT,BACK
#endif


C	Function to test and reset FPU error flags
	external fperror
	integer fperror
C       Initialize FPU error trap and flags
	call fpreset

C       For this program, incident and substrate media must be non-magnetic, so
        GQMSQ(1)=0.
        GQMSQ(NGLAY+1)=0.
#ifdef MINUSQ
        GQMSQ(NGLAY+2)=0.
        GQMSQ(2*NGLAY+2)=0.
#endif

C     Precalculate ARG and e^th (5-7% faster than doing it in the loop)
        DO 100 L=2,NGLAY
           ARG1(L)=GQCSQ(L)+GQMSQ(L) - CI*8.*PI*GMU(L)/LAMBDA
           ARG2(L)=GQCSQ(L)-GQMSQ(L) - CI*8.*PI*GMU(L)/LAMBDA
           EXPPTH(L)=COS(PI/180.*GTHE(L)) + CI*SIN(PI/180.*GTHE(L))
           EXPMTH(L)=CONJG(EXPPTH(L))
 100    CONTINUE
#ifdef MINUSQ
        DO 200 L=NGLAY+3,NGLAY+NGLAY+1
           ARG1(L)=GQCSQ(L)+GQMSQ(L) - CI*8.*PI*GMU(L)/LAMBDA
           ARG2(L)=GQCSQ(L)-GQMSQ(L) - CI*8.*PI*GMU(L)/LAMBDA
           EXPPTH(L)=COS(PI/180.*GTHE(L)) + CI*SIN(PI/180.*GTHE(L))
           EXPMTH(L)=CONJG(EXPPTH(L))
 200    CONTINUE
#endif

C       Loop over Q data set and calculate relevant reflectivities
        DO 600 NQ=1,NPNTS

#ifdef MINUSQ
C          Set the loop limits based on sign of Q
           TOP = 2
           BOTTOM = NGLAY
           FRONT = 1
           BACK = NGLAY + 1
C          The reversed sample starts at NGLAY + 2
           if (Q(NQ) .lt. 0.) then
                 TOP = 1 + NGLAY + TOP
              BOTTOM = 1 + NGLAY + BOTTOM
               FRONT = 1 + NGLAY + FRONT
                BACK = 1 + NGLAY + BACK
           endif
C           Calculate 2*COSH and 2*SINH for D*S1
            S1=CDSQRT((ARG1(L)-Q(NQ)*Q(NQ))*.25)
            X=S1*GD(L)
            EPA  = EXP(DREAL(X))
            EMA  = 1./EPA
            SINB = SIN(DIMAG(X))
            COSB = COS(DIMAG(X))
            COSHS1 = (EPA+EMA)*COSB + CI*((EPA-EMA)*SINB)
            SINHS1 = (EPA-EMA)*COSB + CI*((EPA+EMA)*SINB)

C           Calculate 2*COSH and 2*SINH for D*S3
            S3=CDSQRT((ARG2(L)-Q(NQ)*Q(NQ))*.25)
            X=S3*GD(L)
            EPA  = EXP(DREAL(X))
            EMA  = 1./EPA
            SINB = SIN(DIMAG(X))
            COSB = COS(DIMAG(X))
            COSHS3 = (EPA+EMA)*COSB + CI*((EPA-EMA)*SINB)
            SINHS3 = (EPA-EMA)*COSB + CI*((EPA+EMA)*SINB)

C           Generate A using a factor of 0.25 since we are using
C           2*cosh and 2*sinh rather than cosh and sinh
            A11=0.25*(COSHS1+COSHS3)
            A21=0.25*(COSHS1-COSHS3)
            A31=0.25*(SINHS1*S1+SINHS3*S3)
            A41=0.25*(SINHS1*S1-SINHS3*S3)
            A13=0.25*(SINHS1/S1+SINHS3/S3)
            A23=0.25*(SINHS1/S1-SINHS3/S3)
            A32=A41*EXPMTH(L)
            A14=A23*EXPMTH(L)
            A12=A21*EXPMTH(L)
            A41=A41*EXPPTH(L)
            A23=A23*EXPPTH(L)
            A21=A21*EXPPTH(L)
            A43=A21
            A34=A12
            A22=A11
            A33=A11
            A44=A11
            A24=A13
            A42=A31

C           Matrix update B=A*B
            C1=A11*B11+A12*B21+A13*B31+A14*B41
            C2=A21*B11+A22*B21+A23*B31+A24*B41
            C3=A31*B11+A32*B21+A33*B31+A34*B41
            C4=A41*B11+A42*B21+A43*B31+A44*B41
            B11=C1
            B21=C2
            B31=C3
            B41=C4

            C1=A11*B12+A12*B22+A13*B32+A14*B42
            C2=A21*B12+A22*B22+A23*B32+A24*B42
            C3=A31*B12+A32*B22+A33*B32+A34*B42
            C4=A41*B12+A42*B22+A43*B32+A44*B42
            B12=C1
            B22=C2
            B32=C3
            B42=C4

            C1=A11*B13+A12*B23+A13*B33+A14*B43
            C2=A21*B13+A22*B23+A23*B33+A24*B43
            C3=A31*B13+A32*B23+A33*B33+A34*B43
            C4=A41*B13+A42*B23+A43*B33+A44*B43
            B13=C1
            B23=C2
            B33=C3
            B43=C4

            C1=A11*B14+A12*B24+A13*B34+A14*B44
            C2=A21*B14+A22*B24+A23*B34+A24*B44
            C3=A31*B14+A32*B24+A33*B34+A34*B44
            C4=A41*B14+A42*B24+A43*B34+A44*B44
            B14=C1
            B24=C2
            B34=C3
            B44=C4

 300      CONTINUE
C         Done computing B = A(NGLAY)*...*A(2)*A(1)*I

C         Rotate polarization axis to lab frame
C         Note: reusing A instead of creating CST
          A12=B12+B21+CI*(B11-B22)
          A21=B21+B12+CI*(B22-B11)
          A11=B11+B22+CI*(B12-B21)
          A22=B22+B11+CI*(B21-B12)
          A14=B14+B23+CI*(B13-B24)
          A23=B23+B14+CI*(B24-B13)
          A13=B13+B24+CI*(B14-B23)
          A24=B24+B13+CI*(B23-B14)
          A32=B32+B41+CI*(B31-B42)
          A41=B41+B32+CI*(B42-B31)
          A31=B31+B42+CI*(B32-B41)
          A42=B42+B31+CI*(B41-B32)
          A34=B34+B43+CI*(B33-B44)
          A43=B43+B34+CI*(B44-B33)
          A33=B33+B44+CI*(B34-B43)
          A44=B44+B33+CI*(B43-B34)

C         Use corrected versions of X,Y,ZI, and ZS to account for effect
C         of incident and substrate media
#ifdef MINUSQ
          ZS=(CI/2.)*CDSQRT(CR*(Q(NQ)*Q(NQ)+GQCSQ(FRONT)-GQCSQ(BACK)))
#else
          ZS=(CI/2.)*CDSQRT(CR*(Q(NQ)*Q(NQ)+GQCSQ(1)-GQCSQ(NGLAY+1)))
#endif
          ZI=(CI/2.)*CDSQRT(CR*(Q(NQ)*Q(NQ)))

          X=-1.
          Y=ZI*ZS

C         W below is U and V is -V of printed versions

          V11=ZS*A11+X*A31+Y*A13-ZI*A33
          V12=ZS*A12+X*A32+Y*A14-ZI*A34
          V21=ZS*A21+X*A41+Y*A23-ZI*A43
          V22=ZS*A22+X*A42+Y*A24-ZI*A44
          
          W11=ZS*A11+X*A31-Y*A13+ZI*A33
          W12=ZS*A12+X*A32-Y*A14+ZI*A34
          W21=ZS*A21+X*A41-Y*A23+ZI*A43
          W22=ZS*A22+X*A42-Y*A24+ZI*A44
          
          DETW=W22*W11-W12*W21

C         Calculate reflectivity coefficients specified by POLSTAT
          if (loc(YA) .NE. 0) then
             X = (V21*W12-V11*W22)/DETW
#ifdef AMPLITUDE
             YA(NQ) = X
#else
             YA(NQ) = (DREAL(X))**2+(DIMAG(X))**2
#endif
          endif
          if (loc(YB) .NE. 0) then
             X = (V11*W21-V21*W11)/DETW
#ifdef AMPLITUDE
             YB(NQ) = X
#else
             YB(NQ) = (DREAL(X))**2+(DIMAG(X))**2
#endif
          endif
          if (loc(YC) .NE. 0) then
             X = (V22*W12-V12*W22)/DETW
#ifdef AMPLITUDE
             YC(NQ) = X
#else
             YC(NQ) = (DREAL(X))**2+(DIMAG(X))**2
#endif
          endif
          if (loc(YD) .NE. 0) then
             X = (V12*W21-V22*W11)/DETW
#ifdef AMPLITUDE
             YD(NQ) = X
#else
             YD(NQ) = (DREAL(X))**2+(DIMAG(X))**2 
#endif
          endif
         
C         Check for errors during calculation of the current Q
          if (fperror() .NE. 0) then
             write(*,6001) Q(NQ)
 6001        format ('/** Matrix error at Q = ',G15.7, ' **/')
          endif

 600    CONTINUE
C       Done computing all desired values of Q

        return
        END

C Subroutine calculates reflected intensity of NLAYER stack
C exactly (without the roughness correction of REFINT)
C From Parratt, Phys. Rev. 95, 359(1954)
C John Ankner 3-May-1989
        double precision function NEWGREFINT(Q,Y,NPNTS,LAMBDA,
     *     GQCSQ,GMU,GD,NGLAY)

c       implicit double precision (A-H,O-Z)
        implicit none

        double precision PI
        parameter (PI=3.1415926)

        double precision GQCSQ(*),GMU(*),GD(*),Q(*),Y(*)
        double precision BETANM1,LAMBDA
        double precision QI
        double precision QISQ,MEIPIOLAMBDA, Ar,Br
        integer NGLAY,NPNTS,N,J
        double complex ANM14TH,RNNP1,RNM1N,FNM1N,QN,QNM1,A,B

C       Check for zero wavelength
        if (LAMBDA .lt. 1.e-10) then
C          write (*,*) '/** Wavelength Must Be Positive **/'
          return
        endif

        MEIPIOLAMBDA=-8.*PI/LAMBDA

        do 30 J=1,NPNTS
C     Loop through to calculate recursion formula described in Parratt
C     with Gaussian roughness added
C     Starting point--no reflected beam in bottom-most (bulk) layer
           RNNP1=(0.,0.)
           if (Q(J) .lt. 1.e-10) then
              QISQ = 1.e-20
           else
              QISQ = Q(J)**2
           endif
           QN=cdsqrt( (QISQ-GQCSQ(NGLAY+1)) + 
     &          (0.,1.)*MEIPIOLAMBDA*GMU(NGLAY+1) )
           do 20 N=NGLAY+1,2,-1
C     Calculate normal component of momentum transfer for layers N and N-1
              QNM1=cdsqrt(DCMPLX(QISQ-GQCSQ(N-1),MEIPIOLAMBDA*GMU(N-1)))
C     Calculate phase factor
C              ANM14TH=cdexp( (0.,-1)*GD(N-1) * QNM1)
              Ar=EXP(-GD(N-1)*DIMAG(QNM1))
              Br=-GD(N-1)*DREAL(QNM1)
              ANM14TH=DCMPLX(Ar*DCOS(Br),Ar*DSIN(Br))
C              FNM1N=(QNM1-QN)/(QNM1+QN)
C     Calculate reflectivity amplitude
C              RNM1N=ANM14TH*((RNNP1+FNM1N)/(RNNP1*FNM1N+1))
              A=QNM1-QN
              B=QNM1+QN
              RNM1N = ANM14TH*((RNNP1*A + B)/(RNNP1*B + A))
C     Carry over to next iteration
              RNNP1=RNM1N
              QN=QNM1
 20        continue
           
           Y(J)=cdabs(RNM1N)**2
 30     continue
        return
        end


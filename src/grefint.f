C Subroutine calculates reflected intensity of NLAYER stack
C exactly (without the roughness correction of REFINT)
C From Parratt, Phys. Rev. 95, 359(1954)
C John Ankner 3-May-1989
        double precision function GREFINT(QI,LAMBDA,
     *     GQCSQ,GMU,GD,NGLAY)

        implicit double precision (A-H,O-Z)

        parameter (PI=3.1415926,MAXGEN=10000)

        double precision GQCSQ(MAXGEN),GMU(MAXGEN),GD(MAXGEN)
        double precision BETANM1,LAMBDA
        double precision QI,FOPI
        integer NGLAY
        double complex ANM1SQ,RNNP1,RNM1N,FNM1N,QN,QNM1

C       Check for zero wavelength
        if (LAMBDA .lt. 1.e-10) then
C          write (*,*) '/** Wavelength Must Be Positive **/'
          return
        endif

	if (QI .lt. 1.e-10) then
	  RNM1N = (1.0,0.0)
	  go to 30
	endif

C       Loop through to calculate recursion formula described in Parratt
C       with Gaussian roughness added
C       Starting point--no reflected beam in bottom-most (bulk) layer
        RNNP1=(0.,0.)
        FOPI=4.*PI
        BETANM1=FOPI*GMU(NGLAY+1)/LAMBDA
        QNM1=cdsqrt((QI*QI-GQCSQ(NGLAY+1))*(1.,0.)
     *                  -(0.,2.)*BETANM1)
        do 20 N=NGLAY+1,2,-1
C         Calculate normal component of momentum transfer for layers N and N-1
          QN=QNM1
          BETANM1=FOPI*GMU(N-1)/LAMBDA
          QNM1=cdsqrt((QI*QI-GQCSQ(N-1))*(1.,0.)
     *                  -(0.,2.)*BETANM1)
C         Calculate phase factor
          ANM1SQ=cdexp((0.,-.5)*QNM1*GD(N-1))
          FNM1N=(QNM1-QN)/(QNM1+QN)
C         Calculate reflectivity amplitude
          RNM1N=ANM1SQ*ANM1SQ*((RNNP1+FNM1N)/(RNNP1*FNM1N+1))
C         Carry over to next iteration
          RNNP1=RNM1N
20      continue

30	GREFINT=cdabs(RNM1N)**2

        return
        end


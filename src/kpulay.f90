!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Copyright 2010.  Los Alamos National Security, LLC. This material was    !
! produced under U.S. Government contract DE-AC52-06NA25396 for Los Alamos !
! National Laboratory (LANL), which is operated by Los Alamos National     !
! Security, LLC for the U.S. Department of Energy. The U.S. Government has !
! rights to use, reproduce, and distribute this software.  NEITHER THE     !
! GOVERNMENT NOR LOS ALAMOS NATIONAL SECURITY, LLC MAKES ANY WARRANTY,     !
! EXPRESS OR IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS         !
! SOFTWARE.  If software is modified to produce derivative works, such     !
! modified software should be clearly marked, so as not to confuse it      !
! with the version available from LANL.                                    !
!                                                                          !
! Additionally, this program is free software; you can redistribute it     !
! and/or modify it under the terms of the GNU General Public License as    !
! published by the Free Software Foundation; version 2.0 of the License.   !
! Accordingly, this program is distributed in the hope that it will be     !
! useful, but WITHOUT ANY WARRANTY; without even the implied warranty of   !
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General !
! Public License for more details.                                         !
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

SUBROUTINE KPULAY

  USE CONSTANTS_MOD
  USE SETUPARRAY
  USE UNIVARRAY
  USE NONOARRAY
  USE NEBLISTARRAY
  USE SPINARRAY
  USE VIRIALARRAY
  USE KSPACEARRAY
  USE MYPRECISION

  IMPLICIT NONE

  INTEGER :: I, J, K, L, M, N, KK, INDI, INDJ
  INTEGER :: LBRA, MBRA, LKET, MKET
  INTEGER :: PREVJ, NEWJ
  INTEGER :: PBCI, PBCJ, PBCK
  INTEGER :: BASISI(5), BASISJ(5), LBRAINC, LKETINC
  INTEGER :: SPININDI, SPININDJ
  INTEGER :: KX, KY, KZ, KCOUNT
  REAL(LATTEPREC) :: ALPHA, BETA, PHI,  COSBETA
  REAL(LATTEPREC) :: RIJ(3), DC(3)
  REAL(LATTEPREC) :: MAGR, MAGR2, MAGRP, MAGRP2
  REAL(LATTEPREC) :: MAXRCUT, MAXRCUT2
  REAL(LATTEPREC) :: MYDFDA, MYDFDB, MYDFDR, RCUTTB
  REAL(LATTEPREC) :: KPOINT(3), KX0, KY0, KZ0, KDOTL
  REAL(LATTEPREC) :: B1(3), B2(3), B3(3), MAG1, MAG2, MAG3, A1A2XA3, K0(3)
  REAL(LATTEPREC) :: WSPINI, WSPINJ
  REAL(LATTEPREC), EXTERNAL :: DFDA, DFDB, DFDR
  COMPLEX(LATTEPREC) :: FTMP_PULAY(3), FTMP_COUL(3), FTMP_SPIN(3)
  COMPLEX(LATTEPREC) :: RHO_PULAY, RHO_COUL, RHO_DIFF, CONJGBLOCH
  COMPLEX(LATTEPREC), ALLOCATABLE :: KX2HRHO(:,:,:), KTMP(:,:), KTMP2(:,:)
  COMPLEX(LATTEPREC), PARAMETER :: ZONE=CMPLX(ONE), ZZERO=CMPLX(ZERO), ZHALF=CMPLX(HALF)

  LOGICAL PATH
  IF (EXISTERROR) RETURN

  ! These were allocated elsewhere. We'll use them to accumulate the complex forces

  KF = CMPLX(ZERO)
  VIRBONDK = CMPLX(ZERO)

  ALLOCATE(KX2HRHO(HDIM, HDIM, NKTOT), KTMP(HDIM, HDIM), KTMP2(HDIM, HDIM))

  ! Computing the reciprocal lattice vectors

  B1(1) = BOX(2,2)*BOX(3,3) - BOX(3,2)*BOX(2,3)
  B1(2) = BOX(3,1)*BOX(2,3) - BOX(2,1)*BOX(3,3)
  B1(3) = BOX(2,1)*BOX(3,2) - BOX(3,1)*BOX(2,2)

  A1A2XA3 = BOX(1,1)*B1(1) + BOX(1,2)*B1(2) + BOX(1,3)*B1(3)

  ! B1 = 2*PI*(A2 X A3)/(A1.(A2 X A3))

  B1 = TWO*PI*B1/A1A2XA3

  ! B2 = 2*PI*(A3 x A1)/(A1(A2 X A3))

  B2(1) = (BOX(3,2)*BOX(1,3) - BOX(1,2)*BOX(3,3))/A1A2XA3
  B2(2) = (BOX(1,1)*BOX(3,3) - BOX(3,1)*BOX(1,3))/A1A2XA3
  B2(3) = (BOX(3,1)*BOX(1,2) - BOX(1,1)*BOX(3,2))/A1A2XA3

  B2 = TWO*PI*B2

  ! B3 = 2*PI*(A1 x A2)/(A1(A2 X A3))

  B3(1) = (BOX(1,2)*BOX(2,3) - BOX(2,2)*BOX(1,3))/A1A2XA3
  B3(2) = (BOX(2,1)*BOX(1,3) - BOX(1,1)*BOX(2,3))/A1A2XA3
  B3(3) = (BOX(1,1)*BOX(2,2) - BOX(2,1)*BOX(1,2))/A1A2XA3

  B3 = TWO*PI*B3

  K0 = PI*KSHIFT

  ! We first have to make the matrix S^-1 H rho = X^2 H rho

  IF (SPINON .EQ. 0) THEN

     IF (KBT .GT. 0.000001) THEN
        
        ! Finite temperature

        DO K = 1, NKTOT
           
           CALL ZGEMM('N', 'N', HDIM, HDIM, HDIM, ZONE, &
                KXMAT(:,:,K), HDIM, KXMAT(:,:,K), HDIM, ZZERO, KX2HRHO(:,:,K), HDIM)
           
           CALL ZGEMM('N', 'N', HDIM, HDIM, HDIM, ZONE, &
                KX2HRHO(:,:,K), HDIM, HK(:,:,K), HDIM, ZZERO, KTMP, HDIM)
           
           ! (S^-1 * H)*RHO
           
           CALL ZGEMM('N', 'N', HDIM, HDIM, HDIM, ZONE, &
             KTMP, HDIM, KBO(:,:,K), HDIM, ZZERO, KX2HRHO(:,:,K), HDIM)
           
        ENDDO
        
     ELSE
        
        ! Te = 0 : Fp = 2Tr[rho H rho dS/dR]
        
        ! Be careful - we're working with bo = 2rho, so we need
        ! the factor of 1/2...
        
        DO K = 1, NKTOT
           
           CALL ZGEMM('N', 'N', HDIM, HDIM, HDIM, ZONE, &
                KBO(:,:,K), HDIM, HK(:,:,K), HDIM, ZZERO, KTMP, HDIM)
           
           CALL ZGEMM('N', 'N', HDIM, HDIM, HDIM, ZHALF, &
                KTMP, HDIM, KBO(:,:,K), HDIM, ZZERO, KX2HRHO(:,:,K), HDIM)
           
        ENDDO
        
     ENDIF

  ELSE ! Now the same but for magnetic systems

     IF (KBT .GT. 0.000001) THEN

        DO K = 1, NKTOT

           CALL ZGEMM('N', 'N', HDIM, HDIM, HDIM, ZONE, &
                KXMAT(:,:,K), HDIM, KXMAT(:,:,K), HDIM, ZZERO, KTMP2, HDIM)

           CALL ZGEMM('N', 'N', HDIM, HDIM, HDIM, ZONE, &
                KHUP(:,:,K), HDIM, KRHOUP(:,:,K), HDIM, ZZERO, KTMP, HDIM)

           CALL ZGEMM('N', 'N',  HDIM, HDIM, HDIM, ZONE, &
                KHDOWN(:,:,K), HDIM, KRHODOWN(:,:,K), HDIM, ZONE, KTMP, HDIM)

           ! (S^-1 * H)*RHO                                                                                                       

           CALL ZGEMM('N', 'N', HDIM, HDIM, HDIM, ZONE, &
             KTMP2, HDIM, KTMP, HDIM, ZZERO, KX2HRHO(:,:,K), HDIM)

        ENDDO
        
     ELSE

        DO K = 1, NKTOT

           CALL ZGEMM('N', 'N', HDIM, HDIM, HDIM, ZONE, &
                KRHOUP(:,:,K), HDIM, KHUP(:,:,K), HDIM, ZZERO, KTMP2, HDIM)

           CALL ZGEMM('N', 'N', HDIM, HDIM, HDIM, ZONE, &
                KTMP2, HDIM, KRHOUP(:,:,K), HDIM, ZZERO, KX2HRHO(:,:,K), HDIM)

           CALL ZGEMM('N', 'N', HDIM, HDIM, HDIM, ZONE, &
                KRHODOWN(:,:,K), HDIM, KHDOWN(:,:,K), HDIM, ZZERO, KTMP2, HDIM)

           CALL ZGEMM('N', 'N', HDIM, HDIM, HDIM, ZONE, &
                KTMP2, HDIM, KRHODOWN(:,:,K), HDIM, ZONE, KX2HRHO(:,:,K), HDIM)

        ENDDO

     ENDIF

  ENDIF


!$OMP PARALLEL DO DEFAULT (NONE) &
!$OMP SHARED(NATS, BASIS, ELEMPOINTER, TOTNEBTB, NEBTB) &
!$OMP SHARED(CR, BOX, KX2HRHO, KBO,  NOINT, ATELE, ELE1, ELE2) &
!$OMP SHARED(KRHOUP, KRHODOWN, SPINON, H2VECT) &
!$OMP SHARED(HCUT, SCUT, MATINDLIST, BASISTYPE, ELECTRO) &
!$OMP SHARED(DELTASPIN, WSS, WPP, WDD, WFF, SPININDLIST) &
!$OMP SHARED(K0, B1, B2, B3, NKX, NKY, NKZ, KF) &
!$OMP SHARED(LCNSHIFT, HUBBARDU, DELTAQ, COULOMBV) &
!$OMP PRIVATE(I, J, K, NEWJ, BASISI, BASISJ, INDI, INDJ, PBCI, PBCJ, PBCK) &
!$OMP PRIVATE(RIJ, MAGR2, MAGR, MAGRP2, MAGRP, PATH, PHI, ALPHA, BETA, COSBETA)&
!$OMP PRIVATE(FTMP_PULAY, FTMP_COUL, FTMP_SPIN) &
!$OMP PRIVATE(DC, LBRAINC, LBRA, MBRA, L, LKETINC, LKET, MKET, RHO_PULAY, RHO_COUL, RHO_DIFF) &
!$OMP PRIVATE(MYDFDA, MYDFDB, MYDFDR, RCUTTB, CONJGBLOCH, KDOTL) &
!$OMP PRIVATE(KPOINT, KCOUNT) &
!!$OMP PRIVATE(WSPINI, WSPINJ, SPININDI, SPININDJ) &
!$OMP REDUCTION(+: VIRBONDK)


  DO I = 1, NATS

     ! Build list of orbitals on atom I
     SELECT CASE(BASIS(ELEMPOINTER(I)))

     CASE("s")
        BASISI(1) = 0
        BASISI(2) = -1
     CASE("p")
        BASISI(1) = 1
        BASISI(2) = -1
     CASE("d")
        BASISI(1) = 2
        BASISI(2) = -1
     CASE("f")
        BASISI(1) = 3
        BASISI(2) = -1
     CASE("sp")
        BASISI(1) = 0
        BASISI(2) = 1
        BASISI(3) = -1
     CASE("sd")
        BASISI(1) = 0
        BASISI(2) = 2
        BASISI(3) = -1
     CASE("sf")
        BASISI(1) = 0
        BASISI(2) = 3
        BASISI(3) = -1
     CASE("pd")
        BASISI(1) = 1
        BASISI(2) = 2
        BASISI(3) = -1
     CASE("pf")
        BASISI(1) = 1
        BASISI(2) = 3
        BASISI(3) = -1
     CASE("df")
        BASISI(1) = 2
        BASISI(2) = 3
        BASISI(3) = -1
     CASE("spd")
        BASISI(1) = 0
        BASISI(2) = 1
        BASISI(3) = 2
        BASISI(4) = -1
     CASE("spf")
        BASISI(1) = 0
        BASISI(2) = 1
        BASISI(3) = 3
        BASISI(4) = -1
     CASE("sdf")
        BASISI(1) = 0
        BASISI(2) = 2
        BASISI(3) = 3
        BASISI(4) = -1
     CASE("pdf")
        BASISI(1) = 1
        BASISI(2) = 2
        BASISI(3) = 3
        BASISI(4) = -1
     CASE("spdf")
        BASISI(1) = 0
        BASISI(2) = 1
        BASISI(3) = 2
        BASISI(4) = 3
        BASISI(5) = -1
     END SELECT

     INDI = MATINDLIST(I)
!     IF (SPINON .EQ. 1) SPININDI = SPININDLIST(I)

     DO NEWJ = 1, TOTNEBTB(I)

        J = NEBTB(1, NEWJ, I)
        PBCI = NEBTB(2, NEWJ, I)
        PBCJ = NEBTB(3, NEWJ, I)
        PBCK = NEBTB(4, NEWJ, I)

        RIJ(1) = CR(1,J) + REAL(PBCI)*BOX(1,1) + REAL(PBCJ)*BOX(2,1) + &
             REAL(PBCK)*BOX(3,1) - CR(1,I)

        RIJ(2) = CR(2,J) + REAL(PBCI)*BOX(1,2) + REAL(PBCJ)*BOX(2,2) + &
             REAL(PBCK)*BOX(3,2) - CR(2,I)

        RIJ(3) = CR(3,J) + REAL(PBCI)*BOX(1,3) + REAL(PBCJ)*BOX(2,3) + &
             REAL(PBCK)*BOX(3,3) - CR(3,I)

        MAGR2 = RIJ(1)*RIJ(1) + RIJ(2)*RIJ(2) + RIJ(3)*RIJ(3)

        ! Building the forces is expensive - use the cut-off

        RCUTTB = ZERO
        DO K = 1, NOINT

           IF ( (ATELE(I) .EQ. ELE1(K) .AND. &
                ATELE(J) .EQ. ELE2(K)) .OR. &
                (ATELE(J) .EQ. ELE1(K) .AND. &
                ATELE(I) .EQ. ELE2(K) )) THEN

              IF (SCUT(K) .GT. RCUTTB ) RCUTTB = SCUT(K)

           ENDIF

        ENDDO

        IF (MAGR2 .LT. RCUTTB*RCUTTB) THEN

           MAGR = SQRT(MAGR2)

           ! Build list of orbitals on atom J

           SELECT CASE(BASIS(ELEMPOINTER(J)))
           CASE("s")
              BASISJ(1) = 0
              BASISJ(2) = -1
           CASE("p")
              BASISJ(1) = 1
              BASISJ(2) = -1
           CASE("d")
              BASISJ(1) = 2
              BASISJ(2) = -1
           CASE("f")
              BASISJ(1) = 3
              BASISJ(2) = -1
           CASE("sp")
              BASISJ(1) = 0
              BASISJ(2) = 1
              BASISJ(3) = -1
           CASE("sd")
              BASISJ(1) = 0
              BASISJ(2) = 2
              BASISJ(3) = -1
           CASE("sf")
              BASISJ(1) = 0
              BASISJ(2) = 3
              BASISJ(3) = -1
           CASE("pd")
              BASISJ(1) = 1
              BASISJ(2) = 2
              BASISJ(3) = -1
           CASE("pf")
              BASISJ(1) = 1
              BASISJ(2) = 3
              BASISJ(3) = -1
           CASE("df")
              BASISJ(1) = 2
              BASISJ(2) = 3
              BASISJ(3) = -1
           CASE("spd")
              BASISJ(1) = 0
              BASISJ(2) = 1
              BASISJ(3) = 2
              BASISJ(4) = -1
           CASE("spf")
              BASISJ(1) = 0
              BASISJ(2) = 1
              BASISJ(3) = 3
              BASISJ(4) = -1
           CASE("sdf")
              BASISJ(1) = 0
              BASISJ(2) = 2
              BASISJ(3) = 3
              BASISJ(4) = -1
           CASE("pdf")
              BASISJ(1) = 1
              BASISJ(2) = 2
              BASISJ(3) = 3
              BASISJ(4) = -1
           CASE("spdf")
              BASISJ(1) = 0
              BASISJ(2) = 1
              BASISJ(3) = 2
              BASISJ(4) = 3
              BASISJ(5) = -1
           END SELECT

           INDJ = MATINDLIST(J)
!           IF (SPINON .EQ. 1) SPININDJ = SPININDLIST(J)

           MAGRP2 = RIJ(1)*RIJ(1) + RIJ(2)*RIJ(2)
           MAGRP = SQRT(MAGRP2)


           ! transform to system in which z-axis is aligned with RIJ

           PATH = .FALSE.
           IF (ABS(RIJ(1)) .GT. 1E-12) THEN
              IF (RIJ(1) .GT. ZERO .AND. RIJ(2) .GE. ZERO) THEN
                 PHI = ZERO
              ELSEIF (RIJ(1) .GT. ZERO .AND. RIJ(2) .LT. ZERO) THEN
                 PHI = TWO * PI
              ELSE
                 PHI = PI
              ENDIF
              ALPHA = ATAN(RIJ(2) / RIJ(1)) + PHI
           ELSEIF (ABS(RIJ(2)) .GT. 1E-12) THEN
              IF (RIJ(2) .GT. 1E-12) THEN
                 ALPHA = PI / TWO
              ELSE
                 ALPHA = THREE * PI / TWO
              ENDIF
           ELSE
              ! pathological case: pole in alpha at beta=0
              PATH = .TRUE.
           ENDIF

           COSBETA = RIJ(3)/MAGR
           BETA = ACOS(RIJ(3) / MAGR)

           DC = RIJ/MAGR

           ! build forces using PRB 72 165107 eq. (12) - the sign of the
           ! dfda contribution seems to be wrong, but gives the right
           ! answer(?)

           FTMP_PULAY = ZERO
           FTMP_COUL = ZERO
           FTMP_SPIN = ZERO

           K = INDI

           LBRAINC = 1
           DO WHILE (BASISI(LBRAINC) .NE. -1)

              LBRA = BASISI(LBRAINC)
              LBRAINC = LBRAINC + 1
              
              DO MBRA = -LBRA, LBRA

                 K = K + 1
                 L = INDJ

                 LKETINC = 1
                 DO WHILE (BASISJ(LKETINC) .NE. -1)

                    LKET = BASISJ(LKETINC)
                    LKETINC = LKETINC + 1

                    DO MKET = -LKET, LKET

                       L = L + 1

                       !RHO = X2HRHO(L, K)

                       IF (.NOT. PATH) THEN

                          ! Unroll loops and pre-compute

                          MYDFDA = DFDA(I, J, LBRA, LKET, MBRA, &
                               MKET, MAGR, ALPHA, COSBETA, "S")

                          MYDFDB = DFDB(I, J, LBRA, LKET, MBRA, &
                               MKET, MAGR, ALPHA, COSBETA, "S")

                          MYDFDR = DFDR(I, J, LBRA, LKET, MBRA, &
                               MKET, MAGR, ALPHA, COSBETA, "S")


                          KCOUNT = 0

                          DO KX = 1, NKX

                             DO KY = 1, NKY

                                DO KZ = 1, NKZ

                                   KPOINT = ZERO
                                   KPOINT = KPOINT + (TWO*REAL(KX) - REAL(NKX) - ONE)/(TWO*REAL(NKX))*B1
                                   KPOINT = KPOINT + (TWO*REAL(KY) - REAL(NKY) - ONE)/(TWO*REAL(NKY))*B2
                                   KPOINT = KPOINT + (TWO*REAL(KZ) - REAL(NKZ) - ONE)/(TWO*REAL(NKZ))*B3
                                   
                                   KCOUNT = KCOUNT+1

                                   KDOTL = KPOINT(1)*RIJ(1) + KPOINT(2)*RIJ(2) + &
                                        KPOINT(3)*RIJ(3)

                                   CONJGBLOCH = EXP(CMPLX(ZERO,-KDOTL))

                                   RHO_PULAY = KX2HRHO(K,L,KCOUNT)*CONJGBLOCH

                                   SELECT CASE(SPINON)
                                   CASE(0)
                                      RHO_COUL = KBO(K,L,KCOUNT)*CONJGBLOCH
                                   CASE(1)
                                      RHO_COUL = (KRHOUP(K,L,KCOUNT) + KRHODOWN(K,L,KCOUNT))*CONJGBLOCH
                                      RHO_DIFF = (KRHOUP(K,L,KCOUNT) - KRHODOWN(K,L,KCOUNT)) * &
                                           CONJGBLOCH*(H2VECT(K) + H2VECT(L))
                                   END SELECT
                                      
                                   !
                                   ! d/d_alpha
                                   !

                                   FTMP_PULAY(1) = FTMP_PULAY(1) + RHO_PULAY * &
                                        (-RIJ(2) / MAGRP2 * MYDFDA)

                                   FTMP_PULAY(2) = FTMP_PULAY(2) + RHO_PULAY * &
                                        (RIJ(1)/ MAGRP2 * MYDFDA)

                                   FTMP_COUL(1) = FTMP_COUL(1) + RHO_COUL * &
                                        (-RIJ(2) / MAGRP2 * MYDFDA)

                                   FTMP_COUL(2) = FTMP_COUL(2) + RHO_COUL * &
                                        (RIJ(1)/ MAGRP2 * MYDFDA)

                                   IF (SPINON .EQ. 1) THEN

                                      FTMP_SPIN(1) = FTMP_SPIN(1) + RHO_DIFF * &
                                           (-RIJ(2) / MAGRP2 * MYDFDA)
                                      
                                      FTMP_SPIN(2) = FTMP_SPIN(2) + RHO_DIFF * &
                                           (RIJ(1)/ MAGRP2 * MYDFDA)
                                      
                                   ENDIF

                                   !
                                   ! d/d_beta
                                   !

                                   FTMP_PULAY(1) = FTMP_PULAY(1) + RHO_PULAY * &
                                        (((((RIJ(3) * RIJ(1)) / &
                                        MAGR2)) / MAGRP) * MYDFDB)

                                   FTMP_PULAY(2) = FTMP_PULAY(2) + RHO_PULAY * &
                                        (((((RIJ(3) * RIJ(2)) / &
                                        MAGR2)) / MAGRP) * MYDFDB)

                                   FTMP_PULAY(3) = FTMP_PULAY(3) - RHO_PULAY * &
                                        (((ONE - ((RIJ(3) * RIJ(3)) / &
                                        MAGR2)) / MAGRP) * MYDFDB)

                                   FTMP_COUL(1) = FTMP_COUL(1) + RHO_COUL * &
                                        (((((RIJ(3) * RIJ(1)) / &
                                        MAGR2)) / MAGRP) * MYDFDB)

                                   FTMP_COUL(2) = FTMP_COUL(2) + RHO_COUL * &
                                        (((((RIJ(3) * RIJ(2)) / &
                                        MAGR2)) / MAGRP) * MYDFDB)

                                   FTMP_COUL(3) = FTMP_COUL(3) - RHO_COUL * &
                                        (((ONE - ((RIJ(3) * RIJ(3)) / &
                                        MAGR2)) / MAGRP) * MYDFDB)

                                   IF (SPINON .EQ. 1) THEN

                                      FTMP_SPIN(1) = FTMP_SPIN(1) + RHO_DIFF * &
                                           (((((RIJ(3) * RIJ(1)) / &
                                           MAGR2)) / MAGRP) * MYDFDB)
                                      
                                      FTMP_SPIN(2) = FTMP_SPIN(2) + RHO_DIFF * &
                                           (((((RIJ(3) * RIJ(2)) / &
                                           MAGR2)) / MAGRP) * MYDFDB)
                                      
                                      FTMP_SPIN(3) = FTMP_SPIN(3) - RHO_DIFF * &
                                           (((ONE - ((RIJ(3) * RIJ(3)) / &
                                           MAGR2)) / MAGRP) * MYDFDB)
                                      
                                   ENDIF
                                   

                                   !
                                   ! d/dR
                                   !

                                   FTMP_PULAY(1) = FTMP_PULAY(1) - RHO_PULAY * DC(1) * &
                                        MYDFDR

                                   FTMP_PULAY(2) = FTMP_PULAY(2) - RHO_PULAY * DC(2) * &
                                        MYDFDR

                                   FTMP_PULAY(3) = FTMP_PULAY(3) - RHO_PULAY * DC(3) * &
                                        MYDFDR

                                   FTMP_COUL(1) = FTMP_COUL(1) - RHO_COUL * DC(1) * &
                                        MYDFDR

                                   FTMP_COUL(2) = FTMP_COUL(2) - RHO_COUL * DC(2) * &
                                        MYDFDR

                                   FTMP_COUL(3) = FTMP_COUL(3) - RHO_COUL * DC(3) * &
                                        MYDFDR

                                   IF (SPINON .EQ. 1) THEN
                                      
                                      FTMP_SPIN(1) = FTMP_SPIN(1) - RHO_DIFF * DC(1) * &
                                           MYDFDR
                                      
                                      FTMP_SPIN(2) = FTMP_SPIN(2) - RHO_DIFF * DC(2) * &
                                           MYDFDR
                                      
                                      FTMP_SPIN(3) = FTMP_SPIN(3) - RHO_DIFF * DC(3) * &
                                           MYDFDR
                                      
                                   ENDIF

                                ENDDO
                             ENDDO
                          ENDDO

                       ELSE

                          ! pathological configuration in which beta=0
                          ! or pi => alpha undefined

                          ! fixed: MJC 12/17/13

                          MYDFDB = DFDB(I, J, LBRA, LKET, &
                               MBRA, MKET, MAGR, ZERO, COSBETA, "S") / MAGR

                          MYDFDB = DFDB(I, J, LBRA, LKET, &
                               MBRA, MKET, MAGR, PI/TWO, COSBETA, "S") / MAGR

                          MYDFDR = DFDR(I, J, LBRA, LKET, MBRA, &
                               MKET, MAGR, ZERO, COSBETA, "S")

                          KCOUNT = 0

                          DO KX = 1, NKX

                             DO KY = 1, NKY

                                DO KZ = 1, NKZ


                                   KPOINT = ZERO
                                   KPOINT = KPOINT + (TWO*REAL(KX) - REAL(NKX) - ONE)/(TWO*REAL(NKX))*B1
                                   KPOINT = KPOINT + (TWO*REAL(KY) - REAL(NKY) - ONE)/(TWO*REAL(NKY))*B2
                                   KPOINT = KPOINT + (TWO*REAL(KZ) - REAL(NKZ) - ONE)/(TWO*REAL(NKZ))*B3
                                   
                                   KCOUNT = KCOUNT+1

                                   KDOTL = KPOINT(1)*RIJ(1) + KPOINT(2)*RIJ(2) + &
                                        KPOINT(3)*RIJ(3)

                                   CONJGBLOCH = EXP(CMPLX(ZERO,-KDOTL))

                                   RHO_PULAY = KX2HRHO(K,L,KCOUNT)*CONJGBLOCH

                                   SELECT CASE(SPINON)
                                   CASE(0)
                                      RHO_COUL = KBO(K,L,KCOUNT)*CONJGBLOCH
                                   CASE(1)
                                      RHO_COUL = (KRHOUP(K,L,KCOUNT) + KRHODOWN(K,L,KCOUNT))*CONJGBLOCH
                                      RHO_DIFF = (KRHOUP(K,L,KCOUNT) - KRHODOWN(K,L,KCOUNT)) * &
                                           CONJGBLOCH*(H2VECT(K) + H2VECT(L))
                                   END SELECT

                                   FTMP_PULAY(1) = FTMP_PULAY(1) - RHO_PULAY * COSBETA * MYDFDB
                                   FTMP_PULAY(2) = FTMP_PULAY(2) - RHO_PULAY * COSBETA * MYDFDB
                                   FTMP_PULAY(3) = FTMP_PULAY(3) - RHO_PULAY * COSBETA * MYDFDR

                                   FTMP_COUL(1) = FTMP_COUL(1) - RHO_COUL * COSBETA * MYDFDB
                                   FTMP_COUL(2) = FTMP_COUL(2) - RHO_COUL * COSBETA * MYDFDB
                                   FTMP_COUL(3) = FTMP_COUL(3) - RHO_COUL * COSBETA * MYDFDR

                                   IF (SPINON .EQ. 1) THEN
                                      FTMP_SPIN(1) = FTMP_SPIN(1) - RHO_DIFF * (COSBETA * MYDFDB)
                                      FTMP_SPIN(2) = FTMP_SPIN(2) - RHO_DIFF * (COSBETA * MYDFDB)
                                      FTMP_SPIN(3) = FTMP_SPIN(3) - RHO_DIFF * (COSBETA * MYDFDR)
                                   ENDIF


                                ENDDO
                             ENDDO
                          ENDDO
                          
                       ENDIF

                    ENDDO
                 ENDDO
              ENDDO
           ENDDO

           KF(1,I) = KF(1,I) - TWO * FTMP_PULAY(1)
           KF(2,I) = KF(2,I) - TWO * FTMP_PULAY(2)
           KF(3,I) = KF(3,I) - TWO * FTMP_PULAY(3)

           VIRBONDK(1) = VIRBONDK(1) - RIJ(1) * FTMP_PULAY(1)
           VIRBONDK(2) = VIRBONDK(2) - RIJ(2) * FTMP_PULAY(2)
           VIRBONDK(3) = VIRBONDK(3) - RIJ(3) * FTMP_PULAY(3)
           VIRBONDK(4) = VIRBONDK(4) - RIJ(1) * FTMP_PULAY(2)
           VIRBONDK(5) = VIRBONDK(5) - RIJ(2) * FTMP_PULAY(3)
           VIRBONDK(6) = VIRBONDK(6) - RIJ(3) * FTMP_PULAY(1)


           IF (ELECTRO .EQ. 1) THEN

              FTMP_COUL = FTMP_COUL * ( HUBBARDU(ELEMPOINTER(J))*DELTAQ(J) + COULOMBV(J) &
                   +HUBBARDU(ELEMPOINTER(I))*DELTAQ(I) + COULOMBV(I))
           
           ELSE

              FTMP_COUL = FTMP_COUL * (LCNSHIFT(I) + LCNSHIFT(J))

           ENDIF

           
           KF(1,I) = KF(1,I) + FTMP_COUL(1)
           KF(2,I) = KF(2,I) + FTMP_COUL(2)
           KF(3,I) = KF(3,I) + FTMP_COUL(3)
           
           ! with the factor of 2...                                            
           
           VIRBONDK(1) = VIRBONDK(1) + RIJ(1)*FTMP_COUL(1)/TWO
           VIRBONDK(2) = VIRBONDK(2) + RIJ(2)*FTMP_COUL(2)/TWO
           VIRBONDK(3) = VIRBONDK(3) + RIJ(3)*FTMP_COUL(3)/TWO
           VIRBONDK(4) = VIRBONDK(4) + RIJ(1)*FTMP_COUL(2)/TWO
           VIRBONDK(5) = VIRBONDK(5) + RIJ(2)*FTMP_COUL(3)/TWO
           VIRBONDK(6) = VIRBONDK(6) + RIJ(3)*FTMP_COUL(1)/TWO
           

           IF (SPINON .EQ. 1) THEN

              KF(1,I) = KF(1,I) + FTMP_SPIN(1)
              KF(2,I) = KF(2,I) + FTMP_SPIN(2)
              KF(3,I) = KF(3,I) + FTMP_SPIN(3)

              VIRBONDK(1) = VIRBONDK(1) + RIJ(1)*FTMP_SPIN(1)/TWO
              VIRBONDK(2) = VIRBONDK(2) + RIJ(2)*FTMP_SPIN(2)/TWO
              VIRBONDK(3) = VIRBONDK(3) + RIJ(3)*FTMP_SPIN(3)/TWO
              VIRBONDK(4) = VIRBONDK(4) + RIJ(1)*FTMP_SPIN(2)/TWO
              VIRBONDK(5) = VIRBONDK(5) + RIJ(2)*FTMP_SPIN(3)/TWO
              VIRBONDK(6) = VIRBONDK(6) + RIJ(3)*FTMP_SPIN(1)/TWO
           
           ENDIF

        ENDIF

     ENDDO
     
  ENDDO

!$OMP END PARALLEL DO

  DEALLOCATE(KX2HRHO, KTMP, KTMP2)

  !  PRINT*, KF(1,1), KF(2,1), KF(3,1)

  !  DO I= 1, NATS
  !     WRITE(6,10) I, FPUL(1,I), FPUL(2,I), FPUL(3,I)
  !  ENDDO

  !10 FORMAT(I4, 3F12.6)

  FPUL = REAL(KF)/REAL(NKTOT)
  VIRPUL = REAL(VIRBONDK)/REAL(NKTOT)

  !  print*, VIRPUL(1)
  RETURN

END SUBROUTINE KPULAY

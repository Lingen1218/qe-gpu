!
! Copyright (C) 2001-2015 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!
!----------------------------------------------------------------------
subroutine init_us_2 (npw_, igk_, q_, vkb_)
  !----------------------------------------------------------------------
  !
  !   Calculates beta functions (Kleinman-Bylander projectors), with
  !   structure factor, for all atoms, in reciprocal space. On input:
  !      npw_       : number of PWs 
  !      igk_(npw_) : indices of G in the list of q+G vectors
  !      q_(3)      : q vector (2pi/a units)
  !  On output:
  !      vkb_(npwx,nkb) : beta functions (npw_ <= npwx)
  !
  USE kinds,      ONLY : DP
  USE ions_base,  ONLY : nat, ntyp => nsp, ityp, tau
  USE cell_base,  ONLY : tpiba
  USE constants,  ONLY : tpi
  USE gvect,      ONLY : eigts1, eigts2, eigts3, mill, g
  USE wvfct,      ONLY : npwx
  USE us,         ONLY : nqx, dq, tab, tab_d2y, spline_ps
  USE m_gth,      ONLY : mk_ffnl_gth
  USE splinelib
  USE uspp,       ONLY : nkb, nhtol, nhtolm, indv
  USE uspp_param, ONLY : upf, lmaxkb, nhm, nh
  !
  implicit none
  !
  INTEGER, INTENT (IN) :: npw_, igk_ (npw_)
  REAL(dp), INTENT(IN) :: q_(3)
  COMPLEX(dp), INTENT(OUT) :: vkb_ (npwx, nkb)
  !
  !     Local variables
  !
  integer :: i0,i1,i2,i3, ig, lm, na, nt, nb, ih, jkb

  real(DP) :: px, ux, vx, wx, arg
  real(DP), allocatable :: gk (:,:), qg (:), vq (:), ylm (:,:), vkb1(:,:)

  complex(DP) :: phase, pref
  complex(DP), allocatable :: sk(:)

  real(DP), allocatable :: xdata(:)
  integer :: iq

  !
  !
  if (lmaxkb.lt.0) return
  call start_clock ('init_us_2')

  allocate (vkb1( npw_,nhm))    
  allocate (  sk( npw_))    
  allocate (  qg( npw_))    
  allocate (  vq( npw_))    
  allocate ( ylm( npw_, (lmaxkb + 1) **2))    
  allocate (  gk( 3, npw_))    
  !
!   write(*,'(3i4,i5,3f10.5)') size(tab,1), size(tab,2), size(tab,3), size(vq), q_
  do ig = 1, npw_
     gk (1,ig) = q_(1) + g(1, igk_(ig) )
     gk (2,ig) = q_(2) + g(2, igk_(ig) )
     gk (3,ig) = q_(3) + g(3, igk_(ig) )
     qg (ig) = gk(1, ig)**2 +  gk(2, ig)**2 + gk(3, ig)**2
  enddo
  !
  call ylmr2 ((lmaxkb+1)**2, npw_, gk, qg, ylm)
  !
  ! set now qg=|q+G| in atomic units
  !
  do ig = 1, npw_
     qg(ig) = sqrt(qg(ig))*tpiba
  enddo

  if (spline_ps) then
    allocate(xdata(nqx))
    do iq = 1, nqx
      xdata(iq) = (iq - 1) * dq
    enddo
  endif
  ! |beta_lm(q)> = (4pi/omega).Y_lm(q).f_l(q).(i^l).S(q)
  jkb = 0
  do nt = 1, ntyp
     ! calculate beta in G-space using an interpolation table f_l(q)=\int _0 ^\infty dr r^2 f_l(r) j_l(q.r)
     do nb = 1, upf(nt)%nbeta
        if ( upf(nt)%is_gth ) then
           call mk_ffnl_gth( nt, nb, npw_, qg, vq )
        else
           do ig = 1, npw_
              if (spline_ps) then
                vq(ig) = splint(xdata, tab(:,nb,nt), tab_d2y(:,nb,nt), qg(ig))
              else
                px = qg (ig) / dq - int (qg (ig) / dq)
                ux = 1.d0 - px
                vx = 2.d0 - px
                wx = 3.d0 - px
                i0 = INT( qg (ig) / dq ) + 1
                i1 = i0 + 1
                i2 = i0 + 2
                i3 = i0 + 3
                vq (ig) = tab (i0, nb, nt) * ux * vx * wx / 6.d0 + &
                          tab (i1, nb, nt) * px * vx * wx / 2.d0 - &
                          tab (i2, nb, nt) * px * ux * wx / 2.d0 + &
                          tab (i3, nb, nt) * px * ux * vx / 6.d0
              endif
           enddo
        endif
        ! add spherical harmonic part  (Y_lm(q)*f_l(q)) 
        do ih = 1, nh (nt)
           if (nb.eq.indv (ih, nt) ) then
              !l = nhtol (ih, nt)
              lm =nhtolm (ih, nt)
              do ig = 1, npw_
                 vkb1 (ig,ih) = ylm (ig, lm) * vq (ig)
              enddo
           endif
        enddo
     enddo
     !
     ! vkb1 contains all betas including angular part for type nt
     ! now add the structure factor and factor (-i)^l
     !
     do na = 1, nat
        ! ordering: first all betas for atoms of type 1
        !           then  all betas for atoms of type 2  and so on
        if (ityp (na) .eq.nt) then
           arg = (q_(1) * tau (1, na) + &
                  q_(2) * tau (2, na) + &
                  q_(3) * tau (3, na) ) * tpi
           phase = CMPLX(cos (arg), - sin (arg) ,kind=DP)
           do ig = 1, npw_
              sk (ig) = eigts1 (mill(1,igk_(ig)), na) * &
                        eigts2 (mill(2,igk_(ig)), na) * &
                        eigts3 (mill(3,igk_(ig)), na)
           enddo
           do ih = 1, nh (nt)
              jkb = jkb + 1
              pref = (0.d0, -1.d0) **nhtol (ih, nt) * phase
              do ig = 1, npw_
                 vkb_(ig, jkb) = vkb1 (ig,ih) * sk (ig) * pref
              enddo
              do ig = npw_+1, npwx
                 vkb_(ig, jkb) = (0.0_dp, 0.0_dp)
              enddo
           enddo
        endif
     enddo
  enddo
  deallocate (gk)
  deallocate (ylm)
  deallocate (vq)
  deallocate (qg)
  deallocate (sk)
  deallocate (vkb1)

  call stop_clock ('init_us_2')
  return
end subroutine init_us_2

#ifdef USE_CUDA

subroutine init_us_2_gpu (npw_, igk_d_, q_, vkb_d_)
  !----------------------------------------------------------------------
  !
  !   Calculates beta functions (Kleinman-Bylander projectors), with
  !   structure factor, for all atoms, in reciprocal space. On input:
  !      npw_       : number of PWs 
  !      igk_(npw_) : indices of G in the list of q+G vectors
  !      q_(3)      : q vector (2pi/a units)
  !  On output:
  !      vkb_(npwx,nkb) : beta functions (npw_ <= npwx)
  !
  USE kinds,      ONLY : DP
  USE ions_base,  ONLY : nat, ntyp => nsp, ityp, tau
  USE cell_base,  ONLY : tpiba
  USE constants,  ONLY : tpi
  USE gvect,      ONLY : eigts1_d, eigts2_d, eigts3_d, mill_d, g_d
  USE wvfct,      ONLY : npwx
  USE us,         ONLY : nqx, dq, tab_d, tab_d2y_d, spline_ps
  USE m_gth,      ONLY : mk_ffnl_gth
  USE splinelib
  USE uspp,       ONLY : nkb, nhtol, nhtolm, indv
  USE uspp_param, ONLY : upf, lmaxkb, nhm, nh
  USE cudafor
  USE ylmr2_gpu
  !
  implicit none
  !
  INTEGER, INTENT (IN) :: npw_
  INTEGER, device, INTENT (IN) :: igk_d_ (npw_)
  REAL(dp), INTENT(IN) :: q_(3)
  COMPLEX(dp), device, INTENT(OUT) :: vkb_d_ (npwx, nkb)
  !
  !     Local variables
  !
  integer :: i0,i1,i2,i3, ig, lm, na, nt, nb, ih, jkb
  integer :: istat
  integer :: iv_d
  real(DP) :: px, ux, vx, wx, arg, q1, q2, q3
  real(DP), device, allocatable :: gk_d (:,:), qg_d (:), vq_d(:), ylm_d(:,:), vkb1_d(:,:)
  real(DP) :: rv_d

  complex(DP) :: phase, pref
  complex(DP), device, allocatable :: sk_d(:)

  integer :: iq

  !
  !
  if (lmaxkb.lt.0) return
  call start_clock ('init_us_2')

  ! JR Eventually replace with smarter allocation/deallocation of GPU temp arrays
  allocate (vkb1_d( npw_,nhm))    
  allocate (  sk_d( npw_))    
  allocate (  qg_d( npw_))    
  allocate (  vq_d( npw_))    
  allocate ( ylm_d( npw_, (lmaxkb + 1) **2))    
  allocate (  gk_d( 3, npw_))    
  !
!   write(*,'(3i4,i5,3f10.5)') size(tab,1), size(tab,2), size(tab,3), size(vq), q_

  q1 = q_(1)
  q2 = q_(2)
  q3 = q_(3)

  !$cuf kernel do(1) <<<*,*>>>
  do ig = 1, npw_
     iv_d = igk_d_(ig)
     gk_d (1,ig) = q1 + g_d(1, iv_d )
     gk_d (2,ig) = q2 + g_d(2, iv_d )
     gk_d (3,ig) = q3 + g_d(3, iv_d )
     qg_d (ig) = gk_d(1, ig)*gk_d(1, ig) + &
                 gk_d(2, ig)*gk_d(2, ig) + &
                 gk_d(3, ig)*gk_d(3, ig)
  enddo
  !
  call ylmr2_d ((lmaxkb+1)**2, npw_, gk_d, qg_d, ylm_d)
  !
  ! set now qg=|q+G| in atomic units
  !
  !$cuf kernel do(1) <<<*,*>>>
  do ig = 1, npw_
     qg_d(ig) = sqrt(qg_d(ig))*tpiba
  enddo

  ! JR Don't need this when using splint_eq_gpu
  !if (spline_ps) then
  !  allocate(xdata(nqx))
  !  do iq = 1, nqx
  !    xdata(iq) = (iq - 1) * dq
  !  enddo
  !endif

  ! |beta_lm(q)> = (4pi/omega).Y_lm(q).f_l(q).(i^l).S(q)
  jkb = 0
  do nt = 1, ntyp
     do nb = 1, upf(nt)%nbeta
        if ( upf(nt)%is_gth ) then
           !call mk_ffnl_gth( nt, nb, npw_, qg, vq )
           CALL errore( 'init_us_2_gpu', 'mk_ffnl_gth not implemented on GPU!', 1 )
        else if (spline_ps) then
           call splint_eq_gpu(dq, tab_d(:,nb,nt), tab_d2y_d(:,nb,nt), qg_d, vq_d)
        else
           !$cuf kernel do(1) <<<*,*>>>
           do ig = 1, npw_
              rv_d = qg_d(ig)
              px = rv_d / dq - int (rv_d / dq)
              ux = 1.d0 - px
              vx = 2.d0 - px
              wx = 3.d0 - px
              i0 = INT( rv_d / dq ) + 1
              i1 = i0 + 1
              i2 = i0 + 2
              i3 = i0 + 3
              vq_d (ig) = ux * vx * (wx * tab_d(i0, nb, nt) + px * tab_d(i3, nb, nt)) / 6.d0 + &
                          px * wx * (vx * tab_d(i1, nb, nt) - ux * tab_d(i2, nb, nt)) * 0.5d0
                          
              !vq_d (ig) = tab_d (i0, nb, nt) * ux * vx * wx / 6.d0 + &
              !            tab_d (i1, nb, nt) * px * vx * wx / 2.d0 - &
              !            tab_d (i2, nb, nt) * px * ux * wx / 2.d0 + &
              !            tab_d (i3, nb, nt) * px * ux * vx / 6.d0
           enddo
        endif

        ! add spherical harmonic part  (Y_lm(q)*f_l(q)) 
        do ih = 1, nh (nt)
           if (nb.eq.indv (ih, nt) ) then
              !l = nhtol (ih, nt)
              lm =nhtolm (ih, nt)

              !$cuf kernel do(1) <<<*,*>>>
              do ig = 1, npw_
                 vkb1_d (ig,ih) = ylm_d (ig, lm) * vq_d (ig)
              enddo
           endif
        enddo
     enddo

     !
     ! vkb1 contains all betas including angular part for type nt
     ! now add the structure factor and factor (-i)^l
     !
     do na = 1, nat
        ! ordering: first all betas for atoms of type 1
        !           then  all betas for atoms of type 2  and so on
        if (ityp (na) .eq.nt) then
           arg = (q_(1) * tau (1, na) + &
                  q_(2) * tau (2, na) + &
                  q_(3) * tau (3, na) ) * tpi
           phase = CMPLX(cos (arg), - sin (arg) ,kind=DP)
           !$cuf kernel do(1) <<<*,*>>>
           do ig = 1, npw_
              sk_d (ig) = eigts1_d (mill_d(1,igk_d_(ig)), na) * &
                          eigts2_d (mill_d(2,igk_d_(ig)), na) * &
                          eigts3_d (mill_d(3,igk_d_(ig)), na)
           enddo
           do ih = 1, nh (nt)
              jkb = jkb + 1
              pref = (0.d0, -1.d0) **nhtol (ih, nt) * phase
              !$cuf kernel do(1) <<<*,*>>>
              do ig = 1, npw_
                 vkb_d_(ig, jkb) = vkb1_d (ig,ih) * sk_d (ig) * pref
              enddo
              !$cuf kernel do(1) <<<*,*>>>
              do ig = npw_+1, npwx
                 vkb_d_(ig, jkb) = (0.0_dp, 0.0_dp)
              enddo
           enddo
        endif
     enddo
  enddo

  deallocate(gk_d)
  deallocate(ylm_d) 
  deallocate (vq_d)
  deallocate(qg_d)
  deallocate (sk_d)
  deallocate (vkb1_d)

  call stop_clock ('init_us_2')
  return
end subroutine init_us_2_gpu
#endif

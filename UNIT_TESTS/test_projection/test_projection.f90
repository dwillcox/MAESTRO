module test_projection_module

  use bl_types
  use bl_constants_module
  use multifab_module
  use ml_restriction_module
  use ml_layout_module
  use define_bc_module
  use multifab_fill_ghost_module
  use multifab_physbc_module

  implicit none

  private
  public :: init_velocity, add_grad_scalar

contains

  subroutine init_velocity(U, dx, mla, the_bc_level)

    integer :: n, i, ng, dm, nlevs

    type(multifab) , intent(inout) :: U(:)
    real(kind=dp_t), intent(in   ) :: dx(:,:)
    type(ml_layout)   , intent(inout) :: mla
    type(bc_level)    , intent(in   ) :: the_bc_level(:)

    integer :: lo(get_dim(U(1))), hi(get_dim(U(1)))

    real(kind=dp_t), pointer :: up(:,:,:,:)

    nlevs = size(U)
    dm = get_dim(U(1))

    ng = nghost(U(1))

    do n=1,nlevs
       do i = 1, nboxes(U(n))
          if ( multifab_remote(U(n),i) ) cycle
          up => dataptr(U(n), i)
          lo = lwb(get_box(U(n), i))
          hi = upb(get_box(U(n), i))

          select case (dm)
          case (2)
             call init_velocity_2d(up(:,:,1,:), ng, lo, hi, dx(n,:))

          case (3)
             call bl_error("ERROR: init_velocity not implemented in 3d")

          end select
       end do
    end do

    ! fill ghostcells
    if (nlevs .eq. 1) then

       ! fill ghost cells for two adjacent grids at the same level
       ! this includes periodic domain boundary ghost cells
       call multifab_fill_boundary(U(nlevs))

       ! fill non-periodic domain boundary ghost cells                         
       call multifab_physbc(U(nlevs),1,1,dm,the_bc_level(nlevs))

    else

       ! the loop over nlevs must count backwards to make sure the             
       ! finer grids are done first                                            
       do n=nlevs,2,-1

          ! set level n-1 data to be the average of the level n                
          ! data covering it                                                   
          call ml_cc_restriction(U(n-1),U(n),mla%mba%rr(n-1,:))

          ! fill level n ghost cells using interpolation from                  
          ! level n-1 data note that multifab_fill_boundary and                
          ! multifab_physbc are called for both levels n-1 and n               
          call multifab_fill_ghost_cells(U(n),U(n-1),nghost(U(n)), &
                                         mla%mba%rr(n-1,:), &
                                         the_bc_level(n-1), &
                                         the_bc_level(n), &
                                         1,1,dm, &
                                         fill_crse_input=.false.)
          
       enddo

    end if

  end subroutine init_velocity


  subroutine init_velocity_2d(U, ng, lo, hi, dx)

    ! initialize the velocity field to a divergence-free field.  This
    ! velocity field comes from Almgren, Bell, and Szymczak 1996.

    use probin_module, only: prob_lo, prob_hi

    integer         , intent(in   ) :: lo(:), hi(:), ng
    real (kind=dp_t), intent(inout) :: U(lo(1)-ng:,lo(2)-ng:,:)
    real (kind=dp_t), intent(in   ) :: dx(:)

    ! Local variables
    integer :: i, j
    real (kind=dp_t) :: x, y

    do j = lo(2), hi(2)
       y = (dble(j)+0.5d0)*dx(2) + prob_lo(2)

       do i = lo(1), hi(1)
          x = (dble(i)+0.5d0)*dx(1) + prob_lo(1)
    
          U(i,j,1) = -sin(M_PI*x)**2 * sin(TWO*M_PI*y)
          U(i,j,2) =  sin(M_PI*y)**2 * sin(TWO*M_PI*x)  

       enddo
    enddo

  end subroutine init_velocity_2d



  subroutine add_grad_scalar(U, dx, mla, the_bc_level)

    integer :: n, i, ng, dm, nlevs

    type(multifab) , intent(inout) :: U(:)
    real(kind=dp_t), intent(in   ) :: dx(:,:)
    type(ml_layout)   , intent(inout) :: mla
    type(bc_level)    , intent(in   ) :: the_bc_level(:)

    integer :: lo(get_dim(U(1))), hi(get_dim(U(1)))

    real(kind=dp_t), pointer :: up(:,:,:,:)

    nlevs = size(U)
    dm = get_dim(U(1))

    ng = nghost(U(1))

    do n=1,nlevs
       do i = 1, nboxes(U(n))
          if ( multifab_remote(U(n),i) ) cycle
          up => dataptr(U(n), i)
          lo = lwb(get_box(U(n), i))
          hi = upb(get_box(U(n), i))

          select case (dm)
          case (2)
             call add_grad_scalar_2d(up(:,:,1,:), ng, lo, hi, dx(n,:))

          case (3)
             call bl_error("ERROR: add_grad_scalar not implemented in 3d")

          end select
       end do
    end do

    ! fill ghostcells
    if (nlevs .eq. 1) then

       ! fill ghost cells for two adjacent grids at the same level
       ! this includes periodic domain boundary ghost cells
       call multifab_fill_boundary(U(nlevs))

       ! fill non-periodic domain boundary ghost cells                         
       call multifab_physbc(U(nlevs),1,1,dm,the_bc_level(nlevs))

    else

       ! the loop over nlevs must count backwards to make sure the             
       ! finer grids are done first                                            
       do n=nlevs,2,-1

          ! set level n-1 data to be the average of the level n                
          ! data covering it                                                   
          call ml_cc_restriction(U(n-1),U(n),mla%mba%rr(n-1,:))

          ! fill level n ghost cells using interpolation from                  
          ! level n-1 data note that multifab_fill_boundary and                
          ! multifab_physbc are called for both levels n-1 and n               
          call multifab_fill_ghost_cells(U(n),U(n-1),nghost(U(n)), &
                                         mla%mba%rr(n-1,:), &
                                         the_bc_level(n-1), &
                                         the_bc_level(n), &
                                         1,1,dm, &
                                         fill_crse_input=.false.)
          
       enddo

    end if

  end subroutine add_grad_scalar


  subroutine add_grad_scalar_2d(U, ng, lo, hi, dx)

    ! Add on the gradient of a scalar (phi) that satisfies grad(phi).n = 0.

    use probin_module, only: prob_lo, prob_hi

    integer         , intent(in   ) :: lo(:), hi(:), ng
    real (kind=dp_t), intent(inout) :: U(lo(1)-ng:,lo(2)-ng:,:)
    real (kind=dp_t), intent(in   ) :: dx(:)

    ! Local variables
    integer :: i, j
    real (kind=dp_t) :: x, y

    do j = lo(2), hi(2)
       y = (dble(j)+0.5d0)*dx(2) + prob_lo(2)

       do i = lo(1), hi(1)
          x = (dble(i)+0.5d0)*dx(1) + prob_lo(1)
    
          U(i,j,1) = U(i,j,1) + FOUR*x*(ONE - x)
          U(i,j,2) = U(i,j,2) + FOUR*y*(ONE - y)

       enddo
    enddo

  end subroutine add_grad_scalar_2d


end module test_projection_module

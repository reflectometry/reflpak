      integer function fp_error()
      implicit none

      integer mask, fpgetsticky$
      external fpgetsticky$

      mask = fpgetsticky$()
      if (jiand(mask, 30) .ne. 0) then
         fp_error = 1
      else
         fp_error = 0
      endif
      return
      end

      subroutine fp_error_clear
      implicit none

      integer mask, fpgetsticky$, fpsetsticky$
      external fpgetsticky$, fpsetsticky$

      mask = fpgetsticky$()
      mask = jiand(mask, 1)
      mask = fpsetsticky$(%VAL(mask))

      return
      end

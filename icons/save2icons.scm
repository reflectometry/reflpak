(define (write-indexed-png image base xtn n)
  (if (equal? 0 n)
      (let ((ofile (string-append base xtn))
	    (drawable (car (gimp-image-active-drawable image))))
	(file-png-save 1 image drawable ofile ofile 0 9 0 0 0 0 0))
      (let* ((ofile (string-append base xtn))
	     (indexed-image (car (gimp-channel-ops-duplicate image)))
	     (drawable (car (gimp-image-active-drawable indexed-image))))
	(gimp-convert-indexed indexed-image 2 0 n 0 0 "")
	(file-png-save 1 indexed-image drawable ofile ofile 0 9 0 0 0 0 0)
	(gimp-image-delete indexed-image)))
  )
(define (write-icons image base)
  (gimp-image-scale image 32 32)
  (if (> (car (gimp-image-get-layers image)) 1)
      (gimp-image-merge-visible-layers image 0))
  (write-indexed-png image base "_32.png" 0)
  (write-indexed-png image base "_32d8.png" 255)
  (write-indexed-png image base "_32d4.png" 15)
  (gimp-image-scale image 16 16)
  (write-indexed-png image base "_16.png" 0)
  (write-indexed-png image base "_16d8.png" 255)
  (write-indexed-png image base "_16d4.png" 15))
(define (xcf2icons base)
  (let* ((ifile (string-append base ".xcf"))
	 (image (car (gimp-xcf-load 0 ifile ifile))))
    (write-icons image base)
    (gimp-image-delete image)
    ))
(define (save2icons image base)
  (let ((copy (car (gimp-channel-ops-duplicate image))))
    (write-icons copy base)
    (gimp-image-delete copy)
    ))
(script-fu-register "xcf2icons"
		    "<Toolbox>/Xtns/Script-Fu/User/Convert to icons (batch)"
		    "Batch command to create blah_WWdB.png files from blah.xcf\n\n$gimp --no-interface --batch '(xcf2png \"blah\")'\n\nSee 'save2icons' for details."
		    "Paul Kienzle"
		    "Paul Kienzle"
		    "2004-03-04"
		    ""
		    SF-STRING "Base name of xcf file" "")
(script-fu-register "save2icons"
		    "<Toolbox>/Xtns/Script-Fu/User/Save as icons..."
		    "Create blah_WWD.png files from the visible layers of an image.  Dimension WW is 32 for 32x32 and 16 for 16x16 pixel icons.  Depth D is blank for 32 bit, d8 for 255 color images and d4 for 16 color images.  Use\n\n  $png2ico blah.ico blah_*.png\n\nto build the icon."
		    "Paul Kienzle"
		    "Paul Kienzle"
		    "2004-03-04"
		    ""
		    SF-IMAGE "32x32 image to save" 0
		    SF-STRING "Base name of icon file" "")

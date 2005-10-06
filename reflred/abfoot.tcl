

namespace eval abfoot {
    variable A
    variable B
    variable Io
    variable length
    variable offset
    variable thickness
    variable detector_width
    variable detector_distance
    proc initialize {} {
	# Check if already initialized
	if {[vector_exists ::abfoot_y]} { return }
	vector create ::abfoot_x ::abfoot_y
	foreach {var val} {
	    A 1. B 2. Io 1. length 100. offset 0. thickness 10.
	    detector_width 100. detector_distance 9000.
	} {
	    variable $var
	    set $var $val
	}
    }

    proc dialog {} {
	set w .abfoot
	if {[winfo exists $w]} {
	    wm state normal
	    raise $w
	    return
	}
	initialize
	toplevel $w
	wm title $w "AB footprint"
	set g [graph $w.g]
	active_graph $g -motion append_slit_value
	active_axis $g y
	active_legend $g
	set colors [option get $g lineColors LineColors]
	set coloridx 0
	foreach pol { {} A D } {c1 c2} [lrange $colors 1 6] {
	    opt $g.refl$pol pixels 4 fill {} \
		lineWidth 1 color $c1 symbol square
	    $g element create refl$pol \
		-xdata ::refl_x$pol -ydata ::refl_y$pol -yerror ::refl_dy$pol
	    legend_set $g refl$pol on
	    opt $g.div$pol pixels 4 fill {} \
		lineWidth 0 color $c2 symbol cross
	    $g element create div$pol \
		-xdata ::div_x$pol -ydata ::div_y$pol -yerror ::div_dy$pol
	}
	opt $g.foot pixels 0 fill {} lineWidth 1 \
	    color [lindex $colors 0] symbol {}
	$g element create foot \
	    -xdata ::abfoot_x -ydata ::abfoot_y
	legend_set $g foot on

	set f [frame $w.values]
	set line {}
	foreach {var max} {
	    A 100 B 100 offset 200 length 200 Io 100000	} {
	    spinbox $f.entry${var}  -textvariable ::abfoot::$var \
		-increment [expr {$max/1000.}] -from 0. -to $max \
		-command [namespace code calc] -width 5
	    label $f.label${var} -text $var
	    lappend line $f.label${var} $f.entry${var}
	    bind $f.entry${var} <Return> [namespace code calc]
	}
	$f.entryoffset configure -from "-[$f.entryoffset cget -to]"
	eval pack $line -side left

	set f [frame $w.buttons]
	button $f.apply -text Apply -command [namespace code apply]
	button $f.close -text Close -command [list destroy $w]
	pack $f.apply $f.close -side left

	grid $w.g -sticky news
	grid $w.values -sticky ew
	grid $w.buttons -sticky e
	grid rowconfigure $w 0 -weight 1
	grid columnconfigure $w 0 -weight 1

	# status message dialog
	label $w.message -relief ridge -anchor w
	grid $w.message -sticky ew
    }

    proc integrate {wA wB edge area} {
	set B [vector create \#auto] ;# Area under triangular region
	# Length of intersection in triangular region
	$B expr "($edge-$wA)*($edge>$wA && $edge<$wB) + ($wB-$wA)*($edge>=$wB)"
	# Area of intersection in triangular region; note that if wB==wA then
	# B will be 0 and we have 0 * (1-0/(2*0)) which is zero.  To avoid
	# numerical problems, we transform this to 0 * (1-0/(2*0+epsilon)).
	$B expr "$B * (1 - $B/(2*($wB-$wA)+1e-16))"
	# Area of intersection in rectangular region
	$area expr "$edge*($edge<=$wA) + $wA*($edge>$wA) + $B"
	vector destroy $B
    }

    proc apply {} {
	calc
	# Scale refl by footprint, ignoring zeros
	foreach pol { {} A B C D } {
	    if { [::div_y$pol length] > 0 } {
		::refl_y$pol expr "::div_y$pol / (::abfoot_y + !::abfoot_y)"
		::refl_dy$pol expr "::div_dy$pol / (::abfoot_y + !::abfoot_y)"
	    }
	}
    }

    proc calc {} {
	variable A
	variable B
	variable Io
	variable length
	variable thickness
	variable offset
	if { $A > $B } {
	    message "A must be less than B"
	    ::abfoot_y delete :
	    return
	}
	set lambda [set ::${::reduce_head}(L)]
	set L1 [expr {$length/2.+$offset}]
	set L2 [expr {$length/2.-$offset}]

	if { [::spec_m length] > 0 } {
	    set slit ::spec_m
	    set Qz ::spec_x
	} elseif { [::spec_mA length] > 0 } {
	    set slit ::spec_mA
	    set Qz ::spec_xA
	} elseif { [::spec_mD length] > 0 } {
	    set slit ::spec_mD
	    set Qz ::spec_xD
	}
	$Qz dup ::abfoot_x

	set wA [vector create \#auto] ;# Width of A
	set wB [vector create \#auto] ;# Width of B
	$wA expr "$slit * $A/2" ;# Compute using half width
	$wB expr "$slit * $B/2"

	set lo [vector create \#auto] ;# low edge of the sample
	set hi [vector create \#auto] ;# high edge of the sample
	set Alo [vector create \#auto] ;# area on low edge
	set Ahi [vector create \#auto] ;# area on high edge

	# Algorithm for converting Qx-Qz to alpha-beta:
	#   beta = 2 asin(lambda/(2 pi) sqrt(Qx^2+Qz^2)/2) * 180/pi 
	#        = asin(lambda sqrt(Qx^2+Qz^2) /(4 pi)) / (pi/360)
	#   theta = atan2(Qx,Qz) * 180/pi
	#   alpha = theta + beta/2
	# Since we are in the specular condition, Qx = 0
	#   Qx = 0 => theta => 0 => alpha = beta/2
	#          => alpha = 2 asin(lambda sqrt(Qz^2)/(4 pi)) / 2
	#          => alpha = asin (lambda Qz / 4 pi) in radians
	# Length of intersection d = L sin (alpha)
	#          => d = L sin (asin (lambda Qz / 4 pi)) 
	#          => d = L lambda Qz/(4 pi)
	$lo expr "$L2*$lambda * $Qz / $::pitimes4"
	$hi expr "$L1*$lambda * $Qz / $::pitimes4"
	integrate $wA $wB $lo $Alo
	integrate $wA $wB $hi $Ahi

	# Total area of intersection is the sum of the areas of the regions
	# Normalize that by the total area of the beam (A+B)/2.  Note that
	# the factor of 2 is already incorporated into wA and wB.
	::abfoot_y expr "$Io * ($Alo + $Ahi) / ($wA+$wB)"

	vector destroy $wA $wB $lo $hi $Alo $Ahi
    }

    proc spill {} {
	# It is too difficult to compute beam spill for now.  Leave this
	# pseudo code around in case we decide to implement it later.

	# The primary beam on the detector is the beam reflected from the
	# sample. Beam spill is the portion of the beam which is not 
        # intercepted by the sample but is still incident on the detector.
	# This happens at low angles.  Above the sample this is fairly 
	# simple, being just that portion which is not reflected.  Below 
	# the sample there is the effect of the the thickness of the 
	# sample which shades the beam plus the fact that the detector is 
	# moving out of the path of the beam. At low angles there will also
	# be some beam transmitted through the sample, but this is assumed
	# to be orders of magnitude smaller than the direct beam so we can
	# safely ignore it.  The final effect is the width of the back
	# slits which cuts down the 
	set lo [vector create \#auto] ;# low edge of the sample
	set hi [vector create \#auto] ;# high edge of the sample
	set lo2 [vector create \#auto] ;# low edge of the sample bottom
	set hi2 [vector create \#auto] ;# max(sample,detector)
	set det [vector create \#auto] ;# low edge of the detector
	set refl [vector create \#auto] ;# area of intersection
	set spill_lo [vector create \#auto] ;# area of spill below
	set spill_hi [vector create \#auto] ;# area of spill above

	# Algorithm for converting Qx-Qz to alpha-beta:
	#   beta = 2 asin(lambda/(2 pi) sqrt(Qx^2+Qz^2)/2) * 180/pi 
	#        = asin(lambda sqrt(Qx^2+Qz^2) /(4 pi)) / (pi/360)
	#   theta = atan2(Qx,Qz) * 180/pi
	#   alpha = theta + beta/2
	# Since we are in the specular condition, Qx = 0
	#   Qx = 0 => theta => 0 => alpha = beta/2
	#          => alpha = 2 asin(lambda sqrt(Qz^2)/(4 pi)) / 2
	#          => alpha = asin (lambda Qz / 4 pi) in radians
	# Length of intersection d = L sin (alpha)
	#          => d = L sin (asin (lambda Qz / 4 pi)) 
	#          => d = L lambda Qz/(4 pi)
	$lo expr "-$L2*$lambda * $Qz / $::pitimes4"
	$hi expr "$L1*$lambda * $Qz / $::pitimes4"
	integrate $wA $wB $lo $hi $area

	# From trig, the bottom of the detector is located at
	#    d sin T - D/2 cos T 
	# where d is the detector distance and D is the detector length.
	# Using cos(asin(x)) = sqrt(1-x^2), this is
	#    d lambda Qz/4pi - D/2 sqrt(1-(lambda Qz/4pi)^2)
	$det expr "$detector_distance*$lambda*$Qz/$::pitimes4 - $::detector_width/2 * sqrt(1 - ($lambda*$Qz/$::pitimes4)^2)"

	#  
	# From trig, the projection of thickness in the plane normal to 
	# the beam is 
	#    thickness/cos(theta) = thickness/sqrt(1-(lambda Qz/4 pi)^2)
	# since cos(asin(x)) = sqrt(1-x^2).
	$lo2 expr "$lo - $thickness / sqrt(1 - ($lambda*$Qz/$::pitimes4)^2)"
	$hi2 expr "$det*($det>=$hi) + $hi*($det<$hi)"
	integrate $wA $wB $det $lo2 $spill_lo
	integrate $wA $wB $hi2 $wB $spill_hi

	# Total area of intersection is the sum of the areas of the regions
	# Normalize that by the total area of the beam (A+B)/2
	::abfoot_y expr "2 * $Io * ($refl + $spill_lo + $spill_hi) / ($wA+$wB)"

	
	vector destroy $lo $hi $lo2 $hi2 $det $refl $spill_lo $spill_hi $wA $wB
    }

}

if {$argv0 eq [info script] && ![info exists running]} {
    # running from command line
    set running 1
    lappend auto_path [file dirname $argv0]/../..
    package require Tk
    package require BLT
    package require ncnrlib
    package require tkcon
    namespace import blt::vector blt::graph

    tkcon show
    vector create ::refl_x ::refl_y ::refl_dy ::spec_m
    ::refl_x seq 1 10 0.1
    ::refl_y expr ::refl_x*10.
    ::refl_dy expr sqrt(::refl_y)
    ::spec_m expr ::refl_x/10.
    foreach dim {x y dy} { ::refl_$dim dup ::div_$dim }
    # Need to know lambda to find theta
    set R(L) 5.
    set ::reduce_head R
    set ::pitimes4 [expr {atan(1)*16.}]
    proc append_slit_value {w x y name idx msg} { return $msg }

    abfoot::dialog
} 

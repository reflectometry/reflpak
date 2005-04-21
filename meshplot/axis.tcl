
package require snit

::snit::widgetadaptor axis {

    constructor {args} {
        # Create the text widget; turn off its insert cursor
        installhull using canvas -width 12c -height 1.5c -highlightthickness 0
	bindtags $win [linsert [bindtags $win] 0 Axis]

        # Apply any options passed at creation time.
        $self configurelist $args
    }

    # Pass all other methods and options to the real canvas widget, so
    # that the remaining behavior is as expected.
    delegate method * to hull
    delegate option * to hull
    option -length -default 12c -configuremethod setlength
    option -tics -default {}
    option -mtics -default {}
    option -side -default left
    option -min -default 0.
    option -max -default 1.

    method setlength {} {
    }

    method draw {} {
	# Determine number of dots available on the axis
	set w [expr {[winfo width $win]-1}]
	set h [expr {[winfo height $win]-1}]
	switch -- $options(-side) {
	    default -
	    left { set draw ldraw; set d $h }
	    right { set draw rdraw; set d $h }
	    top { set draw tdraw; set d $w }
	    bottom { set draw bdraw; set d $w }
	}

	if {$options(-tics) != ""} {
	    set min $options(-min)
	    set max $options(-max)
	    set tics {}
	    foreach {value label} $options(-tics) {
		lappend tics [expr {double($value-$min)/double($max-$min)}] $label
	    }
	    set mtics {}
	    foreach value $options(-mtics) {
		lappend mtics [expr {double($value-$min)/double($max-$min)}]
	    }
	} else {
	    # Determine the number of major increments, at most 2 per inch.
	    set steps [expr {ceil(2.*$d/([tk scaling]*72.))}]
	    if {$steps < 1.} { set steps 1. }

	    # turn min,max,steps into major,minor tics
	    $self compute_tics $options(-min) $options(-max) $steps tics mtics
	}

	#Example tics for testing purposes
	#set tics {0.0 1.0 0.2 1.2 0.4 1.4 0.6 1.6 0.8 1.8 1.0 2.0}
	#set mtics {0.05 0.1 0.15 0.25 0.3 0.35 0.45 0.5 0.55 0.65 0.7 0.75 0.85 0.9 0.95}
	$self $draw $tics $mtics
    }

    method ldraw {tics mtics} {
	set w [expr {[winfo width $win]-1}]
	set h [expr {[winfo height $win]-1}]
	$win delete All
	$win create line $w 0 $w [expr {$h+1}] -width 1p -tag All
	set endpos [expr {$w-5.*[tk scaling]}]
	set labpos [expr {$w-7.*[tk scaling]}]
	foreach {pos text} $tics {
	    set p [expr {$h - $h*$pos}]
	    $win create line $w $p $endpos $p -width 1p -tag All
	    $win create text $labpos $p -text $text -anchor e -tag All
	}
	set endpos [expr {$w-3.*[tk scaling]}]
	foreach pos $mtics {
	    set p [expr {$h - $h*$pos}]
	    $win create line $w $p $endpos $p -width 1p -tag All
	}
    }

    method rdraw {tics mtics} {
	set w [expr {[winfo width $win]-1}]
	set h [expr {[winfo height $win]-1}]
	$win delete All
	$win create line 0 0 0 [expr {$h+1}] -width 1p -tag All
	set endpos [expr {5.*[tk scaling]}]
	set labpos [expr {7.*[tk scaling]}]
	foreach {pos text} $tics {
	    set p [expr {$h - $h*$pos}]
	    $win create line 0 $p $endpos $p -width 1p -tag All
	    $win create text $labpos $p -text $text -anchor w -tag All
	}
	set endpos [expr {3.*[tk scaling]}]
	foreach pos $mtics {
	    set p [expr {$h - $h*$pos}]
	    $win create line 0 $p $endpos $p -width 1p -tag All
	}
    }

    method bdraw {tics mtics} {
	set w [expr {[winfo width $win]-1}]
	set h [expr {[winfo height $win]-1}]
	$win delete All
	$win create line 0 0 [expr {$w+1}] 0 -width 1p -tag All
	set endpos [expr {5.*[tk scaling]+1}]
	set labpos [expr {7.*[tk scaling]+1}]
	foreach {pos text} $tics {
	    set p [expr {$w*$pos}]
	    $win create line $p $endpos $p 1 -width 1p -tag All
	    $win create text $p $labpos -text $text -anchor n -tag All
	}
	set endpos [expr {3.*[tk scaling]}]
	foreach pos $mtics {
	    set p [expr {$w*$pos}]
	    $win create line $p $endpos $p 1 -width 1p -tag All
	}
    }

    method tdraw {tics mtics} {
	set w [expr {[winfo width $win]-1}]
	set h [expr {[winfo height $win]-1}]
	$win delete All
	$win create line 0 $h [expr {$w+1}] $h -width 1p -tag All
	set endpos [expr {$h-5.*[tk scaling]+1}]
	set labpos [expr {$h-7.*[tk scaling]+1}]
	foreach {pos text} $tics {
	    set p [expr {$w*$pos}]
	    $win create line $p $endpos $p $h -width 1p -tag All
	    $win create text $p $labpos -text $text -anchor s -tag All
	}
	set endpos [expr {$h-3.*[tk scaling]}]
	foreach pos $mtics {
	    set p [expr {$w*$pos}]
	    $win create line $p $endpos $p $h -width 1p -tag All
	}
    }


    method compute_tics {min max steps tics_v mtics_v} {
	upvar $tics_v tics
	upvar $mtics_v mtics

	# Requires valid limits
	if { $max <= $min } { error "axis limits cannot be equal in $self" }

	# Determine major and minor increment and number of subincrements
	set range [expr {$max-$min}]
	set d [expr {pow(10.,ceil(log10($range/$steps)))}]
	if { 5. * $range / $d <= $steps } {
	    # set major [expr {$d / 5.}]
	    set minor [expr {$d / 20.}]
	    set sub 4
	} elseif { 2. * $range / $d <= $steps } {
	    # set major [expr {$d / 2.}]
	    set minor [expr {$d / 10.}]
	    set sub 5
	} else {
	    # set major $d
	    set minor [expr {$d / 5.}]
	    set sub 5
	}

	# Compute tics
	set n [expr {int(ceil($min/$minor))}]
	set tics {}
	set mtics {}
	set d [expr {$n*$minor}]
	while {$d <= $max} {
	    # normalize position to [0,1]
	    set pos [expr {($d-$min)/$range}]
	    if {  $n%$sub == 0 } {
		# major tic --- normalized position followed by text
		# XXX FIXME XXX if we are looking at a small range
		# away from 0, we are losing too many digits
		lappend tics $pos [format %g $d]
	    } else {
		# minor tic --- just add normalized position
		lappend mtics $pos
	    }
	    set d [expr {[incr n]*$minor}]
	}	
    }
}

bind Axis <Configure> {%W draw}


if {[info exists argv0] && [file tail [info script]]==[file tail $argv0]} {
    catch {
	# Tcl console --- see wiki for details on turning tkcon into a package
	lappend auto_path /home/pkienzle/tcl-8.4.2/lib
	package require tkcon
	tkcon show
    }
    axis .y -width 2c -side left -bg red -min 327.3100201 -max 335.7930203
    axis .x -height 1c -side bottom -bg yellow -min 0 -max 1
    axis .y2 -width 2c -side right -bg red -min -1 -max 1
    axis .x2 -height 1c -side top -bg yellow -min 3.141597 -max 3.141599
    axis .x3 -height 1c -side bottom -bg green -min -335.793 -max -327.31
    canvas .c -bg green -highlightthickness 0

    grid  x .x2  x  -sticky news
    grid .y .c  .y2 -sticky news
    grid  x .x   x  -sticky news
    grid  x .x3  x  -sticky news
    grid columnconfig . {0 2} -minsize 2c
    grid columnconfig . 1 -weight 1
    grid rowconfig . {0 2} -minsize 1c
    grid rowconfig . 1 -weight 1
    . conf -width 15c -height 10c
}


proc grep {pattern list} {
    set result {}
    foreach item $list {
	if { [regexp -- $pattern $item] } { lappend result $item }
    }
    return $result
}

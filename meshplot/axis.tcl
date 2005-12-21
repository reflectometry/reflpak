
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
    option -logscale -default 0

    method setlength {} {
    }

    method draw {} {
	# Determine number of dots available on the axis
	set w [expr {[winfo width $win]-1}]
	set h [expr {[winfo height $win]-1}]
	switch -- $options(-side) {
	    default -
	    left { set draw ldraw; set d $h; set spacing 0.5 }
	    right { set draw rdraw; set d $h; set spacing 0.5 }
	    top { set draw tdraw; set d $w; set spacing 1.25 }
	    bottom { set draw bdraw; set d $w; set spacing 1.25 }
	}

	# Determine the number of major increments, at most 2 per inch.
	set steps [expr {ceil($d/([tk scaling]*72.)/$spacing)}]
	if {$steps < 1.} { set steps 1. }
	# FIXME if horizontal scale with lots of digits per number
	# then we will need cut down the number of major tics and
	# increase the number of displayed digits


	# Sort max and min
	if {$options(-min) >= $options(-max)} {
	    set options(-max) [expr {$options(-min)+1.}]
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
	    # turn min,max,steps into major,minor tics
	    if {[string is true $options(-logscale)]} {
		# puts "log tics in \[$options(-min), $options(-max)]"
		$self log_tics $options(-min) $options(-max) $steps tics mtics
	    } else {
		# puts "linear tics in \[$options(-min), $options(-max)]"
		$self linear_tics $options(-min) $options(-max) $steps tics mtics
	    }
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
	set endpos [expr {$w-3.*[tk scaling]+1}]
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
	set endpos [expr {$h-5.*[tk scaling]}]
	set labpos [expr {$h-7.*[tk scaling]}]
	foreach {pos text} $tics {
	    set p [expr {$w*$pos}]
	    $win create line $p $endpos $p $h -width 1p -tag All
	    $win create text $p $labpos -text $text -anchor s -tag All
	}
	set endpos [expr {$h-3.*[tk scaling]+1}]
	foreach pos $mtics {
	    set p [expr {$w*$pos}]
	    $win create line $p $endpos $p $h -width 1p -tag All
	}
    }


    method log_tic_values {min max steps tics_v mtics_v} {
	upvar $tics_v tics
	upvar $mtics_v mtics

	set tics {}
	set mtics {}
	set range [expr {log10(double($max)/double($min))}]
	set val [expr {pow(10,floor(log10($min)))}]
	if { $range < 0.5 } {
	    # puts " Log scale with linear tics"
	    $self linear_tic_values $min $max $steps tics mtics
	} elseif { $range > $steps } {
	    # puts " Multiple decades per tic, minor tics at remainder"
	    # FIXME may want multiple decades per minor tic too
	    set subtics [expr {int(ceil($range/$steps))}]
	    if { $val < $min } { set val [expr {$val*10}] }
	    set i 0
	    while { $val <= $max } {
		if { $i % $subtics == 0 } {
		    lappend tics $val
		} else {
		    lappend mtics $val
		}
		set val [expr {$val*10.}]
		incr i
	    }
	} elseif { $range*3 > $steps } {
	    # puts " Major tics at decades, minor tics at 2 and 5"
	    while { $val <= $max } {
		if { $val >= $min && $val <= $max } {
		    lappend tics $val
		}
		if { 2*$val >= $min && 2*$val <= $max } {
		    lappend mtics [expr {2*$val}]
		}
		if { 5*$val >= $min && 5*$val <= $max } {
		    lappend mtics [expr {5*$val}]
		}
		set val [expr {$val*10}]
	    }
	} elseif { $range*10 > $steps } {
	    # puts " Major tics at 1 2 5, minor tics at 3 4 6 7 8 9"
	    while { $val <= $max } {
		set i 1
		while { $i < 10 } {
		    if { $i * $val >= $min && $i * $val <= $max } {
			if { $i == 1 || $i == 2 || $i == 5 } {
			    lappend tics [expr {$i*$val}]
			} else {
			    lappend mtics [expr {$i*$val}]
			}
		    }
		    incr i
		}
		set val [expr {$val*10}]
	    }
	} else {
	    # puts " Major tics at 1 2 3 4 5 6 7 8 9, no minor tics"
	    # FIXME consider minor tics at 1.2, 1.5, 2.5, 3.5, 4.5
	    while { $val <= $max } {
		set i 1
		while { $i < 10 } {
		    if { $i * $val >= $min && $i * $val <= $max } {
			lappend tics [expr {$i*$val}]
		    }
		    incr i
		}
		set val [expr {$val*10}]
	    }
	}

    }

    method linear_tic_values {min max steps tics_v mtics_v} {
	upvar $tics_v tics
	upvar $mtics_v mtics

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
	    if {  $n%$sub == 0 } {
		# major tic --- normalized position followed by text
		# FIXME if we are looking at a small range
		# away from 0, we are losing too many digits
		lappend tics $d
	    } else {
		# minor tic --- just add normalized position
		lappend mtics $d
	    }
	    set d [expr {[incr n]*$minor}]
	}
    }

    method linear_tics {min max steps tics_v mtics_v} {
	upvar $tics_v tics
	upvar $mtics_v mtics

	# locate tic marks
	$self linear_tic_values $min $max $steps tv mtv

	# compute number of digits to display for major tic marks
	if { [llength $tv] > 1 } {
	    set step [expr {[lindex $tv 1]-[lindex $tv 0]}]
	    set precision [expr {int(floor(log10($step)))}]
	    if { $precision < 0 } { 
		set precision [expr {-$precision+1}]
	    } else {
		set precision 0
	    }
	} else {
	    set precision 0
	}
 
	# normalize marks to [0,1] and format major tic labels
	set tics {}
	set mtics {}
 	set range [expr {$max-$min}]
	foreach v $tv {
	    set pos [expr {($v-$min)/$range}]
	    if { $precision > 0 } {
		lappend tics $pos [format %.*g $precision $v]
	    } else {
		lappend tics $pos [format %g $v]
	    }
	}
	foreach v $mtv {
	    set pos [expr {($v-$min)/$range}]
	    lappend mtics $pos 
	}
    }

    method log_tics {min max steps tics_v mtics_v} {
	upvar $tics_v tics
	upvar $mtics_v mtics

	# Correct bad ranges
	# FIXME this needs to be based on the actual values plotted
	if { $max <= 0 } { set max 1. }
	if { $min <= 0 } { set min [expr {$max/1000.}] }

	# locate tic marks
	$self log_tic_values $min $max $steps tv mtv
 
	# normalize marks to [0,1] and format major tic labels
	set tics {}
	set mtics {}
	set min [expr {log10($min)}]
 	set range [expr {log10($max)-$min}]
	foreach v $tv {
	    set pos [expr {(log10($v)-$min)/$range}]
	    lappend tics $pos [format %g $v]
	}
	foreach v $mtv {
	    set pos [expr {(log10($v)-$min)/$range}]
	    lappend mtics $pos 
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
    axis .x4 -height 1c -side top -bg green -min 6 -max 98 -logscale 1
    axis .y3 -width 2c -side left -bg green -min 256 -max 257 -logscale 1
    axis .y4 -width 2c -side right -bg green -min .3 -max 857000 -logscale 1

    grid  x   x .x4  x   x  -sticky news
    grid  x   x .x2  x   x  -sticky news
    grid .y3 .y .c  .y2 .y4 -sticky news
    grid  x   x .x   x   x  -sticky news
    grid  x   x .x3  x   x  -sticky news
    grid columnconfig . {0 2} -minsize 2c
    grid columnconfig . 2 -weight 1
    grid rowconfig . {0 2} -minsize 1c
    grid rowconfig . 2 -weight 1
    . conf -width 15c -height 10c
}


proc grep {pattern list} {
    set result {}
    foreach item $list {
	if { [regexp -- $pattern $item] } { lappend result $item }
    }
    return $result
}

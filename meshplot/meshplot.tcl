

catch { package require snit }

::snit::widget meshslice {
}

::snit::widget meshlegend {
    option -limits -configuremethod Limits
    option -items -configuremethod Items
    option -min
    option -max
    component Names
    component Color
    component ZAxis

    hulltype frame
    constructor {args} {
	install Color using togl $win.colors -rgba true -double true -height 0.5c
	install ZAxis using axis $win.z -side bottom -height 1c
	install Names using axis $win.names -side left -width 2c
	grid $win.names $win.colors -sticky news
	grid   x        $win.z      -sticky news
	grid columnconfigure $win 0 -minsize 2c
	grid columnconfigure $win 1 -weight 1
	grid rowconfigure $win 0 -weight 1
	grid rowconfigure $win 1 -minsize 1c
	$self configure -limits {0 1}
    }
    method draw {args} {
	$Color draw

	$Names draw
	$ZAxis draw
    }

    method add {args} {
	$self configure -items [concat $options(-items) $args]
    }

    method Items {name list} {
	set options(-items) $list
	set n [llength $options(-items)]
	if {$n == 0} { set n 1 }
	set v 0.5
	set tics {}
	foreach item $options(-items) {
	    lappend tics $v $item
	    set v [expr {$v+1.}]
	}
	set h [expr $n*0.35]c
	$Color configure -height $h
	$Names configure -min 0 -max $n -tics $tics -height $h
	$Names draw
	$Color draw
    }

    method Limits {op v} {
	foreach axis {-min -max} value $v {
	    $self configure $axis $value
	}
	set n [llength $options(-items)]
	if {$n == 0} { set n 1 }
	$Color limits $options(-min) $options(-max) 0 $n
    }
}

::snit::widget meshplot {
#    option -xborder -default 1c
#    option -yborder -default 2c
    option -xmin
    option -xmax
    option -ymin
    option -ymax
    option -vmin
    option -vmax
    option -limits -configuremethod Limits
    option -vrange -configuremethod Vrange
    option -grid -configuremethod Grid
    option -logdata -configuremethod Logdata
    option -cursor
    option -legend -default {}

    component XAxis
    component YAxis
    component Mesh
    delegate option -xborder to XAxis as -height
    delegate option -yborder to YAxis as -width
    delegate option -width to hull

    hulltype frame
    constructor {args} {
	install XAxis using axis $win.x -side bottom -height 1c
	install YAxis using axis $win.y -side left -width 2c
	install Mesh using togl $win.c -rgba true -double true
	grid $win.y  $win.c -sticky news
	grid   x    $win.x -sticky news
	grid columnconfigure $win 0 -minsize 2c
	grid columnconfigure $win 1 -weight 1
	grid rowconfigure $win 0 -weight 1
	grid rowconfigure $win 1 -minsize 1c
	$self configurelist $args
	$self configure -vmin 0 -vmax 1 -xmin 0 -xmax 1 -ymin 0 -ymax 1

	#event add <<Pick>> <Button-1>
	event add <<Navigate>> <ButtonPress-1>
        event add <<NavigateEnd>> <ButtonRelease-1>
	event add <<Pan>> <Control-Button-1>
	event add <<ZoomIn>> <Button-4>
	event add <<ZoomOut>> <Button-5>
	bind $win.c <<Navigate>> [subst {$win navigate xy 5 %x %y}]
	bind $win.x <<Navigate>> [subst {$win navigate x 5 %x %y}]
	bind $win.y <<Navigate>> [subst {$win navigate y 5 %x %y}]
        bind $win.c <<NavigateEnd>> [subst {$win navigate halt}]
        bind $win.x <<NavigateEnd>> [subst {$win navigate halt}]
        bind $win.y <<NavigateEnd>> [subst {$win navigate halt}]

	bind $win   <<ZoomIn>>  [subst {$win  zoom  5}]
	bind $win   <<ZoomOut>> [subst {$win  zoom -5}]
	bind $win.c <<ZoomIn>>  [subst {$win  zoom  5 %x %y}]
	bind $win.c <<ZoomOut>> [subst {$win  zoom -5 %x %y}]
	bind $win.c <<Pick>>    [subst {$Mesh pick %x %y}]
	bind $win.x <<ZoomIn>>  [subst {$win xzoom  5 %x}]
	bind $win.x <<ZoomOut>> [subst {$win xzoom -5 %x}]
	bind $win.y <<ZoomIn>>  [subst {$win yzoom  5 %y}]
	bind $win.y <<ZoomOut>> [subst {$win yzoom -5 %y}]

	bind $win.c <<Pan>> [subst {pan start $win %X %Y; break }]
	#bind $win.c <ButtonRelease-2> [subst {pan stop $win; break }]
	#bind $win.c <B2-Motion> [subst {pan move $win %X %Y; break }]
    }
    method navigate { which {n 5} {x {}} {y {}} } {
	variable afterid
	if { [string equal $which "halt"] } {
	    catch { after cancel $afterid }
	} else {
	    if {$KeyState::Shift} { 
		set step -$n 
	    } elseif {$KeyState::Control} { 
		set step $n 
	    } else {
		return
	    }
	    switch -- $which {
		x { $self xzoom $step $x }
		y { $self yzoom $step $y }
		xy { $self zoom $step $x $y }
	    }
	    set afterid [after 5 [subst {$self navigate $which $n $x $y}]]
	}
    }
	  
    method zoom { n {x {}} {y {}}} {
	set w [winfo width $win.c]
	set h [winfo height $win.c]
	if {$y != ""} { set y [expr {$h-1-$y}] }
	$self DoZoom -xmin -xmax $w $n $x 
	$self DoZoom -ymin -ymax $h $n $y 
	$self draw
    }
    method xzoom { n {x {}}} { 
	set w [winfo width $win.c]
	$self DoZoom -xmin -xmax $w $n $x
	$self draw
    }
    method yzoom { n {y {}}} { 
	set h [winfo height $win.c]
	if {$y != ""} { set y [expr {$h-1-$y}] }
	$self DoZoom -ymin -ymax $h $n $y
	$self draw
    }
    method DoZoom { l r w n x } {
	set min $options($l)
	set max $options($r)
	if { $n >= 0 } {
	    set step [expr {($max-$min)*$n/100.}]
	} else {
	    set step [expr {($max-$min)*$n/(100.-$n)}]
	}
	if { $x == "" } {
	    set bal 0.5
	} elseif { $x < 0 } {
	    set bal 0.
	} elseif { $x >= $w } {
	    set bal 1.
	} else {
	    set bal [expr {double($x)/double($w)}]
	}
	# puts "zooming $l by $n%, from ($min,$max) by $step at $x of $w ($bal)"
	$self configure $l [expr {$min-$bal*$step}] $r [expr {$max+(1-$bal)*$step}]
    }
    method xview {scroll n units} {
	set min $options(-xmin)
	set max $options(-xmax)
	set step [expr {($max-$min)*$n/20.}]
	$self configure -xmin [expr {$min+$step}] -xmax [expr {$max+$step}]
	$self draw
    }

    method yview {scroll n units} {
	set min $options(-ymin)
	set max $options(-ymax)
	set step [expr {($max-$min)*$n/20.}]
	$self configure -ymin [expr {$min-$step}] -ymax [expr {$max-$step}]
	$self draw
    }

    method draw {args} {
	$XAxis configure -min $options(-xmin) -max $options(-xmax)
	$YAxis configure -min $options(-ymin) -max $options(-ymax)

	$Mesh limits $options(-xmin) $options(-xmax) $options(-ymin) $options(-ymax)
	$Mesh draw

	$XAxis draw
	$YAxis draw
    }

    method autoaxes {args} {
	# Determine axis limits.  If the y-range is empty then we
	# expand the limits to make a non-trivial range.
	# XXX FIXME XXX to keep data points from the edge of the
	# graph, we should automatically pad the range a bit.
	set min $options(-min)
	set max $options(-max)
	if { $max < $min } {
	    # if lower less than upper, reverse the limits
	    set d $min
	    set max $min
	    set min $d
	} elseif { $max == $min } {
	    if { $max == 0. } {
		# if lower==upper == 0, set limits to [-1,1]
		set min -1.
		set max 1.
		set range 2.
	    } else {
		# if lower==upper != 0, set limits to +/- 1 on the fifth digit
		set d [expr {pow(10.,floor(log10($max))-5)}]
		set min [expr {(floor($max/$d)-1.)*$d}]
		set max [expr {(floor($max/$d)+1.)*$d}]
	    }
	}
    }

    method hue {h} { $Mesh valmap $h }

    method colormap {map} { $Mesh colormap map }

    method mesh {m n x y v {name {}}} {
	set xvar $x
	set yvar $y
	set vvar $v
	$Mesh vrange $options(-vmin) $options(-vmax)
	set id [$Mesh mesh $m $n xvar yvar vvar]
	if { $options(-legend) != "" && $name != ""} {
	    $options(-legend) add $name
	}
	return $id
    }

    method delete {{h *}} {
	foreach id [$Mesh list] {
	    if {[string match $h $id]} { $Mesh delete $id }
	}
    }

    # Cycle through all mesh objects */
    method cycle {} {
	foreach k [$Mesh list] { 
	    $Mesh raise $k
	    $Mesh draw
	    update
	}
    }

    method raise {id} {
	$Mesh raise $id
	$Mesh draw $id
    }

    method plot_demo {} { 
	$Mesh demo 
	if { $options(-legend) != "" } {
	    $options(-legend) add {Mesh 1} {Mesh 2}
	}
	$self configure -limits {0 10 -3 3}
    }

    method Grid {op v} {
	$Mesh grid $v
    }

    method Logdata {op v} {
	$Mesh logdata $v
    }

    method Vrange {op v} {
	foreach axis {-vmin -vmax} value $v {
	    $self configure $axis $value
	}
    }

    method Limits {op v} {
	foreach axis {-xmin -xmax -ymin -ymax} value $v { 
	    $self configure $axis $value
	}
    }

    variable num_demos 0
    method example {} {
	variable num_demos
	incr num_demos
	set x {}
	foreach i {1 2 3 2 3 4 3 4 5} { lappend x [expr {$i+$num_demos}] }
	fvector x $x
	fvector y {1 2 3 1 2 3 1 2 3}
	fvector v {.1 .2 .3 .4}

	set hue [expr {($num_demos%9)/10.}]
	$self hue $hue
	$self mesh 2 2 $x $y $v "Mesh $num_demos"
	$self configure -limits [list 0 [expr {$num_demos+6}] 0 4]
    }


    typemethod demo {} {
	meshlegend .cl
	meshplot .c -legend .cl
	meshplot .d
	grid .c .d -sticky news
	grid .cl - -sticky news
	grid rowconfigure . 0 -w 1
	grid columnconfigure . {0 1} -w 1
	wm geometry . 500x400
	.c example
	.d plot_demo
	.c configure -grid on
    }

}

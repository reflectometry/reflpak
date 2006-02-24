

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

::snit::widget meshcolorbar {
    option -min
    option -max
    component Color
    component ZAxis
    delegate option -padx to hull
    delegate option -pady to hull
    delegate option -logscale to ZAxis

    hulltype frame
    constructor {args} {
	# FIXME need to allow tics on right, left, top or bottom.
	install Color using togl $win.bar -rgba true -double true -width 0.75c
#	install Color using canvas $win.bar -width 0.5c
	install ZAxis using axis $win.z -side right -width 2c
	grid $win.bar $win.z -sticky news
	grid columnconfigure $win 0 -weight 1
	grid rowconfigure $win 0 -weight 1
	$self configure -min 0 -max 1

	# Add mesh to colorbar
	set n 1024
	fvector xv [linspace 0 1 [expr {$n+1}]]
	fvector yv [linspace 0 1 2]
	foreach {x y} [buildmesh $n 1 xv yv] {}
	fvector z [linspace 0 1 $n]
	$Color vrange 0. 1.
	$Color limits 0. 1. 0. 1.
	$Color mesh $n 1 x y z
    }
    method draw {args} {
	# $Color draw
	$ZAxis configure -min $options(-min) -max $options(-max)
	$ZAxis draw
    }

    method vrange {min max} { $self configure -min $min -max $max }

    method colormap {map} { 
	# $Color colormap map 
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
    option -grid
    option -logdata -configuremethod Logdata
    option -legend -default {}
    option -colorbar -default {}

    component XAxis
    component YAxis
    component Mesh
    component Menu
    delegate option -xborder to XAxis as -height
    delegate option -yborder to YAxis as -width
    delegate option -cursor to hull
    delegate option -width to hull
    delegate option -borderwidth to hull

    hulltype frame
    constructor {args} {
	install XAxis using axis $win.x -side bottom -height 1c
	install YAxis using axis $win.y -side left -width 2c
	install Mesh using togl $win.c -rgba true -double true
	install Menu using menu $win.menu -title "Image controls" -tearoff 0
	grid $win.y  $win.c -sticky news
	grid   x    $win.x -sticky news
	grid columnconfigure $win 0 -minsize 2c
	grid columnconfigure $win 1 -weight 1
	grid rowconfigure $win 0 -weight 1
	grid rowconfigure $win 1 -minsize 1c
	$self configurelist $args
	$self configure -vmin 0 -vmax 1 -xmin 0 -xmax 1 -ymin 0 -ymax 1

	#event add <<Pick>> <Button-1>
	event add <<Zoom>> <ButtonPress-1>
	event add <<ZoomMove>> <Motion>
	event add <<ZoomEnd>> <ButtonRelease-1>
	event add <<Navigate>> <Shift-ButtonPress-1>
	event add <<Navigate>> <Control-ButtonPress-1>
        event add <<NavigateEnd>> <ButtonRelease-1>
	event add <<Pan>> <Button-2>
	event add <<ContextMenu>> <Button-3>
	mousewheel bind $win ;# Convert <MouseWheel> to <<Wheel>> events
	bind $win.c <<Navigate>> [subst {$win navigate xy 5 %x %y}]
	bind $win.x <<Navigate>> [subst {$win navigate x 5 %x %y}]
	bind $win.y <<Navigate>> [subst {$win navigate y 5 %x %y}]
        bind $win.c <<NavigateEnd>> [subst {$win navigate halt 0 %x %y}]
        bind $win.x <<NavigateEnd>> [subst {$win navigate halt 0 %x %y}]
        bind $win.y <<NavigateEnd>> [subst {$win navigate halt 0 %x %y}]

	bind $win.c <<Zoom>> [subst {$win zoombox start xy %x %y}]
	bind $win.x <<Zoom>> [subst {$win zoombox start x %x %y}]
	bind $win.y <<Zoom>> [subst {$win zoombox start y %x %y}]
	bind $win.c <<ZoomMove>> [subst {$win zoombox move xy %x %y}]
	bind $win.x <<ZoomMove>> [subst {$win zoombox move x %x %y}]
	bind $win.y <<ZoomMove>> [subst {$win zoombox move y %x %y}]
	bind $win.c <<ZoomEnd>> [subst {$win zoombox end xy %x %y}]
	bind $win.x <<ZoomEnd>> [subst {$win zoombox end x %x %y}]
	bind $win.y <<ZoomEnd>> [subst {$win zoombox end y %x %y}]

	bind $win.c <<Wheel>> "$win zoom  \[mousewheel step %W] %x %y"
	bind $win.x <<Wheel>> "$win xzoom \[mousewheel step %W] %x"
	bind $win.y <<Wheel>> "$win yzoom \[mousewheel step %W] %y"

	bind $win.c <<Pick>> [subst {$Mesh pick %x %y}]
	bind $win.c <<Pan>>  [subst {pan start $win %X %Y; break }]
	#bind $win.c <ButtonRelease-2> [subst {pan stop $win; break }]
	#bind $win.c <B2-Motion> [subst {pan move $win %X %Y; break }]

	bind $win.c <<ContextMenu>> [subst {$win contextmenu %X %Y %x %y}]

	if 0 {
	    # Don't know how to manage data limits yet
	    $Menu add command -label "Show all" \
		-command "$win autoaxes; $win.c draw"
	}
	$self menu "Pan" {pan start %W}
	$self menu "Grid" {%W grid toggle}
    }

    method menu {label command} {
	$Menu add command -label $label \
	    -command [list $self invokemenu $command]
    }
    method invokemenu {command} {
	variable menu
	eval [string map [list %x $menu(x) %y $menu(y) %W $self] $command]
    }

    method contextmenu {X Y x y} {
	variable menu
	set menu(x) $x
	set menu(y) $y
	tk_popup $Menu $X $Y
    }

    variable zoom_x {} 
    variable zoom_y {}
    method zoombox { which dir x y } {
	variable zoom_x 
	variable zoom_y
	if { $which eq "start" } {
            set zoom_x $x
	    set zoom_y $y
        } elseif { $which eq "move" } {
	    # if zooming update bounding box
	} elseif { $which eq "end" } {
            if { $zoom_x ne {} } {
              if { abs($zoom_x-$x)>2 && abs($zoom_y-$y)>2 } {
		foreach {l t} [$self coords $zoom_x $zoom_y] {}
		foreach {r b} [$self coords $x $y] {}
	        if { $l > $r } { foreach {l r} [list $r $l] {} }
	        if { $b > $t } { foreach {t b} [list $b $t] {} }
		if { $dir == "x" || $dir == "xy" } { $self configure -xmin $l -xmax $r }
                if { $dir == "y" || $dir == "xy" } { $self configure -ymin $b -ymax $t }
		$self draw
	      } else {
                event generate $win.c <<ZoomClick>> -x $zoom_x -y $zoom_y
              }
            }
	    set zoom_x {}
	    set zoom_y {}
	}
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

    # Bind an action to a sequence in the graph window
    method bind { sequence action } {
        # Since the Tk binding is happening in the subwidget, we need to
        # explicitly replace the name of the widget in the action
        # with the name of the composite widget.
	# FIXME: how can we allow the usual "bind .g ..." syntax?
	bind $win.c $sequence [string map [list %W $win] $action]
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
# puts "Invoking draw"
	$XAxis configure -min $options(-xmin) -max $options(-xmax)
	$YAxis configure -min $options(-ymin) -max $options(-ymax)
	$Mesh grid $options(-grid)

	$Mesh limits $options(-xmin) $options(-xmax) $options(-ymin) $options(-ymax)
# puts "Setting vrange ($options(-vmin),$options(-vmax))"
	$Mesh vrange $options(-vmin) $options(-vmax)
	if { $options(-colorbar) != "" } {
	    $options(-colorbar) vrange $options(-vmin) $options(-vmax)
	    $options(-colorbar) draw
	}
	$Mesh draw

	$XAxis draw
	$YAxis draw
    }

    method autoaxes {args} {
	# Determine axis limits.  If the y-range is empty then we
	# expand the limits to make a non-trivial range.
	# FIXME to keep data points from the edge of the
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

    method colormap {map} { 
	$Mesh colormap map 
	if { $options(-colorbar) != "" } {
	    $options(-colorbar) colormap map
	}
    }

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

    # Cycle through all mesh objects; if x,y is given then only
    # cycle object under x,y
    method cycle {} {
	foreach k [$Mesh list] { 
	    $Mesh raise $k
	    $Mesh draw
	    update
	}
    }

    method raise {id} {
	$Mesh raise $id
	$Mesh draw
    }

    method lower {id} {
	$Mesh lower $id
	$Mesh draw
    }

    method order {} {
 	return [$Mesh list]
    }

    method plot_demo {} { 
	$Mesh demo 
	if { $options(-legend) != "" } {
	    $options(-legend) add {Mesh 1} {Mesh 2}
	}
	$self configure -limits {0 10 -3 3}
    }

    method grid {state} {
	if { $state == "toggle" } {
	    $self configure -grid [string is false $options(-grid)]
	} else {
	    $self configure -grid $state
	}
	$self draw
    }

    method logdata {state} {
#puts "processing logdata"
	if { $state == "toggle" } {
	    $self configure -logdata [string is false $options(-logdata)]
	} else {
	    $self configure -logdata $state
	}
#puts "logdata is now $options(-logdata)"
# FIXME for some reason $self draw is invoked between here and the
# return to the caller.
    }

    method Logdata {op v} {
	set options(-logdata) [string is true $v]
	if { $options(-colorbar) != "" } {
	    $options(-colorbar) configure -logscale $v
	}
	$Mesh logdata $options(-logdata)
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

    method coords {x y} {
	set w [winfo width $win.c]
	set h [winfo height $win.c]
	set worldx [expr {($x+0.5)/$w}]
	set worldy [expr {($h-$y+0.5)/$h}]
	set xmin $options(-xmin)
	set xmax $options(-xmax)
	set ymin $options(-ymin)
	set ymax $options(-ymax)
	set graphx [expr {$worldx*($xmax-$xmin)+$xmin}]
	set graphy [expr {$worldy*($ymax-$ymin)+$ymin}]
	return [list $graphx $graphy]
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
	set w [toplevel .meshplot]
	meshlegend $w.cl
	meshplot $w.c -legend $w.cl
	meshplot $w.d
	grid $w.c $w.d -sticky news
	grid $w.cl - -sticky news
	grid rowconfigure $w 0 -w 1
	grid columnconfigure $w {0 1} -w 1
	
	wm geometry $w 500x400
	$w.c example
	$w.d plot_demo
	$w.c configure -grid on
    }

}

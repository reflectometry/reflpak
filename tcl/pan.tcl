if 0 {
package require BLT
set TKCON "C:\\Program Files\\tcl\\bin\\tkcon.tcl"

option add *Axis.ScrollIncrement 1 widgetDefault
pack [blt::graph .g] -fill both -expand yes
Blt_ZoomStack .g
.g elem create x -xdata { 1 2 3 4 5 } -ydata { 2 1 3 1 2 }

proc start_tkcon {} {
    if [winfo exists .tkcon] {
	wm deiconify .tkcon
	raise .tkcon
    } else {
	uplevel #0 [list source $::TKCON]
	# yuck --- for some reason source tkcon on 8.3.4 activestate
	# does not evaluate ::tkcon::Init.  Since I want to leave the
	# activestate installation as untouched as possible, I will
	# just have to work around it here.
	if {![winfo exists .tkcon]} { tkcon init }
	tkcon attach Main
	# click on the close window icon to hide the console
	wm protocol .tkcon WM_DELETE_WINDOW { tkcon hide }
    }
}
start_tkcon
}


namespace eval pan {

    variable cursor
    array set cursor {
	++ bottom_right_corner
	+= bottom_side
	+- bottom_left_corner
	=+ right_side
	== fleur
	=- left_side
	-+ top_right_corner
	-= top_side
	-- top_left_corner
    }

    proc graph_xview { w args } {
        foreach side { xaxis x2axis } {
	    foreach axis [$w $side use] {
	        eval $w axis view $axis $args
	    }
        }
    }

    proc graph_yview { w args } {
        foreach side { yaxis y2axis } {
	    foreach axis [$w $side use] {
	        eval $w axis view $axis $args
	    }
        }
    }

    proc dir { value } {
	if { $value > 0 } {
	    return +
	} elseif { $value < 0 } {
	    return -
	} else {
	    return =
	}
    }

    proc pan { action { w {} } { x {} } { y {} } } {
	variable rate
	variable step
	variable cursor
	variable pan
	switch $action {
	    init {
		# Create pan icon
		toplevel .pan -class Pan
		wm overrideredirect .pan 1
		wm withdraw .pan
		.pan conf -cursor $cursor(==)
		option add *Pan.Label.Background yellow widgetDefault
		option add *Pan.Label.Relief raised widgetDefault
		pack [label .pan.label -text Pan]
		# Get repeat rate
		option add *Pan.Rate 200 widgetDefault
		option add *Pan.Step 20 widgetDefault
		set rate [option get .pan rate Rate]
		set step [option get .pan step Step]
	    }
	    bind {
	        bind $w <ButtonPress-2>   { ::pan::pan start %W %X %Y }
                bind $w <ButtonRelease-2> { ::pan::pan stop %W }
                bind $w <B2-Motion>       { ::pan::pan move %W %X %Y }
	    }
	    start {
		if { [info exists pan($w,x)] } {
		    set pan($w,motion) 1 ;# stop only works after motion
		    pan stop $w
		} else {
		    if { [llength $x] == 0 } {
			# default x,y from the current mouse position
			foreach { x y } [winfo pointerxy .] break
		    }
		    set pan($w,x) $x
		    set pan($w,y) $y
		    set pan($w,v) 0
		    set pan($w,h) 0
		    set pan($w,cursor) [$w cget -cursor]
		    set pan($w,focus) [focus]
		    $w conf -cursor $cursor(==)
		    wm geometry .pan +[expr {$x-[winfo width .pan]/2}]+[expr {$y-[winfo height .pan]/2}]
		    wm deiconify .pan
		    raise .pan
		    after 0 "::pan::pan step $w"
		    bind .pan <Motion>        [list ::pan::pan move $w %X %Y]
		    bind .pan <ButtonPress>   [list set ::pan::pan($w,motion) 1]
		    bind .pan <ButtonRelease> [list ::pan::pan stop $w]
		    grab set .pan
		    # after 5000 { grab release .pan }
		}
	    }
	    move {
		if { [info exists pan($w,x)] } {
		    set v [expr {$y - $pan($w,y)}]
		    set h [expr {$x - $pan($w,x)}]
		    set vstep [expr {abs($v)/$step}]
		    set hstep [expr {abs($h)/$step}]
		    if {$v>=0} { set vsign 1 } { set vsign -1 }
		    if {$h>=0} { set hsign 1 } { set hsign -1 }
		    # puts "$v $vstep $vsign $h $hstep $hsign"
		    set pan($w,v) [expr {$vstep*$vsign}]
		    set pan($w,h) [expr {$hstep*$hsign}]
		    $w conf -cursor $cursor([dir $pan($w,v)][dir $pan($w,h)])
		    set pan($w,motion) 1
		}
	    }
	    step {
		if { [info exists pan($w,x)] } {
		    graph_xview $w scroll $pan($w,h) units
		    graph_yview $w scroll $pan($w,v) units
		    after $rate "::pan::pan step $w"
		}
	    }
	    stop {
		if { [info exists pan($w,motion)] } {
		    grab release .pan
		    wm withdraw .pan
		    $w conf -cursor $pan($w,cursor)
		    focus $pan($w,focus)
		    foreach el [array names pan "$w,*"] { unset pan($el) }
		    after cancel "::pan::pan step $w"
		}
	    }
	}
    }

    catch { pan init } ;# allow file to be sourced multiple times
}

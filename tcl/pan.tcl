 # Usage:  
 #
 #   pan::pan bind $w
 #
 #   Add pan capabilities to a tcl/tk widget, including BLT graphs.
 #
 #   Either middle click to start pan, move the mouse in the direction you
 #   want to pan followed by any click to stop, or middle press to start
 #   pan, move the mouse in the direction you want to pan followed by middle
 #   release to stop.  There is a timeout which stops panning after 10 seconds
 #   of no mouse movement.
 #
 #   pan::pan start $w
 #
 #   Start panning the widget from current mouse position.  Use this for
 #   example from a context sensitive menu with an entry for panning.
 #
 # Resources: 
 #
 #   The .pan widget is a toplevel undecorated window of class Pan
 #   which contains a label.  The single .pan widget is shared by
 #   all graphs.  You can control its features using the usual label
 #   resources, indicated by *Pan.Label*.
 #
 #   You can control the pan repeat rate (milliseconds) and increment using
 #      *Pan.Rate: 200
 #      *Axis.ScrollIncrement: 1
 #   The step size is scaled linearly with the number of pixels.  
 #   Pan.Accel determines the number of pixels away to increase 
 #   speed by one scrollincrement per repeat.
 #      *Pan.Accel: 20
 #   Since we have an application grab, we also have a timeout set.
 #      *Pan.Timeout: 10000
 #   Alternatively, you can set the variables ::pan::rate, ::pan::accel
 #   and ::pan::timeout
 #
 #   Axis.ScrollIncrement is a BLT resource. It is set to 1 at the 
 #   widgetDefault level when pan.tcl is sourced.  Be sure to source
 #   pan.tcl before creating your graphs.
 #
 #   Pan is attached to the middle mouse button.  You could for example
 #   attach it to button 1 using the following in lieu of pan::pan bind
 #
 #      bind $w <ButtonPress-1>   { ::pan::pan start %W %X %Y }
 #      bind $w <ButtonRelease-1> { ::pan::pan stop %W }
 #      bind $w <B1-Motion>       { ::pan::pan move %W %X %Y }
 #
 # Test using
 #    $wish pan.tcl
 # zoom into a region with the left button and use the middle button to pan.
 #
 # To do:
 #    The pan widget and the cursors are not as pretty as they might be.
 #    Keyboard support --- bind arrow keys to cursor warping events.

 # This program is in the public domain.
 #
 # Please edit this as you see fit, but update the changelog.
 #
 # 2003-05-29 Paul Kienzle <pkienzle at users sf net>
 #    * initial release
 namespace eval pan {

    # use these cursors to indicate pan direction
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

    # internal: xview and yview for BLT graphs
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

    # internal: convert a direction to a cursor code
    proc dir { value } {
	if { $value > 0 } {
	    return +
	} elseif { $value < 0 } {
	    return -
	} else {
	    return =
	}
    }

    # pan actions
    proc pan { action { w {} } { x {} } { y {} } } {
	variable timeout
	variable rate
	variable accel
	variable cursor
	variable pan
	switch $action {
	    init { # initialize the pan icon (only called once)
		# Create pan icon
		toplevel .pan -class Pan
		wm overrideredirect .pan 1
		wm withdraw .pan
		.pan conf -cursor $cursor(==)
		option add *Pan.Label.Background yellow widgetDefault
		option add *Pan.Label.Relief raised widgetDefault
		pack [label .pan.label -text Pan]

		# Get resources
		foreach {var val} { rate 200 accel 20 timeout 10000 } {
		    if {![info exists $var]} {
			set tvar [string totitle $var]
			option add *Pan.$tvar $val widgetDefault
			set $var [option get .pan $var $tvar]
		    }
		}

		# Make sure future graphs use a small increment
		option add *Axis.ScrollIncrement 1 widgetDefault
	    }
	    bind { # bind panning to a widget
	        bind $w <ButtonPress-2>   { ::pan::pan start %W %X %Y }
                bind $w <ButtonRelease-2> { ::pan::pan stop %W }
                bind $w <B2-Motion>       { ::pan::pan move %W %X %Y }
	    }
	    start { # start panning
		if { [info exists pan($w,x)] } { return	}
		# if no x-position, start from current cursor --- this
		# can happen if panning is triggered by something other
		# than the mouse bindings, such as a context sensitive
		# menu.
		if { [llength $x] == 0 } {
		    foreach { x y } [winfo pointerxy .] break
		}
		# remember the initial state
		set pan($w,x) $x
		set pan($w,y) $y
		set pan($w,v) 0
		set pan($w,h) 0
		set pan($w,cursor) [$w cget -cursor]
		set pan($w,focus) [focus]
		# set the cursor
		$w conf -cursor $cursor(==)
		.pan conf -cursor $cursor(==)
		# display the pan icon
		set xpos [expr {$x-[winfo width .pan]/2}]
		set ypos [expr {$y-[winfo height .pan]/2}]
		wm geometry .pan +$xpos+$ypos
		wm deiconify .pan
		raise .pan
		# associate panning actions with the current widget
		bind .pan <Motion>      [list ::pan::pan move $w %X %Y]
		bind .pan <ButtonPress> [list set ::pan::pan($w,motion) 1]
		bind .pan <ButtonRelease> [list ::pan::pan stop $w]
		grab set .pan
		# start panning --- don't really need to start until
		# after the mouse moves, but it doesn't seem to hurt
		# anything starting immediately
		after 0 [list ::pan::pan step $w]
		# set timeout
		after $timeout [list ::pan::pan cancel $w]
	    }
	    move { # mouse motion
		if { ![info exists pan($w,x)] } { return }
		# compute new step size
		set v [expr {$y - $pan($w,y)}]
		set h [expr {$x - $pan($w,x)}]
		set vstep [expr {abs($v)/$accel}]
		set hstep [expr {abs($h)/$accel}]
		if {$v>=0} { set vsign 1 } { set vsign -1 }
		if {$h>=0} { set hsign 1 } { set hsign -1 }
		set pan($w,v) [expr {$vstep*$vsign}]
		set pan($w,h) [expr {$hstep*$hsign}]
		# puts "$v $vstep $vsign $h $hstep $hsign"
		# set new cursor
		$w conf -cursor $cursor([dir $pan($w,v)][dir $pan($w,h)])
		.pan conf -cursor $cursor([dir $pan($w,v)][dir $pan($w,h)])
		# remember that there is motion --- if there is no motion
		# between press and release, then it is a click action and
		# the pan icon stays until the next click.
		set pan($w,motion) 1
		# reset timeout
		after cancel [list ::pan::pan cancel $w]
		after $timeout [list ::pan::pan cancel $w]
	    }
	    step { # do the panning
		if { ![info exists pan($w,x)] } { return }
		# handle blt::graph specially --- perhaps want to generalize
		# so that we can add functions for all widgets that do not
		# support xview/yview.
		if { [winfo class $w] == "Graph" } {
		    graph_xview $w scroll $pan($w,h) units
		    graph_yview $w scroll $pan($w,v) units
		} else {
		    $w xview scroll $pan($w,h) units
		    $w yview scroll $pan($w,v) units
		}
		# program the next step
		after $rate [list ::pan::pan step $w]
	    }
	    stop { # button release
		# if the mouse hasn't moved yet, don't cancel panning
		if { [info exists pan($w,motion)] } { ::pan::pan cancel $w }
	    }
	    cancel { # cancel panning for whatever reason
		if { ![info exists pan($w,x)] } { return }
		# restore state
		grab release .pan
		wm withdraw .pan
		$w conf -cursor $pan($w,cursor)
		focus $pan($w,focus)
		# clear variables
		foreach el [array names pan "$w,*"] { unset pan($el) }
		# stop panning update
		after cancel [list ::pan::pan step $w]
		# stop timeout
		after cancel [list ::pan::pan cancel $w]
	    }
	}
    }

    # initialize pan widget
    # use catch so that the file can be sourced multiple times
    catch { pan init }
 }


 # Test code
 if {[info exists argv0] && [file tail [info script]]==[file tail $argv0]} {
    catch {
	# add a blt graph if blt is available
	package require BLT
	blt::graph .g
	.g elem create x -xdata { 1 2 3 4 5 } -ydata { 2 1 3 1 2 }
	Blt_ZoomStack .g
	pan::pan bind .g
	grid .g - -sticky news
    }

    # add a text widget
    text .t -width 10 -height 5 -wrap no \
	    -xscrollcommand { .h set } -yscrollcommand { .v set }
    scrollbar .h -orient h -command { .t xview }
    scrollbar .v -orient v -command { .t yview }
    .t insert end "1 This is a bunch of text which I am using to test the panning capabilities\n2 of the text widget.\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16\n17\n18\n19\n20\n21\n22 end of text ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- really!"

    pan::pan bind .t
    grid .t x -sticky news
    grid .h x -sticky ew
    grid .v -row 1 -column 1 -sticky ns
    grid columnconf . 0 -weight 1
 }
    
 if 0 {
     # Handy-dandy debugging tools, if you have them
     catch { 
	 source /usr/local/bin/tkcon 
	 if {![winfo exists .tkcon]} { tkcon init }
	 tkcon attach Main
     }
     catch { 
	 package require tablelist 
	 source [file join $::tablelist::library demos browse.tcl]
	 ::demo::displayChildren .
     }
 }

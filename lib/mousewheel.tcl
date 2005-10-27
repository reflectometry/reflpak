 # This program is in the public domain.
 #
 # Please edit this as you see fit, but update the changelog.
 #
 # 2005-10-27 Paul Kienzle <pkienzle at users sf net>
 #    * initial release

 # mousewheel bind w
 #   Convert <MouseWheel> events anywhere in a window to <<Wheel>> events 
 #   on individual widgets.  Unlike <MouseWheel> events, <<Wheel>> events
 #   can be received by a widget which does not have the focus.
 #
 #   Tk does not allow -delta to be specified for virtual events.  Instead
 #   the most recent delta is stored in ::mousewheel::delta($w).
 #
 #   On unix, button-4 and button-5 are converted to <MouseWheel> events.
 #
 # mousewheel step w
 #   Get ::mousewheel::delta as a step size.  This scales delta by 1/120 
 #   and cubes it so that fast motion is accelerated.
 proc mousewheel { action w } {
    switch -- $action {
 	bind {
	    bind [winfo toplevel $w] <MouseWheel> \
		{ mousewheel::doevent %W %X %Y %D }
	}
	step {
	    return [mousewheel::step $w] 
	}
	default {
	    error "mousewheel bind|step w"
	}
    }
 }


 namespace eval mousewheel {

    # Convert unix Button-4/Button-5 to MouseWheel events.  Collect events
    # in 200 ms intervals so that we can do speed estimates.
    bind all <Button-4> [namespace code {collect  1 %W %X %Y %x %y}]
    bind all <Button-5> [namespace code {collect -1 %W %X %Y %x %y}]
    variable afterid {}
    variable factor 0

    proc collect {n W X Y x y} {
	variable factor
	variable afterid
	if {$afterid eq {}} {
	    set factor $n
	    set afterid [after 200 [namespace code "trigger $W $X $Y $x $y"]]
	} else {
	    incr factor $n
	}
    }
    proc trigger {W X Y x y} {
	variable afterid {}
        variable factor
	event generate $W <MouseWheel> \
	    -delta [expr {$factor*120}] -rootx $X -rooty $Y -x $x -y $y
    }


    # Convert <MouseWheel> to <<Wheel>> event.
    proc doevent {W X Y D} {
	set w [winfo containing -displayof $W $X $Y]
	if { $w ne "" } {
	    set x [expr {$X-[winfo rootx $w]}]
	    set y [expr {$Y-[winfo rooty $w]}]
	    variable delta
	    set delta($w) $D
	    event generate $w <<Wheel>> -rootx $X -rooty $Y -x $x -y $y
	}
    }

    # Return step size from delta
    proc step {w} {
	variable delta
	return [expr {int(pow($delta($w)/120,3))}]
    }
 }

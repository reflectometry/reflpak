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
		{ mousewheel::collect %W %X %Y %D }
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

    variable afterid {}
    variable factor 0

    proc collect {W X Y D} {
	variable factor
	variable afterid
	if {$afterid eq {}} {
	    set factor $D
	    set afterid [after 200 [namespace code "trigger $W $X $Y"]]
	} else {
	    incr factor $D
	}
    }

    # Convert <MouseWheel> to <<Wheel>> event.
    proc trigger {W X Y} {
	variable afterid {}
        variable factor
	set w [winfo containing -displayof $W $X $Y]
	if { $w ne "" } {
	    set x [expr {$X-[winfo rootx $w]}]
	    set y [expr {$Y-[winfo rooty $w]}]
	    variable delta
	    set delta $factor
	    event generate $w <<Wheel>> -rootx $X -rooty $Y -x $x -y $y
	}
    }

    # Return step size from delta
    proc step {w} {
	variable delta
	return [expr {int(pow($delta/120,3))}]
    }
 }


 # Convert unix Button-4/Button-5 to MouseWheel events.  Collect events
 # in 200 ms intervals so that we can do speed estimates.
 bind all <Button-4> { 
    event generate %W <MouseWheel> -delta 120 -rootx %X -rooty %Y -x %x -y %y
 }
 bind all <Button-5> {
    event generate %W <MouseWheel> -delta -120 -rootx %X -rooty %Y -x %x -y %y
 }


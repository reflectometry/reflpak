namespace eval graph {


# Bindings and options for graph_select and graph_select_list
bind graphselect <Motion> [namespace code {_select_activate %W %x %y}]
bind graphselect <Button-1> [namespace code {_select_choose %W %x %y; break}]
bind graphselect <Button-3> [namespace code {_select_cancel %W; break}]
option add *Graph.selectText.Coords {-Inf -Inf} widgetDefault
option add *Graph.selectText.Anchor sw widgetDefault
option add *Graph.selectText.Under 1 widgetDefault


# HELP developer
# Usage: graph::select w {x1 y1 name1 idx1} {x2 y2 name2 idx2} ...
#
# Lets the user select a number of points off a graph, saving the result
# in the named variables x1 y1 name1, x2 y2 name2, etc.  Uses the
# activeLine pen to indicate the symbol under the mouse.
#
# Any of the names can be omitted using {} instead.  The label for the
# point is x, y, name or index, whichever is the first non-blank label
#
# Returns true if points were selected, false otherwise
#
# Examples
#
# graph::select .graph x_min x_max
#   selects an x-range and stores it in x_min, x_max.
# graph::select .graph {x y}
#   selects a single point and stores it in x, y
# graph::select .graph {x y name idx}
#   selects a single point and stores it in x, y.  The name of the line
#   element containing the point is stored in name and the index is stored
#   in idx

# TODO restrict points to a given subset of the available elements
# TODO restrict points to the first line selected
# TODO restrict selection to entire lines
# TODO restrict selection to distinct points
proc select { w args } {
    # Simple argument checking
    set fn "[namespace current]::select"
    if {[llength $args] == 0} { 
	error "$fn expects graph {x1 y1 name1 idx1} ..." 
    }

    # Determine the names for each point
    set names {}
    foreach p $args {
	if {[llength $p] < 1 || [llength $p] > 4} {
	    error "$fn expects graph {x1 y1 name1 idx1} ..."
	}
        # find first non-blank name and append it to list
        set name [lindex $p [lsearch $p ?*]]
	if { $name ne "" } {
	    lappend names $name
	} else {
	    error "$fn expects one of x,y,name,idx to be non-blank"
	}
    }

    # Select the points
    set selected [_select_points $w $names]

    # Assign the points to the labels
    if {[llength $selected] == [llength $args]} { 
	_assign_points $args $selected
	return 1
    } else {
	return 0
    }
}


# HELP developer
# Usage: graph::select_list w ?n|names
#
# Selects a set of points.  When complete var is set to {{x1 y1 name1 idx1}
# ... {xk yk namek idxk}}.  Use vwait var to process the data after all
# selections are complete.
proc select_list { w {names {}}} {

    if {[llength $names] == 1} {
	set n [expr {$names}]
	set names {}
	for { set i 1 } { $i <= $n } { incr i } { lappend names $i }
    }

    # Select the points
    set points [_select_points $w $names]

    # If getting a set of points, return the set
    if {[llength $names] == 0 || [llength $names] == [llength $points]} {
	return $points
    } else {
	return {}
    }

}

proc _select_points {w names} {
    variable info

    # Keep track of the number of points needed
    set info($w,names) $names
    set info($w,n) [llength $names]
    set info($w,pts) {}

    #set info($w,focus) [focus]
    # ptrace "adding tag to [bindtags $w] for $w"
    bindtags $w [concat graphselect [bindtags $w]]
    # XXX FIXME XXX is there a way to save and restore stacking order?
    raise [winfo toplevel $w]
    $w marker create text -name selectText

    if { $info($w,n) > 0 } {
	$w marker conf selectText \
	    -text "Click to select [lindex $names 0]\nRight-Click to cancel"
    } else {
	$w marker conf selectText \
	    -text "Click to select next\nRight-Click to end selection"
    }

    # grab set $w

    # Wait until done
    vwait [namespace current]::info($w,done)

    set points $info($w,pts)
    array unset info $w,*
    return $points
}


# HELP internal
# Usage: _assign_points points selected
#
# Ones all points have been selected, assign them to the corresponding
# variables
proc _assign_points {points selected} {
    foreach p $points s $selected {
	foreach {vx vy vel vidx} $p {x y el idx} $s break
	if { $vx ne "" } { upvar 2 $vx v; set v $x }
	if { $vy ne "" } { upvar 2 $vy v; set v $y }
	if { $vel ne "" } { upvar 2 $vel v; set v $el }
	if { $vidx ne ""} { upvar 2 $vidx v; set v $idx }
    }
}

# HELP internal
# Usage: _select_activate w x y
#
# Highlights the point of the the graph under cursor x,y.
# Callback for the motion event.
proc _select_activate {w x y} {
    # puts _select_activate
    variable info

    # Activate the currently selected points
    eval $w element deactivate [$w elem names]
    foreach line [array names info "$w,el:*"] {
	set el [string map [list "$w,el:" {}] $line]
	# puts "activating $info($line) in $el"
	eval $w element activate $el $info($line)
    }

    # Find nearest element
    # XXX FIXME XXX -along doesn't seem to work in blt 2.4z. When it is fixed,
    # uncomment it where it occurs in this file and in viewrun.tcl.  May need
    # the interpolate keyword as well.
    $w element closest $x $y where -halo 1i ;#\
	    -along [option get $w interpolate Interpolate]

    # Highlight the nearest element
    if { [info exists where(x)] } {
        # XXX FIXME XXX the use of int(idx) is completely bogus
        # but for some reason on Windows the element at index 10
        # sometimes fails in Tcl_ExprLong(), even when used in
        # a context such as 0+10+0.  I cannot reproduce this
        # behaviour outside of reflred, but within reflred it is
        # consistent across graphs.  Go figure!
	#ptrace "activating $where(name) $where(index)"
	if [info exists info($w,el:$where(name))] {
	    eval $w element activate $where(name) $info($w,el:$where(name)) int($where(index))
        } else {
	    $w elem activate $where(name) int($where(index))
        }
    }
}

# HELP internal
# Usage: _select_choose w x y
#
# Appends the point under x,y to the list of selected points.
# Callback for the select event.
proc _select_choose {w x y} {
    # puts _select_choose
    $w element closest $x $y where -halo 1i ;# \
	    -interpolate [option get $w.Interpolate]
    if { ![info exists where(x)] } { return }

    variable info
    lappend info($w,pts) [list $where(x) $where(y) $where(name) $where(index)]
    lappend info($w,el:$where(name)) [expr $where(index)]
    set collected [llength $info($w,pts)]
    # puts "$collected: $info($w,pts)"
    if { $collected == $info($w,n) } { 
	_select_done $w
    } else {
	set pointname [lindex $info($w,names) $collected]
	if { $info($w,n) > 0 } {
	    $w marker conf selectText \
		-text "Click to select $pointname\nRight-Click to cancel"
	}
    }
}


# HELP internal
# Usage: _select_cancel $w
#
# Callback for the abort event.
proc _select_cancel {w} {
    # puts _select_cancel
    _select_done $w
}

# HELP internal
# Usage: _select_done $w
#
# Stop collecting points for the selected list.  Called from
# _select_cancel or _select_choose
proc _select_done {w} {
    # puts _select_done
    variable info
    $w marker delete selectText
    bindtags $w [_ldelete [bindtags $w] graphselect]
    #grab release $w
    catch {
	#raise [winfo toplevel $info($w,focus)]
	#focus $info($w,focus)
    }
    eval $w element deactivate [$w elem names]
    set info($w,done) 1
}

# Delete a particular value from a list
proc _ldelete { list value } {
    set index [ lsearch -exact $list $value ]
    if { $index >= 0 } {
        return [lreplace $list $index $index]
    } else {
        return $list
    }
}

}


# Test code
if {[info exists argv0] && [file tail [info script]]==[file tail $argv0]} {

    option add *Graph.activeLine.Outline red widgetDefault
    option add *Graph.activeLine.Symbol splus widgetDefault
    option add *Graph.Element.Pixels 2 widgetDefault
    option add *Graph.Element.Outline darkblue widgetDefault
    
    package require BLT
    pack [blt::graph .g] -fill both -expand yes
    .g elem create a -xdata {1 2 3 4 5 6 7} -ydata {2 3 1 4 2 1 7}
    .g elem create b -xdata {7 8 9 10} -ydata {2 3 1 5} -color cyan
    if {[graph::select .g {x1 y1} {{} {} name2 idx2}]} {
	puts "x1 $x1 y1 $y1 name2 $name2 idx2 $idx2"
    }
    puts "Three items: [graph::select_list .g 3]"
    puts "? items: [graph::select_list .g]"
    puts "first second third: [graph::select_list .g {first second third}]"
    exit
}

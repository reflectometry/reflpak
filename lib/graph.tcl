# FIXME: put this all in a graph namespace to hide private functions

#========================= BLT graph functions =====================
# HELP developer
# Usage: zoom w on|off
#
# To suppress the zoom action on the graph when you are twiddling the
# marker and legend, be sure to call zoom off on the the Button-1 
# event and zoom on on the ButtonRelease-1 event for the marker/legend.
# XXX FIXME XXX there must be a better way to do this
proc zoom { w state } {
    switch $state {
	"off" { blt::RemoveBindTag $w zoom-$w }
	"on" { blt::AddBindTag $w zoom-$w }
	default { error "{on|off}" }
    }
}


# HELP developer
# Usage: active_legend graph ?callback
#
# Highlights the legend entry when the user mouses over the line in the
# graph.  Toggles the line when the user clicks on the legend entry.
#
# If a callback is provided it will be called after showing/hiding with
#    eval callback graph elem ishidden
# where ishidden is the new state of the element.
#
# To highlight the current line when the user mouses over its
# legend entry, add the following:
proc active_legend {w {command ""}} {
    set ::legend_command($w) $command
    $w legend conf -hide 0
    $w legend bind all <Button-1> { zoom %W off ; legend_toggle %W }
    $w legend bind all <ButtonRelease-1> { zoom %W on }
    $w elem bind all <Enter> { %W legend activate [%W elem get current] }
    $w elem bind all <Leave> { %W legend deactivate [%W elem get current] }
    $w legend bind all <Enter> { %W elem activate [%W legend get current] }
    $w legend bind all <Leave> { %W elem deactivate [%W legend get current] }
}

# Default options for legend
option add *Graph.LegendHide {-labelrelief flat} widgetDefault
option add *Graph.LegendShow {-labelrelief raised} widgetDefault
option add *Graph.Legend.activeRelief raised widgetDefault
option add *Graph.Element.labelRelief raised widgetDefault


# HELP internal
# Usage: legend_toggle w
#
# Hide/show the element associated with the current legend in the window.
# Callback for the active_legend toggle binding.
proc legend_toggle {w} {
    # elem conf -hide now hides the legend entry.  Instead of hiding
    # the line, we will replace its x-vector with _legend_hidden, and set
    # the element bindtag to {legend_hidden xdata-value}.  AFAICT, it won't
    # hurt anything since the bind tag is never bound, and it has the
    # advantage over a global variable in that it will be freed with the
    # element.
    set line [$w legend get current]
    legend_set $w $line [legend_hidden $w $line]
}

# HELP developer
# Usage legend_hidden w line
#
# Return true if the line is hidden
proc legend_hidden {w line} {
    return [expr {[string equal ::_legend_hidden [$w elem cget $line -xdata]]}]
}

# HELP developer
# Usage: legend_set w line on|off
#
# Hide or show a particular graph line.  Call the legend callback specified
# with active_legend with the widget line and state.
proc legend_set {w line state} {
    set tags [$w elem cget $line -bindtags]
    set idx [lsearch $tags legend_hidden*]
    set hidden [legend_hidden $w $line]
    if { [string is true $state] } {
	if { !$hidden } { return }
	set hide 0
	# assert { $idx >= 0 }
	if { $idx >= 0 } {
	    eval $w elem conf $line [lrange [lindex $tags $idx] 1 end]
	}
	eval $w elem conf $line [option get $w legendShow LegendShow]
    } else {
	if { $hidden } { return }
	blt::vector create ::_legend_hidden
	set hide 1
	set hiddentag [list legend_hidden \
		-xdata [$w elem cget $line -xdata] \
		-color [$w elem cget $line -color] \
		-outline [$w elem cget $line -outline] \
		-fill [$w elem cget $line -fill] ]
	$w elem conf $line -xdata ::_legend_hidden
	$w elem conf $line -color [$w cget -background]
	$w elem conf $line -outline [$w cget -background]
	$w elem conf $line -fill [$w legend cget -background]
	if { $idx >= 0 } {
	    set tags [lreplace $tags $idx $idx $hiddentag]
	} else {
	    set tags [linsert $tags 0 $hiddentag]
	}
	$w elem conf $line -bindtags $tags
	eval $w elem conf $line [option get $w legendHide LegendHide]
    }
    if ![string equal {} $::legend_command($w)] {
	eval $::legend_command($w) $w $line [expr {!$hidden}]
    }
}

# HELP developer
# Usage: active_axis graph axis ?callback
#
# Makes the specified axis for the graph "active" so that left click
# toggles log/linear scaling and right click hides/shows all the lines
# associated with that axis.
#
# For right-click to work, you must be using active_legend.
#
# If a callback is provided it will be called after hiding/showing with
#    eval callback graph axis ishidden
# where ishidden is the new state of the axis.  There is no
# callback when logscale is changed.
proc active_axis {w axis} {
    $w axis bind $axis <Enter> {
	set axis [%W axis get current]
	%W axis configure $axis -background lightblue2
    }
    $w axis bind $axis <Leave> {
	set axis [%W axis get current]
	%W axis configure $axis -background ""
    }
    $w axis bind $axis <1> {
	set axis [%W axis get current]
	if { [string is true [%W axis cget $axis -logscale]] } {
	    set logscale 0
	} else {
	    set logscale 1
	}
	%W axis configure $axis -logscale $logscale
    }

    $w axis bind $axis <3> { axis_toggle %W }
}

# HELP internal
# Usage: axis_toggle w
#
# Hide/show all elements associated with an axis.
# Callback for the active_axis toggle action.
proc axis_toggle {w} {
    set axis [$w axis get current]
    # find all elements which use the current axis
    set map {}
    foreach ord { x y } {
	set ordaxes [concat [$w ${ord}axis use] [$w ${ord}2axis use]]
	if { [lsearch $ordaxes $axis] >= 0 } {
	    foreach elem [$w elem names] {
		if {[string equal $axis [$w elem cget $elem -map${ord}]]} {
		    lappend map $elem
		}
	    }
	}
    }
    # find if any of these elements are hidden
    set state 0
    foreach elem $map {	if {[legend_hidden $w $elem]} { set state 1; break } }

    # hide/show all elements associated with the axis
    foreach elem $map { legend_set $w $elem $state }
}

# HELP developer
# Usage: graph_select w {x1 y1 name1} {x2 y2 name2} ...
#
# Lets the user select a number of points off a graph, saving the result
# in the named variables x1 y1 name1, x2 y2 name2, etc.  Uses the
# activeLine pen to indicate the symbol under the mouse.
#
# Any of the names can be omitted using {} instead.  E.g.,
#    graph_select .graph x_min x_max
# selects an x-range and stores it in ::x_min, ::x_max.
#    graph_select .graph {x y}
# selects a single point and stores it in ::x, ::y
#    graph_select .graph {x y name idx}
# selects a single point and stores it in ::x, ::y.  The name of the line
# element containing the point is stored in ::name and the index is stored
# in ::idx
#
# TODO should be able to restrict the points to a subset of the
# available elements.
proc graph_select { w args } {
    set ::graph_select(focus,$w) [focus]
    set ::graph_select(points,$w) $args
    # ptrace "adding tag to [bindtags $w] for $w"
    bindtags $w [concat graph_select [bindtags $w]]
    # XXX FIXME XXX is there a way to save and restore stacking order?
    raise [winfo toplevel $w]
    $w marker create text -name selectPointText \
	    -text "Click to select [lindex $args 0]\nRight-Click to cancel"
    grab set $w
}

# Bindings and options for graph_select and graph_select_list
bind graph_select <Motion> {graph_select_motion %W %x %y}
bind graph_select <Button-1> {graph_select_press %W %x %y; break}
bind graph_select <B1-ButtonRelease> {graph_select_release %W %x %y; break}
bind graph_select <Button-3> { break }
bind graph_select <B3-ButtonRelease> {graph_select_cancel %W; break}
option add *Graph.selectPointText.Coords {-Inf -Inf} widgetDefault
option add *Graph.selectPointText.Anchor sw widgetDefault
option add *Graph.selectPointText.Under 1 widgetDefault


# HELP developer
# Usage: graph_select_list w var
#
# Selects a set of points.  When complete var is set to {{x1 y1 name1 idx1}
# ... {xk yk namek idxk}}.  Use vwait var to process the data after all
# selections are complete.
proc graph_select_list { w var {n 0}} {
    set ::graph_select(focus,$w) [focus]
    set ::graph_select(listname,$w) $var
    set ::graph_select(list,$w) {}
    set ::graph_select(listn,$w) $n
    # ptrace "adding tag to [bindtags $w] for $w"
    bindtags $w [concat graph_select [bindtags $w]]
    # XXX FIXME XXX is there a way to save and restore stacking order?
    raise [winfo toplevel $w]
    $w marker create text -name selectPointText \
	    -text "Click to select the next $var\nRight-Click to cancel"
    grab set $w
}

# HELP internal
# Usage: graph_select_motion w x y
#
# Highlights the point of the the graph under cursor x,y.
# Callback for the motion event during select/select_list.
proc graph_select_motion {w x y} {
    # ptrace
    eval $w element deactivate [$w elem names]
    foreach line [array names ::graph_select "active*,$w"] {
	eval $w element activate [string map [list active {} ",$w" {}] $line] $::graph_select($line)
    }
    # XXX FIXME XXX -along doesn't seem to work in blt 2.4z. When it is fixed,
    # uncomment it where it occurs in this file and in viewrun.tcl.  May need
    # the interpolate keyword as well.
    $w element closest $x $y where -halo 1i ;#\
	    -along [option get $w interpolate Interpolate]
    if { [info exists where(x)] } {
        # XXX FIXME XXX the use of int(idx) is completely bogus
        # but for some reason on Windows the element at index 10
        # sometimes fails in Tcl_ExprLong(), even when used in
        # a context such as 0+10+0.  I cannot reproduce this
        # behaviour outside of reflred, but within reflred it is
        # consistent across graphs.  Go figure!
	#ptrace "activating $where(name) $where(index)"
	if [info exists ::graph_select(active$where(name),$w)] {
	    eval $w element activate $where(name) $::graph_select(active$where(name),$w) int($where(index))
        } else {
	    $w elem activate $where(name) int($where(index))
        }
    }
}

# HELP internal
# Usage: graph_select_press w x y
#
# Appends the point under x,y to the list of selected points.
# Callback for the select event during select/select_list.
proc graph_select_press {w x y} {
    $w element closest $x $y where -halo 1i ;# \
	    -interpolate [option get $w.Interpolate]
    if { ![info exists where(x)] } { return }
    if { [info exists ::graph_select(points,$w)] } {
	#ptrace "setting [lindex $::graph_select(points,$w) 0] $where(x)"
	foreach {x y el i} [lindex $::graph_select(points,$w) 0] break
	set ::graph_select(points,$w) [lrange $::graph_select(points,$w) 1 end]
	if {![string equal $x {}]}  { uplevel \#0 [list set $x $where(x)] }
	if {![string equal $y {}]}  { uplevel \#0 [list set $y $where(y)] }
	if {![string equal $el {}]} { uplevel \#0 [list set $el $where(name)] }
	if {![string equal $i {}]}  { uplevel \#0 [list set $i $where(index)] }
	lappend ::graph_select(active$where(name),$w) [expr $where(index)]
    } else {
	lappend ::graph_select(list,$w) \
	    [list $where(x) $where(y) $where(name) $where(index)]
    }
}

# HELP internal
# Usage: graph_select_release w x y
#
# Prepare for the next point in the selected list.
# Callback for the select event during select/select_list.
proc graph_select_release {w x y} {
    # FIXME why are press and release handled separately?
    
     #ptrace "with $::graph_select(points,$w)"
    if {[info exists ::graph_select(list,$w)]} {
	set n $::graph_select(listn,$w)
	if {$n > 0 && [llength $::graph_select(list,$w)] >= $n} {
	    graph_select_cancel $w
	}
    } elseif {[llength $::graph_select(points,$w)] == 0} {
	graph_select_cancel $w
    } else {
	$w marker conf selectPointText \
		-text "Click to select [lindex $::graph_select(points,$w) 0]\nRight-Click to cancel"
    }

}

# HELP internal
# Usage: graph_select_cancel
#
# Stop collecting points for the selected list.
# Callback for the abort event during select/select_list.
proc graph_select_cancel {w} {
    #ptrace
    $w marker delete selectPointText
    eval $w element deactivate [$w elem names]
    bindtags $w [ldelete [bindtags $w] graph_select]
    grab release $w
    catch {
	raise [winfo toplevel $::graph_select(focus,$w)]
	focus $::graph_select(focus,$w)
    }
    # If getting a set of points, return the set
    if {[info exists ::graph_select(list,$w)]} {
	uplevel \#0 \
	    [list set $::graph_select(listname,$w) $::graph_select(list,$w)]
    }
    array unset ::graph_select *,$w
}

# HELP internal
# Usage: graph_activate_menu w X Y x y
#
# Post the graph context sensitive menu at position X,Y (screen) x,y (window)
# Callback for graph menu event.
proc graph_activate_menu {w X Y x y} {
    if {[$w inside $x $y]} {
        set ::active_graph($w,marker) [$w marker get current]
        $w element closest $x $y where
        if [info exists where(x)] {
            set ::active_graph($w,element) $where(name)
            set ::active_graph($w,index) $where(index)
        } else {
            set ::active_graph($w,element) {}
            set ::active_graph($w,index) {}
        }
        tk_popup $w.menu $X $Y 1
    }
}

# Bindings for active_graph
# bind zoom-$w <ButtonPress-3> {}
bind active_graph <ButtonPress-3> { graph_activate_menu %W %X %Y %x %y; break }
bind active_graph <Motion> { graph_motion %W %x %y }
bind active_graph <Leave> { graph_motion_clear %W }

# HELP internal
# Usage: graph_motion_clear w
#
# Clear the info associated with the graph cursor
# Callback for the graph leave event.
#
# TODO make sure crosshairs disappear when cursor leaves graph
proc graph_motion_clear {w} {
    # Determine if this window has a message bar
    # FIXME: consider using floating window if no message bar
    if { [info exists ::active_graph($w,message)] } {
	set wmsg $::active_graph($w,message)
    } elseif { [winfo toplevel $w] == "." } {
	set wmsg ".message"
    } else {
	set wmsg "[winfo toplevel $w].message"
    }
    if { ![winfo exists $wmsg] } { return }

    # Update the message bar
    $wmsg configure -text ""
}

# HELP internal
# Usage: graph_message w
# 
# Determine which message box to use, if any.
proc graph_message {w args} {
    # Determine if this window has a message bar
    # FIXME: consider using floating window if no message bar
    if { [info exists ::active_graph($w,message)] } {
	set wmsg $::active_graph($w,message)
    } elseif { [winfo toplevel $w] == "." } {
	set wmsg ".message"
    } else {
	set wmsg "[winfo toplevel $w].message"
    }
    if { ![winfo exists $wmsg] } { 
	set wmsg "" 
    } elseif { [llength $args] > 0 } {
	$wmsg configure -text [concat $args]
    }
    return $wmsg
}

# HELP internal
# Usage: graph_motion w x y
#
# Display info about the point under the cursor.  Update the graph
# crosshairs. Callback for the graph motion event.
proc graph_motion {w x y} {
    # Move crosshairs to the current point
    $w crosshairs conf -position @$x,$y

    # Generate the default message as "legend_label:index (x, y)"
    $w element closest $x $y where -halo 1i
    if { ![info exists where(x)] } {
	set msg ""
    } else {
	set msg "[$w elem cget $where(name) -label]"
	if {$msg == ""} { set msg $where(name) }
	append msg ":[expr {$where(index)+1}]"
	append msg " ([fix $where(x) {} {} 5], [fix $where(y) {} {} 5])"
	
	# Reformat the message specific to this graph
	if { [info exists ::active_graph($w,motion)] } {
	    set msg [$::active_graph($w,motion) \
			 $w $x $y $where(name) $where(index) $msg]
	}
    }

    # Output the message to the message box
    graph_message $w $msg
}

proc graph_export { w } {
    # FIXME want an export dialog
    #   *record separator, field separator, field width
    #   *digits of precision or digits after decimal
    #   *comment character for heading lines
    #   *export to clipboard or named file (along with directory icon)
    #   *list of labelled legend items to choose from, defaulting to current
    # Remember choices between sessions; default choices according to OS
    set el [active_graph $w element]
    if {$el eq ""} { 
	graph_message $w "no element selected" 
	return
    }
    set filename "[$w element cget $el -label].dat"
    set filename [ tk_getSaveFile -defaultextension .dat \
		       -initialfile $filename -title "Export file" ]
    if {$filename eq ""} { return }

    if {[catch {
	set fid [open $filename w]
	set columns {}
	foreach v { xdata xerror ydata yerror } {
	    set data [$w element cget $el -$v]
	    if { [vector_exists $data] } { set data [set ${data}(:)] }
	    if { [llength $data] > 0 } { lappend $columns $v }
	    set $v $data
	}
	puts $fid "# title [$w cget -title]"
	puts $fid "# legend [$w element cget $el -label]"
	puts $fid "# xlabel [$w axis cget [$w element cget $el -mapx] -title]"
	puts $fid "# ylabel [$w axis cget [$w element cget $el -mapy] -title]"
	puts $fid "# columns $columns"
	foreach x $xdata dx $xerror y $ydata dy $yerror { 
	    puts $fid "$x $dx $y $dy"	
	}
    } msg] } {
	graph_message $w $msg
    }
    catch { close $fid }
}

# HELP developer
# Usage: active_graph w ?-motion command
#
# Make the graph active by keeping crosshairs up to date, allowing zoom
# and pan, updating status of the point under the cursor, providing a
# context menu for toggling grid, crosshairs and error bars and for
# printing the graph.
#
# If present, the motion command should accept
#    motion w x y name idx msg
# where x,y is the point in the graph window w, name is the name of the
# line under the cursor, idx is the index of the point under the cursor
# and msg is the default point status message containing
#    label:idx (xval, yval)
# The motion command should return a new msg to replace this.
#
# The name of the context menu is $w.menu.  You may add new items to this
# menu in the usual way.  To get information about the context of the graph
# under the cursor where the menu was posted, use the command
#
#    active_graph w marker|element|index
#
# For example, if you have a function to record excluded points, you can
# bind that to the context menu using:
#
#    set cmd {
#      exclude_point [active_graph .graph element] [active_graph .graph index]
#    }
#   .graph.menu add separator
#   .graph.menu add command -label Exclude -command $cmd
#
proc active_graph {w args} {

    switch -- [lindex $args 0] {
        marker - index -
        element { return $::active_graph($w,$args) }
	-motion { set ::active_graph($w,motion) [lindex $args 1] }
    }
    array set ::active_graph [list $w,element {} $w,marker {} $w,index {}]
    set ::active_graph($w,errbar) [option get $w showErrorBars ShowErrorBars]
    if { "$::active_graph($w,errbar)" eq "" } {
	set ::active_graph($w,errbar) both
    }

    # crosshairs if the users wishes
    # XXX FIXME XXX do we really need to process this resource by hand?
    if { [string is true [option get $w crosshairs Crosshairs]] } {
	$w crosshairs on
    }
    
    # Define the standard menu
    menu $w.menu -tearoff 1 -title "$w controls"
    $w.menu add command -underline 0 -label "Unzoom" -command "blt::ResetZoom $w"
    $w.menu add command -underline 2 -label "Pan" -command "pan start $w"
    $w.menu add command -underline 5 -label "Crosshairs" -command "$w crosshairs toggle"
    if [blt_errorbars] {
	$w.menu add command -underline 0 -label "Error bars" \
		-command "graph_toggle_error $w"
    }
    $w.menu add command -underline 0 -label "Grid" -command "$w grid toggle"
    if { [string equal windows $::tcl_platform(platform)] } {
        $w.menu add command -underline 3 -label "Copy" -command "$w snap -format emf CLIPBOARD"
    }
    $w.menu add command -underline 0 -label "Print..." -command "PrintDialog $w"
    $w.menu add command -underline 1 -label "Export..." -command "graph_export $w"

    # Add zoom capability to graph, but use the menu to unzoom
    Blt_ZoomStack $w
    # bind zoom-$w <ButtonPress-2> [bind zoom-$w <ButtonPress-3>]
    bindtags $w [concat active_graph [bindtags $w]]

    # Add panning capability
    pan bind $w
}
option add *Graph.showErrorbars both widgetDefault
option add *Graph.Crosshairs off widgetDefault
option add *Graph.Axis.ScrollIncrement 1 widgetDefault
# option add *Graph.Interpolate no widgetDefault

# HELP internal
# Usage: graph_toggle_error w
#
# Toggle error bars on or off for all lines on the graph.
# Callback for the toggle errorbar event (usually bound the context menu).
proc graph_toggle_error {w} {
    if { [blt_errorbars] } {
	# XXX FIXME XXX this toggles between both/none.  There are also
	# options for x-only or y-only, but we will ignore these.  If your
	# data only has x or y errors, then both/none will work fine.
	if { "$::active_graph($w,errbar)" eq "none" } {
	    set ::active_graph($w,errbar) both
	} else {
	    set ::active_graph($w,errbar) none
	}
	foreach el [$w element names] {
	    $w elem conf $el -showerrorbars $::active_graph($w,errbar)
	}
    }
}

# HELP internal
# Usage: blt_errorbars
#
# Returns true if you can use -yerror as an option to the blt graphs.
# Developers will not need this function if errorbars are added with the
# graph_error command.  In practice, all versions of BLT which we will
# see support error bars so this is historical cruft.
proc blt_errorbars {} {
    # Determine if this version of BLT handles error bars
    graph .blt_errorbars
    set status [expr {![ catch {.blt_errorbars elem create hello -yerror 1 }]}]
    destroy .blt_errorbars

    # Cache the result of the test for future queries

    proc blt_errorbars {} "return $status"

    # Return the result
    return $status
}

# HELP developer
# Usage: graph_error .graph elem ?-xerror value ?-yerror value
#
# Associates error bars with the line.  Whether the error bars are
# shown depends on whether your version of BLT supports error bars
# and whether the error bars are requested.
proc graph_error {w el args} {
    if { [blt_errorbars] } {
	eval $w elem conf $el $args -showerrorbars $::active_graph($w,errbar)
    }
}

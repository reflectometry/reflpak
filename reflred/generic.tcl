# ==================== resources ==============================
if { [info exists ::env(HOME)] } {
    set HOME $::env(HOME)
} else {
    set HOME [ pwd ]
}
proc load_resources { base app } {
    # application defaults
    set file [file join $base "${app}rc"]
    if [file exists $file] {
	if [catch { option readfile $file userDefault } err] {
	    puts stderr "error in $file\n$err"
	    exit 1
	}
    }

    # user defaults
    set file [file join $::HOME ".${app}rc"]
    if [file exists $file] {
	if [catch { option readfile $file userDefault } err] {
	    puts stderr "error in $file\n$err"
	    exit 1
	}
    }
}

# ==================== config info =============================
# Usage: blt_errorbars
# Returns true if you can use -yerror as an option to the blt graphs
proc blt_errorbars {} {
    # Determine if this version of BLT handles error bars
    graph .blt_errorbars
    set status [expr ![ catch { .blt_errorbars elem create hello -yerror 1 } ]]
    destroy .blt_errorbars

    # Cache the result of the test for future queries
    proc blt_errorbars {} "return $status"

    # Return the result
    return $status
}


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


# ==================== common dialogs ==========================
#proc notify { mesg {ok "OK"} } {
#}
#
#option add *Confirm*icon.bitmap questhead widgetDefault
#option add *Confirm*mesg.wrapLength 6i widgetDefault
#proc confirm { mesg {ok "OK"} {cancel "Cancel"} } {
#}

# ==================== bug reporting ============================
# from:
#  Harrison, M & McLennan, M (1998). Effective Tcl/Tk Programming.
#  Addison-Wesley.
proc email_send {to from cc subject text} {
    set fid [open "| /usr/lib/sendmail -oi -t" "w"]
    puts $fid "To: $to"
    if {[string length $from] > 0} { puts $fid "From: $from" }
    if {[string length $cc] > 0} { puts $fid "Cc: $cc" }
    puts $fid "Subject: $subject"
    puts $fid "Date: [clock format [clock seconds]]"
    puts $fid "" ;# sendmail terminates header with blank line
    puts $fid $text
    close $fid
}

proc email_bug_report { bugAddress err } {
    global errorInfo env argv argv0

    set bugReport $errorInfo

    set question "Unexpected error:\n$err\n\n"
    append question "Select \"E-mail Bug Report\" to send a report "
    append question "of this incident to $bugAddress."

    if { [confirm $question "E-mail Bug Report" "Ignore"] } {

    }

}

# ==================== Debugging ================================
namespace eval ::tracing:: {
    variable Level 0

    proc Pre { level command argv } {
	variable Level
	if { $level > $::tracing::Level } { return }
	regexp {[:space:]*([^[:space:]][^\n]*)} $command name
	puts stderr "$level $name"
    }
    proc Post { level command argv retcode results } {
	variable Level
	if { $level > $::tracing::Level } { return }
	puts stderr "=> $retcode -- $results"
    }
    proc init { level } {
	variable Level
	set Level $level
	catch { ::blt::watch delete trace }
	if { $level > 0 } {
	    ::blt::watch create trace \
		    -precmd ::tracing::Pre -postcmd ::tracing::Post
	}
    }
}

proc tracing { level } { ::tracing::init $level }


# =========================== greek character codes ==================
# use $::symbol(Alpha) for uppercase alpha, $::symbol(alpha) for
# lowercase alpha, and so on for the rest of the greek alphabet
array set symbol {
    angstrom      \xc5
    squared       \xb2
    inverse       \xaf\xb9
    inversesquare \xaf\xb2
    invangstrom   \xc5\xaf\xb9
    cubed         \xb3
    degree        \xb0
    plusminus     \xb1
    hbar          \u127
    Alpha  \u391 Beta \u392 Gamma \u393 Delta \u394 Epsilon \u395
    Zeta   \u396 Eta  \u397 Theta \u398 Iota  \u399 Kappa   \u39a
    Lambda \u39b Mu   \u39c Nu    \u39d Xi    \u39e Omicron \u39f
    Pi     \u3a0 Rho  \u3a1 Sigma \u3a3 Tau   \u3a4 Upsilon \u3a5
    Phi    \u3a6 Chi  \u3a7 Psi   \u3a8 Omega \u3a9
    alpha  \u3b1 beta \u3b2 gamma \u3b3 delta \u3b4 epsilon \u3b5
    zeta   \u3b6 eta  \u3b7 theta \u3b8 iota  \u3b9 kappa   \u3ba
    lambda \u3bb mu   \u3bc nu    \u3bd xi    \u3be omicron \u3bf
    pi     \u3c0 rho  \u3c1 sigma \u3c3 tau   \u3c4 upsilon \u3c5
    phi    \u3c6 chi  \u3c7 psi   \u3c8 omega \u3c9
}


# ========================== numeric ================================

# given the data limits [min,max], round value to the nearest three
# digits of accuracy.  For example, for limits of [ 0.175, 0.197 ]
# the data range is 0.022, and 1 digit of accuracy would be rounding
# to the nearest 0.01, 2 digits would be rounding to the nearest
# 0.001 and three digits would be rounding to the nearest 0.0001.
# XXX FIXME XXX - do we really want to limit ourselves to 3 digits?
proc fix { value {min {}} {max {}} {accuracy 3}} {
    if { $max == "" } { set max $value }
    if { $min == "" } { set min $value }
    if { $max == $min } { set min 0.0 ; set max [expr abs($max)] }
    if { $max == $min } { set max 1.0 }
    set scale [expr pow(10,ceil(log10($max-$min))-$accuracy)]
    return [expr round($value/$scale)*$scale]
}

## Usage: makereal a
## Force the number $a to include a decimal point.  We need this because
## without a decimal point fortran formatted input assumes one at the user
## specified precision.
proc makereal {a} {
    if { [string match $a {}] } { set a 0 }
    return [ format %.15e $a ]
}

## Usage: makeint a
## Round the value $a and return the nearest integer.
proc makeint {a} {
    if { [string match $a {}] } { set a 0 }
    return [ format %.0f $a ]
}

## Since when is {} a double value?  Grrr...
proc string_is_double { a } {
    if [string equal $a {}] { return 0 }
    return [string is double $a]
}



# ======================= blt additions ==============================

proc cumsum { x } {
    set n [ $x length ]
    set sum 0.0
    for { set i 0 } { $i < $n } { incr i } {
	set ${x}($i) [set sum [expr $sum + [set ${x}($i)]]]
    }
}

proc vector_exists { x } {
    return [expr ![string equal {} [vector names $x]]]
}

# ====================== date conversion =============================

# Grrr... [clock scan "Jul  8 1996"] fails
# Grrr... [clock scan ""] doesn't fail
proc clock_scan { date } {
    if { [string equal {} $date] } {
	error "unable to convert date-time string \"\""
    }
    # XXX FIXME XXX do we want to anchor the pattern to the ends?
    # If so, then we need to accomodate a possible time following
    # the date.  If not, then we have to worry that the pattern is
    # too general.
    regsub {^\s*([[:alpha:]]+)\s+(\d+)\s+(\d+)(\s+\d+:\d+)?\s*$} \
	    $date {\1 \2, \3} date
    return [clock scan $date]
}

# ====================== octave colormaps ===========================

# XXX FIXME XXX perhaps these should be in octave.tcl?
proc load_colormaps {} {
    if { ![info exists ::colormap_list] } {

	# Load predefined colormap table
	set ::colormap_list [option get . colormapList ColormapList]
	if { [llength $::colormap_list] == 0 } {
	    set ::colormap_list { 
		hot cool spring winter summer autumn bone ocean 
		copper prism flag hsv gray pink blue 
	    }
	}
	foreach map $::colormap_list {
	    set mapname [string totitle [string map { " " "" } $map] 0 0]
	    set mapvalue [option get . colormap$mapname Colormap$mapname]
	    if { [llength $mapvalue] > 0 } {
		set ::colormap_defs($map) $mapvalue
	    }
	}

    }
    return $::colormap_list
}

proc set_colormap {name} {
    if { [info exists ::colormap_defs($name)] } {
	set name $::colormap_defs($name)
    }
    octave eval colormap(gray(64))
    octave eval colormap($name)
}


# ====================== array functions =============================
# return index of an occurrence of $value in the named array
# XXX FIXME XXX This should accept -exact/-glob/-regexp like lsearch
# XXX FIXME XXX Both asearch and lsearch should be returning lists!
# XXX FIXME XXX Returns an incorrect result if value matches an index name
# XXX FIXME XXX Not used anywhere
proc asearch { array value } {
    upvar $array a
    set list [array get a]
    set idx [lsearch -exact $list $value]
    return [lindex $list [expr $idx - 1]]
}

# =================== resources for text tags ==========================
# Labouriously check the resource file for the following tag options:
set ::texttagoptions {
    background Background
    bgstipple Bgstipple
    borderWidth BorderWidth
    elide Elide
    fgstipple Fgstipple
    font Font
    foreground Foreground
    justify Justify
    lMargin1 Margin
    lMargin2 Margin
    offset Offset
    overstrike Overstrike
    relief Relief
    rMargin Margin
    spacing1 Spacing
    spacing2 Spacing
    spacing3 Spacing
    tabs Tabs
    underline Underline
    wrap Wrap
}
proc texttagoption { w tag } {
    foreach { name class } $::texttagoptions {
	set opt [option get $w $tag-$name $tag-$class]
	if { [llength $opt] == 0 } { 
	    set opt [option get $w Tag-$name Tag-$class ] 
	}
	if { [llength $opt] > 0 } {
	    $w tag configure $tag -[string tolower $name] $opt
	}
    }
}

# =================== PanedWindow resource handling ====================
# process resource file entries for PanedWindow, since BWidget doesn't
# do it
#   *sash1.but.size: long wide
#   *sash1.but.background: color
proc sashconf { w } {
    set size [option get $w.sash1.but size Size]
    if { [llength $size] == 1 } {
	set wide $size
	set long $size
    } elseif { [llength $size] == 2 } {
	foreach { long wide } $size {}
    } else {
	set wide {}
	set long {}
    }
    switch [$w cget -side] {
	right -
	left { foreach { wide long } [list $long $wide] {} }
    }
    if { [catch { $w.sash1.but conf -width $wide -height $long } msg] } {
	error "resource error for $w.sash1.but.size\n$msg\nUse *sash1.but.size: long wide"
    }

    set bg [option get $w.sash1.but background Background]
    if { [catch { $w.sash1.but conf -bg $bg } msg ] } {
	error "resource error for $w.sash1.but.background\n$msg\nUse *sash1.but.background: <color>"
    }

    return $w
}

# =================== listbox operations ======================
## Usage: listbox_ordered_insert .path_to_listbox item
proc listbox_ordered_insert { w item } {
    set len [ $w size ]
    for { set idx 0 } { $idx < $len } { incr idx } {
	if { [string compare -nocase $item [ $w get $idx ]] < 0 } { break }
    }
    $w insert $idx $item
    return $idx
}

## Usage: listbox_delete_pattern .path_to_listbox name
proc listbox_delete_by_name { w item } {
    set len [ $w size ]
    for { set idx [expr $len - 1] } { $idx >= 0 } { incr idx -1 } {
	if { [string equal $item [ $w get $idx ]] } {
	    $w delete $idx
	}
    }
}

# =================== scrolled window helper functions =================
## Usage: scroll .path_to_widget ...
##        vscroll .path_to_widget ...
##        hscroll .path_to_widget ...
## Create a new frame for the widget and scroll bars and pack it.
## The widget and frame are packed using "-fill both -expand yes".
## Additional arguments to the command are used to pack the frame.
## Scroll bars are automatically displayed or hidden depending on
## the space available to the frame and the size of the widget.
proc scroll { w args } {
    ScrolledWindow ${w}#box
    ${w}#box setwidget $w
    raise $w
    eval pack ${w}#box -fill both -expand yes $args
}
proc vscroll { w args } {
    ScrolledWindow ${w}#box -scrollbar vertical
    ${w}#box setwidget $w
    raise $w
    eval pack ${w}#box -fill both -expand yes $args
}
proc hscroll { w args } {
    ScrolledWindow ${w}#box -scrollbar horizontal
    ${w}#box setwidget $w
    raise $w
    eval pack ${w}#box -fill both -expand yes $args
}
## Usage: scrollwin .path_to_widget
##        vscrollwin .path_to_widget
##        hscrollwin .path_to_widget
## Returns a scrolled frame containing the widget which can be used
## directly to place the widget in a grid.  This widget will be named
## .path_to_widget#box.
##
## E.g.,
if { 0 } {
    toplevel .test
    grid [label .test.textlabel -text "Text box"] -sticky ew
    grid [scrollwin [text .test.text -wrap none]] -sticky news
    grid columnconf .test 0 -weight 1
    grid rowconf .test 1 -weight 1
    .test.text insert end "Here you will see
a bunch of text
that I insert into my
window to test that the
scrollbars are working
as expected.

Resize the box to see
them in action."

}
proc scrollwin { w } {
    ScrolledWindow ${w}#box
    ${w}#box setwidget $w
    raise $w
    return ${w}#box
}
proc vscrollwin { w } {
    ScrolledWindow ${w}#box -scrollbar vertical
    ${w}#box setwidget $w
    raise $w
    return ${w}#box
}
proc hscrollwin { w } {
    ScrolledWindow ${w}#box -scrollbar horizontal
    ${w}#box setwidget $w
    raise $w
    return ${w}#box
}

# ==================== text widget helper functions ====================

## Usage: text_replace .path_to_text_widget "new text value"
## replace the text in the widget with the new text value
proc text_replace {w str} {
    set state [ $w cget -state ]
    $w conf -state normal
    $w delete 0.0 end
    $w insert 0.0 $str
    $w conf -state $state
}

## Usage: text_append .path_to_text_widget "new text"
## append new text on the end of the text in the widget
proc text_append {w str} {
    set state [ $w cget -state ]
    $w conf -state normal
    $w insert end $str
    $w conf -state $state
}

## Usage: text_clear .path_to_text_widget
## clear the text out of the widget
proc text_clear {w} {
    set state [ $w cget -state ]
    $w conf -state normal
    $w delete 0.0 end
    $w conf -state $state
}

## Usage: text_load .path_to_text_widget "filename"
## replace the text in the widget with the contents of the file
proc text_load {w file} {
    if [ catch { open $file r } fid ] {
	text_replace $w {}
    } else {
	text_replace $w [ read $fid ]
	close $fid
    }
}

# ========================= List functions ========================
proc ldelete { list value } {
    set index [ lsearch -exact $list $value ]
    if { $index >= 0 } {
	return [lreplace $list $index $index]
    } else {
	return $list
    }
}


#========================= BLT graph functions =====================
# To suppress the zoom action on the graph when you are twiddling the
# marker and legend, set zoom off on the Button-1 event and zoom on
# on the ButtonRelease-1 event for the marker/legend.
# XXX FIXME XXX there must be a better way to do this
proc zoom { w state } {
    if { ! [info exists ::zoomsave($w)] } {
	set ::zoomsave($w) [ bind zoom-$w <Button-1> ]
    }
    switch $state {
	"off" { bind zoom-$w <Button-1> {} }
	"on" { bind zoom-$w <Button-1> $::zoomsave($w) }
	default { error "{on|off}" }
    }
}

# active_legend graph ?callback
#
# Highlights the legend entry when the user moves over the line in the 
# graph, and toggles the line when the user clicks on the legend entry.
#
# If a callback is provided it will be called after showing/hiding with
#    eval callback graph elem ishidden
# where ishidden is the new state of the element.
#
# XXX FIXME XXX consider highlighting the current line when the user
# mouses over its legend entry
proc active_legend {w {command ""} } {
    $w legend conf -hide 0
    $w legend bind all <Button-1> "zoom %W off ; legend_toggle %W {$command}"
    $w legend bind all <ButtonRelease-1> { zoom %W on }
    $w element bind all <Enter> {
	%W legend activate [%W element get current]
    }
    $w element bind all <Leave> {
	%W legend deactivate [%W element get current]
    }
}
proc legend_toggle {w {command ""}} {
    set line [$w legend get current]
    set state [expr 1 - ![string is true [$w elem cget $line -hide]]]
    legend_set $w $line $state $command
}

proc legend_set {w line state {command ""}} {
    if { [string is true $state] } { 
	set hide 0
	set relief raised
    } else {
	set hide 1
	set relief flat
    }
    # puts "legend_toggle $w $line -> $hide"
    $w elem conf $line -labelrelief $relief -hide $hide
    if ![string equal {} $command] {
	eval $command $w $line $hide
    }
}

# active_axis graph axis ?callback
#
# Makes the specified axis for the graph "active" so that left click
# toggles log/linear scaling and right click hides/shows all the lines
# associated with that axis.
#
# If a callback is provided it will be called after hiding/showing with
#    eval callback graph axis ishidden
# where ishidden is the new state of the axis.  There is no
# callback when logscale is changed.
proc active_axis {w axis {command ""} } {
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
proc axis_toggle {w {command ""}} {
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
    set hide 1
    foreach elem $map {
	if {[$w elem cget $elem -hide]} { set hide 0; break }
    }
    # hide/show all elements associated with the axis
    # XXX FIXME XXX Grrr... cross talk between active_axis and active_legend
    # Is there some sort of element "hide" event that the active legend can
    # bind to?
    if { $hide } {
	set relief flat
    } else {
	set relief raised
    }
    foreach elem $map {
	$w elem conf $elem -hide $hide -labelrelief $relief
    }
    # callback to let the application know which axis was toggled
    if ![string equal {} $command] {
	eval $command $w $axis $hide
    }
}

# graph_select .graph.widget {x1 y1 name1} {x2 y2 name2} ...
# Lets the user select a number of points off a graph, saving the result
# in the named variables x1 y1 name1, x2 y2 name2, etc.  Uses the
# activeLine pen to indicate the symbol under the mouse.
#
# Any of the names can be omitted using {} instead.  E.g.,
#    graph_select .graph x_min x_max
# selects an x-range and stores it in ::x_min, ::x_max.
#    graph_select .graph {x y}
# selects a single point and stores it in ::x, ::y
#    graph_select .graph {x y name}
# selects a single point and stores it in ::x, ::y.  The name of the line
# element containing the point is stored in ::name.

# XXX FIXME XXX should have a way to select a list of points of unknown
# length.
# XXX FIXME XXX should be able to restrict the points to a subset of the
# available elements.
bind graph_select <Motion> {graph_select_motion %W %x %y}
bind graph_select <Button-1> {graph_select_press %W %x %y; break}
bind graph_select <B1-ButtonRelease> {graph_select_release %W %x %y; break}
bind graph_select <B3-ButtonRelease> {graph_select_cancel %W; break}
option add *Graph.selectPointText.Coords {-Inf -Inf} widgetDefault
option add *Graph.selectPointText.Anchor sw widgetDefault
option add *Graph.selectPointText.Justify left widgetDefault
option add *Graph.selectPointText.Under 1 widgetDefault

proc graph_select { w args } {
    set ::graph_select(focus,$w) [focus]
    set ::graph_select(points,$w) $args
    # puts "adding graph_select tag to [bindtags $w] for $w"
    bindtags $w [concat graph_select [bindtags $w]]
    # XXX FIXME XXX is there a way to save and restore stacking order?
    raise [winfo toplevel $w]
    $w marker create text -name selectPointText \
	    -text "Click to select [lindex $args 0]\nRight-Click to cancel"
    grab set $w
}

proc graph_select_motion {w x y} {
    # puts "graph_select_motion"
    eval $w element deactivate [$w elem names]
    foreach line [array names ::graph_select "active*,$w"] { 
	eval $w element activate [string map [list active {} ",$w" {}] $line] $::graph_select($line) 
    }
    $w element closest $x $y where -halo 1i
    if { [info exists where(x)] } {
	#puts "activating $where(name) $where(index)"
	if [info exists ::graph_select(active$where(name),$w)] {
	    eval $w element activate $where(name) $::graph_select(active$where(name),$w) $where(index)
        } else {	
	    $w elem activate $where(name) $where(index)
        }
    }
}

proc graph_select_press {w x y} {
    $w element closest $x $y where -halo 1i
    if { [info exists where(x)] } {
	#puts "graph_select_press setting [lindex $::graph_select(points,$w) 0] $where(x)"
	foreach {x y el} [lindex $::graph_select(points,$w) 0] {}
	set ::graph_select(points,$w) [lrange $::graph_select(points,$w) 1 end]
	if {![string equal $x {}]} { uplevel #0 set $x $where(x) }
	if {![string equal $y {}]} { uplevel #0 set $y $where(y) }
	if {![string equal $el {}]} { uplevel #0 set $el $where(name) }
	lappend ::graph_select(active$where(name),$w) $where(index)
    }
}

proc graph_select_release {w x y} {
     #puts "graph_select_release with $::graph_select(points,$w)"
    if {[llength $::graph_select(points,$w)] == 0} { 
	graph_select_cancel $w 
    } else {
	$w marker conf selectPointText \
		-text "Click to select [lindex $::graph_select(points,$w) 0]\nRight-Click to cancel"
    }

}

proc graph_select_cancel {w} {
    #puts "graph_select_cancel"
    $w marker delete selectPointText
    eval $w element deactivate [$w elem names]
    bindtags $w [ldelete [bindtags $w] graph_select]
    grab release $w
    catch { 
	raise [winfo toplevel $::graph_select(focus,$w)]
	focus $::graph_select(focus,$w) 
    }
    array unset ::graph_select *,$w
}


# ========================= Forms interface =======================

# addfields .pathtoframe { field field ... }
# where field is
#      { real variable label units }
#      { string variable label comments }
#      { bool variable label }
# Primitive form layout manager
# Variable is placed in widget named .pathtoframe.variable
# Uses grid packing manager (3 columns)

proc addfields { frame fields } {
    foreach f $fields {
	switch -exact -- [lindex $f 0] {
	    string -
	    real { # variable label units
		set vname [lindex $f 1]
		set lidx $frame.$vname-label
		label $lidx -text [lindex $f 2]
		set eidx $frame.$vname
		entry $eidx -textvariable [lindex $f 1]
		if { [ lindex $f 3 ] != "" } {
		    set uidx $frame.$vname-units
		    label $uidx -text [lindex $f 3]
		} else {
		    set uidx -
		}
		grid $lidx $eidx $uidx -sticky w
	    }

	    bool { # variable label
		set vname [lindex $f 1]
		set idx $frame.$vname
		checkbutton $idx -text [lindex $f 2] -variable $vname
		grid $idx - - -sticky w
	    }
	    default {
		# set { set of check buttons }
		# choice { (list of choices }
		# int { integer value }
		error "Unknown field type [lindex $f 0]"
	    }
	}
    }
}

# ===================== TkTable Entry ======================

## Use the entry widget for TkTable entries rather than letting
## TkTable fake its own. Use
##
##      table_entry path set
##
## where path is a tktable table widget and set is an optional
## command to get/set entries.
##
## The following substitutions are done on the set command:
##     %r   row containing entry
##     %c   column containing entry
##     %C   %r,%c
##     %W   path to the table
##     %i   0 if get, 1 if set
##     %s   old value (if get, this is the value displayed in the table)
##     %S   new value (if get, this is "")
##
## On get, the get/set command should return the value to edit.
## On set, it should return the value to display.  These need
## not be the same.  For example, the display value may be chopped
## to 4 significant figures, but all the digits are retained and
## available for editting.  Or the display value is the number,
## but the stored entry is a command such as =A6 which gets
## displayed as the contents of row 1, column 6 of the table.
##
## If set raises an error we catch the error, ring the bell, and
## continue editting.  That way set can be used to validate the
## entries.  We could also catch and display the message instead
## of ringing the bell to give the user more feedback, but this
## should be a user preference.
##
## The set command will only be called for edittable cells, not
## for title or disabled cells.  For example, to disable cell 3,3
## use $w tag cell disabled 3,3.

## TODO: allow different widget types for each row/column/cell.

proc table_entry { w { getset "" } } {

    ## need a widget to edit with
    entry $w.entry

    ## Because all widget bindings are processed before any
    ## class bindings, the generic KeyPress event for the
    ## widget gets processed before the specific Up, Down,
    ## Right, Left, etc. for the class.  To get around this,
    ## we make all the class bindings into widget specific
    ## bindings which immediately fall through to the class
    ## bindings so that the generic action for the widget
    ## doesn't get invoked if a more specific action for the
    ## class is defined.  This will ONLY handle specific Key
    ## bindings for Table at the time that this is called.
    foreach seq [bind Table] { 	bind $w $seq { continue }  }

    # Note: use [string map {% %%} $getset] so that the bind command doesn't
    # expand the getset command options for us
    set ::getset-$w $getset
    set save "table_entry::_save $w"

    # XXX FIXME XXX need to grab in cell/focus change requests from $w
    # while editting is in progress and either beep if the current cell
    # value is invalid, or move the edit widget if the value is good
    bind $w <Return> "table_entry::_edit %W; break"
    bind $w <Shift-Tab> { puts "backtab in \$w" }
    bind $w <KeyPress> "table_entry::_new %W %A ; break"
    bind . <Shift-Tab> { puts "backtab in ." }
    bind $w <ButtonRelease-1> "%W activate @%x,%y; table_entry::_edit %W"
    bind $w.entry <Escape> "table_entry::_abort $w"
    bind $w.entry <Return> "$save"
#    bind $w.entry <Shift-Return> "$save up"
    bind $w.entry <Tab> "$save right ; break"
    bind $w.entry <Shift-Tab> "puts backtab; $save left ; break"
    bind $w.entry <Up> "$save up"
    bind $w.entry <Down> "$save down"

    set ::window-$w {}
}

namespace eval table_entry {}

# called when user starts typing a new value
proc table_entry::_new { w char } {
#   puts "[info level 0] [.layertable index active]"
    # ignore titles and disabled fields
    if { ![_can_edit $w active] } { return }

    # put the user into an edit widget with the cursor at the end
    $w.entry delete 0 end
    $w.entry insert end $char
    $w window conf active -window $w.entry -sticky news
    focus $w.entry
}

# called when user wants to edit an existing value
proc table_entry::_edit { w } {
#   puts "[info level 0] [$w index active]"

    # trying to edit a new cell before exitting the old cell
    if { [llength [set ::window-$w]] > 0 } {
	if { ![_can_edit $w active] } {
	    $w activate [set ::window-$w]
	    focus $w.entry
	    return
	} else {
	    # XXX FIXME XXX yuck! _edit calls _save which calls _edit
	    # need to do some refactoring here
	    _save $w [$w index active]
	    return
	}
    }

    # don't edit title fields or disabled fields
    if { ![_can_edit $w active] } { return }

    # the value being editted may not correspond to the value
    # being displayed (e.g., =A1 is the stored value but 3.14
    # is the displayed value) so ask the caller for a new value
    $w.entry delete 0 end
    if { ![string equal {} [set ::getset-$w]] } {
	set row [$w index active row]
	set col [$w index active col]
	set map [list %c "$col" %r "$row" %C "$row,$col" %W "$w" %i 0 \
		%s "[$w curval]" %S "{}"]
	$w.entry insert end [eval [string map $map [set ::getset-$w]]]
    } else {
	$w.entry insert end [$w curval]
    }
    $w.entry selection range 0 end

    # put the user in an edit widget with the cursor at the end
    $w window conf active -window $w.entry -sticky news
    set ::window-$w [$w index active]
    focus $w.entry
}

# called when the user wants to revert to the original value
proc table_entry::_abort { w } {
#   puts "[info level 0] [$w index active]"
    # XXX FIXME XXX ick! Can't we just reload the value?
    $w activate [set ::window-$w]
    set ::window-$w {}
    $w window conf active -window {}
    _edit $w
    # focus $w
}

# called when the user is done editting and wants to save changes
# make sure that valid values are being entered into the table, and
# update the graph when the value changes
proc table_entry::_save { w {move ""}} {
#   puts "[info level 0] [$w index active]"

    set val    [$w.entry get]

    #XXX FIXME XXX should move the entry rather than using -window {}
    #otherwise window names continues to grow
    #puts "window names: [$w window names]"
    set row    [$w index [set ::window-$w] row]
    set col    [$w index [set ::window-$w] col]
    set top    [$w index origin row]
    set bottom [$w index end row]
    set left   [$w index origin col]
    set right  [$w index end col]
    if { ![string equal {} [set ::getset-$w]] } {
	set map [list %c "$col" %r "$row" %C "$row,$col" %W "$w" %i 1 \
		%s "[$w get [set ::window-$w]]" %S "$val"]
	set fail [catch [string map $map [set ::getset-$w]] val]
    } else {
	set fail 0
    }

    if { $fail } {
	# the new value is bad so don't save it, and leave the user in the
	# edit widget (they can trigger abort if they want to revert)
	# XXX FIXME XXX can we do something with the error message in $val?
	set ::message $val
	# XXX FIXME XXX Why aren't we activating [set ::window-$w]?
	$w activate [set ::window-$w]
	focus $w.entry
	bell
    } else {
	set ::message {}
	# the new value is good so save it and remove the edit widget
	$w set [set ::window-$w] $val
	$w icursor end
	$w window conf [set ::window-$w] -window {}
	set ::window-$w {}
	# focus $w

	# move to the next cell according to move
	switch -- $move {
	    up { _move_up; set idx $row,$col }
	    down { _move_down; set idx $row,$col }
	    right { _move_right; set idx $row,$col }
	    left { _move_left; set idx $row,$col }
	    "" { set idx $row,$col }
	    default { set idx $move }
	}
	$w activate $idx
	_edit $w
    }
}

proc table_entry::_can_edit { w cell } {
    # puts "_can_edit $cell"
    if { [string match $cell active] } {
	if { ![$w tag exists active] } { return 0 }
    }
    if { [$w tag includes title $cell] } { return 0 }
    if { [$w tag includes disabled $cell] } { return 0 }
    return 1
}

proc table_entry::_move_up {} {
    upvar left left
    upvar right right
    upvar top top
    upvar bottom bottom
    upvar row row
    upvar col col
    upvar w w

    incr row -1
    while {1} {
	if { $row < $top } {
	    set row $bottom
	    if { [incr col -1] < $left } { break }
	}
	if { [ _can_edit $w $row,$col] } { return }
	incr row -1
    }
    set row [expr $top - 1]
    set col $left
    _move_down
}

proc table_entry::_move_down {} {
    upvar left left
    upvar right right
    upvar top top
    upvar bottom bottom
    upvar row row
    upvar col col
    upvar w w

    incr row
    while {1} {
	if { $row > $bottom } {
	    set row $top
	    if { [incr col] > $right } { break }
	}
	if { [ _can_edit $w $row,$col] } { return }
	incr row 1
    }
    set row [expr $bottom + 1]
    set col $right
    _move_up
}

proc table_entry::_move_left {} {
    upvar left left
    upvar right right
    upvar top top
    upvar bottom bottom
    upvar row row
    upvar col col
    upvar w w

    incr col -1
    while {1} {
	if { $col < $left } {
	    set col $right
	    if { [incr row -1] < $top } { break }
	}
	if { [ _can_edit $w $row,$col] } { return }
	incr col -1
    }
    set row $top
    set col [expr $left - 1]
    _move_right
}

proc table_entry::_move_right {} {
    upvar left left
    upvar right right
    upvar top top
    upvar bottom bottom
    upvar row row
    upvar col col
    upvar w w

    incr col
    while {1} {
	if { $col > $right } {
	    set col $left
	    if { [incr row] > $bottom } { break }
	}
	if { [ _can_edit $w $row,$col] } { return }
	incr col 1
    }
    set row $bottom
    set col [expr $right + 1]
    _move_left
}

# XXX FIXME XXX do we want to override the default bindings?
bind Entry <<Paste>> {
    global tcl_platform
    catch {
#        if {[string compare $tcl_platform(platform) "unix"]} {
            catch {
                %W delete sel.first sel.last
            }
#        }
        %W insert insert [selection get -displayof %W -selection CLIPBOARD]
        tkEntrySeeInsert %W
    }
}

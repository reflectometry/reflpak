
# ===================== console functions =====================
# HELP user
# Usage: plist list
#
# Display a list, one entry per line.
# E.g., plist [.graph conf]
proc plist { list } { foreach l $list { puts $l } }

# HELP user
# Usage: parray array
#
# Display an array, one entery per line.
# E.g., parray ::symbols

# parray is part of standard tcl

# ==================== resources ==============================

# HELP internal
# Usage: load_resources dir app
#
# Load the application specific resource defaults from the application
# source directory, and the user customizations from the user home
# directory.
#
# Sets the HOME variable according to the environment, or if HOME
# is not in the environment, use the start directory.
proc load_resources { base app } {
    # define HOME
    if { [info exists ::env(HOME)] } {
	set ::HOME $::env(HOME)
    } else {
	set ::HOME [ pwd ]
    }

    # application defaults
    set file [file join $base "${app}rc"]
    if [file exists $file] {
	if [catch { option readfile $file userDefault } err] {
	    app_fail "error in $file\n$err"
	}
    }

    # user defaults
    set file [file join $::HOME ".${app}rc"]
    if [file exists $file] {
	if [catch { option readfile $file userDefault } err] {
	    app_fail "error in $file\n$err"
	}
    }

    # find the real home as returned by pwd
    set dir [pwd]
    cd $::HOME
    set ::HOME [pwd]
    cd $dir
}

# HELP developer
# Usage: tildesub path
#
# Replace the portion of the file name corresponding to a user's
# home directory with ~.  To get the name of the directory containing
# a particular file, use:
#    tildesub [file normalize [file dirname $file]]
# This requires the ::HOME variable which is set by load_resources
proc tildesub { path } {
    if { [string match $::HOME* $path] } {
	return ~[string range $path [string length $::HOME] end]
    } else {
	return $path
    }
}

# ========================== help system ==========================

# HELP developer
# Usage: helpmenu menu homepage
#
# Adds a help entry to the given menu.  The menu path is the top
# level menu for your window.  It should not have a help menu
# already.  The homepage is the base for browsing off that menu.
#
# To add help files to an already existing help system, set
#    set ::helpstamp(complete_path_to_file) {}
# This will cause your help file to be loaded the next time
# you request help, or reloaded if it has changed.
#
# There is no support for the img:: tag in user help files at this
# time.

# HELP developer
# Usage: hpage page_name widgetlist text
#
# Defines a help page.
#
# To add help to your application you need to create help files which
# define the help pages.
#
# The markup format for hpage is described in htext.tcl.
#
# The help is context sensitive: when the user presses the help key (F1)
# on a specific widget a description of that widget or one of its
# enclosing widgets (e.g., the toplevel widget) is loaded.  That means
# you do not need help for every widget, but you should have help for
# every toplevel widget.
#
# When the user presses a different help key (Shift-F1), help on the
# corresponding keys and mouse clicks for the widget should be displayed.
# These pages are defined by
#    hpage {page_name controls} {} {text}
#
# Internal links are by page name, so you can refer to pages which are not
# associated with any widget.

# HELP developer
# Usage: help2html package ?extrafiles...
#
# System command to convert the help files to HTML.  Use this to
# test for dangling references in you help text.

# HELP internal
# Usage: help dir name ?name...
#
# Defines the files containing a help system. All files should be
# stored in the $dir/name.help.  The help files will be reloaded
# whenever they are changed which makes it easy to modify and test
# your help system.  Help is not loaded until the user requests it.
#
# By default, help for the controls for page_name is defined via:
#    hpage {page_name controls} {} text
# but you can change this to xxx using
#    bind all <Shift-F1> { gethelp %W xxx}
proc help { dir args } {
    set ::helpdir $dir
    foreach file $args { set ::helpstamp([file join $dir $file.help]) {} }

    # define help key
    # XXX FIXME XXX this should be a resource
    bind all <F1> { gethelp %W }
    bind all <Shift-F1> { gethelp %W controls }

}
proc helpmenu { menu homepage } {
    menu  $menu.help
    .menu add cascade -label Help -menu $menu.help
    $menu.help add command -label "Browse" -command [list gethelp $homepage]
    $menu.help add command -label "Index" -command { gethelp Index }
    $menu.help add command -label "Search" -command { gethelp Search }
    $menu.help add separator
    $menu.help add command -label "About" -command { gethelp About }
}
proc gethelp {args} {
    # ptrace
    rename gethelp {}
    source [file join $::helpdir htext.tcl]
    set htext::photodir $::helpdir
    namespace import htext::*
    proc gethelp { args } {
	# ptrace
	foreach path [array names ::helpstamp] {
	    # auto-reload help file based on modification time
	    set stamp [file mtime $path]
	    if { ![string equal "$stamp" "$::helpstamp($path)"] } {
		# puts "sourcing $path"
		source $path
		set ::helpstamp($path) $stamp
	    }
	}
	eval htext .htext $args
    }
    eval gethelp $args
}

# ========================== config info =============================
# Platform font defaults
switch $tcl_platform(platform) {
    unix {
	option add *Dialog.msg.font {Times -12} widgetDefault
	option add *Dialog.msg.wrapLength 6i widgetDefault
    }
    windows {
	option add *Graph.Legend.Font {Arial 7} widgetDefault
    }
}

# HELP internal
# Usage: tkcon
#
# Attach tkcon to a button, menu or keystroke to raise the Tcl
# console window.
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

# HELP developer
# Usage: package_available package
#
# Test whether a package is available, but do not load it.

proc package_available { package } {
    return [expr { [lsearch [package names] $package] >= 0 } ]
}

# HELP developer
# Usage: start_widget_browser root
# 
# Start the generic widget browser at the given root, or . if no
# root is specified.

proc start_widget_browser { { root . } } {
    if { [catch {
	if { ![info exists ::tablelist::library] } {
	    package require tablelist 
	    source [file join $::tablelist::library demos browse.tcl]
	}
	::demo::displayChildren $root
    } msg] } { app_error $msg }
}

# HELP developer
# Usage: app_error msg
#
# Display an error message. The error message may go to the console
# or to a message box depending on how the system is configured.

proc app_error { msg } {
    tk_messageBox -icon error -message $msg -type ok
}

# HELP developer
# Usage: app_fail msg
#
# Display a message and exit.  We need this because sometimes
# we are not running on the console, so we can't rely on the
# user seeing stdout/stderr.

proc app_fail { msg } {
    tk_messageBox -title $::argv0 -type ok -message $msg
    exit 1
}


# ==================== debugging =========================
# XXX FIXME XXX send automatic bug reports

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

# HELP internal
# Usage: tracing level
#
# Turn on a tcl function trace, saying which functions are entered
# and what values they return, up to a certain function call depth.
proc tracing { level } { ::tracing::init $level }

# HELP developer
# Usage: ptrace
#
# Display the fully qualified function name and argument
# values of the function that is executing
proc ptrace {} {
    set call [info level -1]
    set fn [uplevel namespace which -command [lindex $call 0]]
    set args [lrange $call 1 end]
    puts "[expr {[info level]-1}] $fn $args"
}

# =========================== greek character codes ==================
# HELP user
# Usage: symbol
#
# Array of strings representing Greek and math characters.
#
# Use $::symbol(Alpha) for uppercase alpha, $::symbol(alpha) for
# lowercase alpha, and so on for the rest of the greek alphabet.
#
# For a complete list of characters, type the command:
#
#   parray ::symbol
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

# HELP developer
# Usage: fix value ?min ?max ?digits
#
# Round a data value to the specified number of digits (default 3).
# For example, for limits of [ 0.175, 0.197 ] the data range
# is 0.022, so 1 digit of accuracy would be rounding to the
# nearest 0.01, 2 digits would be rounding to the nearest 0.001
# and three digits would be rounding to the nearest 0.0001.
# If min or max are not specified, reasonable values are chosen.
proc fix { value {min {}} {max {}} {accuracy 3}} {
    if { [string equal {} $max] } { set max $value }
    if { [string equal {} $min] } { set min $value }
    if { $max == $min } { set min 0.0 ; set max [expr {abs($max)}] }
    if { $max == $min } { set max 1.0 }
    set scale [expr {pow(10,ceil(log10($max-$min))-$accuracy)}]
    return [expr {round($value/$scale)*$scale}]
}

# HELP developer
# Usage: makereal a
#
# Force the number a to include a decimal point.  We need this because
# without a decimal point fortran formatted input assumes one at the user
# specified precision.
proc makereal {a} {
    if { [string match $a {}] } { set a 0 }
    return [ format %.15e $a ]
}

# HELP developer
# Usage: makeint a
#
# Round the value a and return the nearest integer.
proc makeint {a} {
    if { [string match $a {}] } { set a 0 }
    return [ expr {round($a)} ]
}

# HELP developer
# Usage: string_is_double a
#
# Returns true if the string could be a double value.  Note that
# unlike [string is double $a], string_is_double does not consider
# the empty string to be a double value.  Grrr...
proc string_is_double { a } {
    if [string equal $a {}] { return 0 }
    return [string is double $a]
}



# ======================= vector ops ==============================

# HELP user
# Usage: cumsum x
#
# Apply the cumulative sum operator to a vector.
proc cumsum { x } {
    set n [ $x length ]
    set sum 0.0
    for { set i 0 } { $i < $n } { incr i } {
	set ${x}($i) [set sum [expr {$sum + [set ${x}($i)]}]]
    }
}

# HELP developer
# Usage: vector exists
#
# Returns true if the named vector exists
proc vector_exists { x } {
    return [expr {![string equal {} [vector names $x]]}]
}

# ====================== date conversion =============================

# HELP developer
# Usage: clock_scan date
#
# Like [clock scan $date] except that
#     clock_scan "Jul  8 1996" is a valid date
#     clock_scan "" is not a valid date
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

# HELP internal
# Usage: load_colormaps
#
# Load the list of available colormaps from the resource file using
# option colormapList ColormapList.  The names in this list can
# refer to other resource file options colormap$name Colormap$name.
# These names can expand to any octave expression which returns a valid
# colormap, such as gray(64).  Otherwise, the name itself is used.
# Builtin colormaps include: hot cool gray ...
# See the code for the rest.
#
# The resulting names are loaded into ::colormap_list, and values
# are loaded into ::colormap_defs($name).

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

# HELP developer
# Usage: set_colormap name
#
# Sets the octave colormap to name.  If ::colormap_defs($name), the
# expression therein is used, otherwise colormap(name) is used
# directly.
#
# See psd.tcl(::psd::init) for an example.
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
    return [lindex $list [expr {$idx - 1}]]
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
    for { set idx [expr {$len - 1}] } { $idx >= 0 } { incr idx -1 } {
	if { [string equal $item [ $w get $idx ]] } {
	    $w delete $idx
	}
    }
}

# =================== scrolled window helper functions =================
## Usage: scroll .path_to_widget
##        vscroll .path_to_widget
##        hscroll .path_to_widget
## Returns a scrolled frame containing the widget which can be used
## directly to place the widget in grid or pack.  This widget will 
## be named .path_to_widget#box.
##
## E.g.,
##    toplevel .test
##    grid [label .test.textlabel -text "Text box"] -sticky ew
##    grid [scroll [text .test.text -wrap none]] -sticky news
##    grid columnconf .test 0 -weight 1
##    grid rowconf .test 1 -weight 1
##    .test.text insert end "Here you will see
## a bunch of text
## that I insert into my
## window to test that the
## scrollbars are working
## as expected.
##
## Resize the box to see
## them in action."


proc scroll { w } {
    ScrolledWindow ${w}#box
    ${w}#box setwidget $w
    raise $w
    return ${w}#box
}
proc vscroll { w } {
    ScrolledWindow ${w}#box -scrollbar vertical
    ${w}#box setwidget $w
    raise $w
    return ${w}#box
}
proc hscroll { w } {
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
    catch { $w edit reset } ;# Tk8.4 command to reset the undo stack
}

## Usage: text_append .path_to_text_widget "new text"
## append new text on the end of the text in the widget
proc text_append {w str} {
    set state [ $w cget -state ]
    $w conf -state normal
    $w insert end $str
    $w conf -state $state
    catch { $w edit reset } ;# Tk8.4 command to reset the undo stack
}

## Usage: text_clear .path_to_text_widget
## clear the text out of the widget
proc text_clear {w} {
    set state [ $w cget -state ]
    $w conf -state normal
    $w delete 0.0 end
    $w conf -state $state
    catch { $w edit reset } ;# Tk8.4 command to reset the undo stack
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
    catch { $w edit reset } ;# Tk8.4 command to reset the undo stack
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
    switch $state {
	"off" { blt::RemoveBindTag $w zoom-$w }
	"on" { blt::AddBindTag $w zoom-$w }
	default { error "{on|off}" }
    }
}


# active_legend graph ?callback
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
option add *Graph.LegendHide {-labelrelief flat} widgetDefault
option add *Graph.LegendShow {-labelrelief raised} widgetDefault
option add *Graph.Legend.activeRelief raised widgetDefault
option add *Graph.Element.labelRelief raised widgetDefault

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

# elem conf -hide now hides the legend entry.  Instead of hiding
# the line, we will replace its x-vector with legend_hidden, and set
# the element bindtag to {legend_hidden xdata-value}.  AFAICT, it won't
# hurt anything since the bind tag is never bound, and it has the
# advantage over a global variable in that it will be freed with the
# element.
blt::vector _legend_hidden
proc legend_toggle {w} {
    set line [$w legend get current]
    legend_set $w $line [legend_hidden $w $line]
}

proc legend_hidden {w line} {
    return [expr {[string equal ::_legend_hidden [$w elem cget $line -xdata]]}]
}

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

# active_axis graph axis ?callback
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
option add *Graph.selectPointText.Under 1 widgetDefault
# option add *Graph.Interpolate no widgetDefault
option add *Graph.showErrorbars both widgetDefault
option add *Graph.Crosshairs off widgetDefault
option add *Graph.Axis.ScrollIncrement 1 widgetDefault

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
    # XXX FIXME XXX -along doesn't seem to work in blt 2.4z. When it is fixed,
    # uncomment it where it occurs in this file and in viewrun.tcl.  May need
    # the interpolate keyword as well.
    $w element closest $x $y where -halo 1i ;#\
	    -along [option get $w interpolate Interpolate]
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
    $w element closest $x $y where -halo 1i ;#\
	    -interpolate [option get $w.Interpolate]
    if { [info exists where(x)] } {
	#puts "graph_select_press setting [lindex $::graph_select(points,$w) 0] $where(x)"
	foreach {x y el} [lindex $::graph_select(points,$w) 0] break
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

proc active_graph {w args} {

    switch -- $args {
        marker { return [set ::marker-$w] }
        element { return [set ::element-$w] }
    }
    set ::element-$w {}
    set ::marker-$w {}

    # Define the standard menu
    menu $w.menu -tearoff 1 -title "$w controls"
    $w.menu add command -label "Unzoom" -command "blt::ResetZoom $w"
    $w.menu add command -label "Pan" -command "pan::pan start $w"
    $w.menu add command -label "Crosshairs" -command "$w crosshairs toggle"
    if [blt_errorbars] {
	set ::errbar-$w [option get $w showErrorBars ShowErrorBars]
	$w.menu add command -label "Error bars" \
		-command "graph_toggle_error $w"
    }
    $w.menu add command -label "Grid" -command "$w grid toggle"
    if { [string equal windows $::tcl_platform(platform)] } {
        $w.menu add command -label "Copy" -command "$w snap -format emf CLIPBOARD"
    }
    $w.menu add command -label "Print" -command "PrintDialog $w"

    # Add zoom capability to graph, but use the menu to unzoom
    Blt_ZoomStack $w
    # bind zoom-$w <ButtonPress-2> [bind zoom-$w <ButtonPress-3>]
    bind zoom-$w <ButtonPress-3> {}
    bind $w <ButtonPress-3> {
	if {[%W inside %x %y]} {
            set ::marker-%W [%W marker get current]
            set ::element-%W [%W element get current]
            tk_popup %W.menu %X %Y 1 
        }
    }

    # Add panning capability
    ::pan::pan bind $w
}

proc graph_toggle_error {w} {
    if { [blt_errorbars] } {
	# XXX FIXME XXX this toggles between both/none.  There are also
	# options for x-only or y-only, but we will ignore these.  If your
	# data only has x or y errors, then both/none will work fine.
	if {[string equal [set ::errbar-$w] none]} {
	    set ::errbar-$w both
	} else {
	    set ::errbar-$w none
	}
	foreach el [$w element names] {
	    $w elem conf $el -showerrorbars [set ::errbar-$w]
	}
    }
}

# HELP developer
# Usage: blt_errorbars
#
# Returns true if you can use -yerror as an option to the blt graphs
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
# Usage graph_error .graph elem ?-xerror value ?-yerror value
#
# Associates error bars with the line.  Whether the error bars are
# shown depends on whether your version of BLT supports error bars
# and whether the
proc graph_error {w el args} {
    if { [blt_errorbars] } {
	eval $w elem conf $el $args -showerrorbars [set ::errbar-$w]
    }
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
## TkTable fake its own.
##
## table_entry::init p getset
##
##    Use an entry widget when editting the cells of table p.
##    The getset function retrieves the cell values.
##
## table_entry::reset p
##
##    The values underlying table p have changed.  Reset the
##    entry widget.
##
## where p is a tktable table widget and getset is an optional
## command to get/set entries.
##
## The following substitutions are done on the getset command:
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
##

## TODO: allow different widget types for each row/column/cell.

namespace eval table_entry {
    # The getset and window arrays are indexed by the table widget
    #   window is the index of the cell containing the entry widget,
    #     or {} if there is no entry widget
    #   getset is the callback for getting/setting cell values,
    #     or {} if there is no callback
    variable window
    variable getset
}

proc table_entry::init { w { gs "" } } {

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

    variable getset
    variable window
    set getset($w) $gs
    set window($w) {}

    # XXX FIXME XXX need to grab in cell/focus change requests from $w
    # while editting is in progress and either beep if the current cell
    # value is invalid, or move the edit widget if the value is good

    # Specific bindings for the keys.  These all generate virtual events
    # so that it is easier for users to override the key bindings.
    # XXX FIXME XXX can users put key bindings in the resource file?
    bind $w <Return> "event generate $w <<Edit>> ; break"
    catch { bind $w <ISO_Left_Tab> "event generate $w <<Left>> ; break" }
    bind $w <Shift-Tab> "event generate $w <<Left>> ; break"
    bind $w <KeyPress> "table_entry::_new %W %A ; break"
    bind $w <ButtonRelease-1> "$w activate @%x,%y; event generate $w <<Edit>>"

    # The commands associated with the virtual events
    bind $w <<Edit>> "table_entry::_select $w"
    bind $w <<Abort>> "table_entry::_edit $w"
    bind $w <<Accept>> "table_entry::_save $w"
    bind $w <<Right>> "table_entry::_save $w right"
    bind $w <<Left>> "table_entry::_save $w left"
    bind $w <<Up>> "table_entry::_save $w up"
    bind $w <<Down>> "table_entry::_save $w down"
}

# called when the user wants to revert to the original value
# or when the program has changed the table contents
proc table_entry::reset { w } {
    # ptrace
    variable window

    # remove the edit window if it is no longer in the table
    if { [llength $window($w)] } {
	if { [lindex [split $window($w) ,] 0] > [$w index end row] || \
		[lindex [split $window($w) ,] 1] > [$w index end col] } {
	    _entry clear $w
	}
    }

    # make sure something is active
    if { [catch { $w index active } ] } { $w activate origin }
    if { ![_can_edit $w active] } { $w activate origin }

    # edit the active cell
    if { [_can_edit $w active] } { _edit $w }
    # focus $w
}

# called when user starts typing a new value and there is no
# cell being editted
proc table_entry::_new { w char } {
    # ptrace
    # ignore titles and disabled fields
    if { ![_can_edit $w active] } { return }

    # put the user into an edit widget with the cursor at the end
    _entry set $w
    $w.entry delete 0 end
    $w.entry insert end $char
}

# called when user wants to edit a new cell
proc table_entry::_select { w } {
    # ptrace
    variable window

    # trying to edit a new cell before exitting the old cell
    if { [llength $window($w)]} {
	if { ![_can_edit $w active] } {
	    # can't edit the new cell, so don't leave the existing cell
	    $w activate $window($w)
	    focus $w.entry
	    return
	} else {
	    # need to save the old cell; save moves to new cell when it
	    # is done
	    _save $w [$w index active]
	    return
	}
    } else {
	# try editting the new cell
	if { [_can_edit $w active] } {
	    _edit $w
	}
    }
}

# called when user wants to edit an existing value
proc table_entry::_edit { w } {
    # ptrace
    variable getset

    # put the user in an edit widget with the cursor at the end
    _entry set $w

    # the value being editted may not correspond to the value
    # being displayed (e.g., =A1 is the stored value but 3.14
    # is the displayed value) so ask the caller for a new value
    $w.entry delete 0 end
    $w.entry insert end [_get $w]
    $w.entry selection range 0 end

}

# get the value from the active cell
proc table_entry::_get { w } {
    variable getset
    variable oldvalue
    if { ![string equal {} $getset($w)] } {
	set row [$w index active row]
	set col [$w index active col]
	set map [list %c "$col" %r "$row" %C "$row,$col" %W "$w" %i 0 \
		%s "[$w curval]" %S "{}"]
	set oldvalue [eval [string map $map $getset($w)]]
    } else {
	set oldvalue [$w curval]
    }
    return $oldvalue
}

# create an entry widget for the given cell of the table
proc table_entry::_entry { action w } {
    # ptrace
    variable window
    switch -- $action {
	set {
	    if { [llength $window($w)] } {
		if { ![string equal $window($w) [$w index active]] } {
		    $w window move $window($w) [$w index active]
		}
	    } else {
		# need a widget to edit with
		entry $w.entry
		bind $w.entry <Escape> "event generate $w <<Abort>> ; break"
		bind $w.entry <Return> "event generate $w <<Accept>> ; break"
		bind $w.entry <Up> "event generate $w <<Up>> ; break"
		bind $w.entry <Down> "event generate $w <<Down>> ; break"
		bind $w.entry <Tab> "event generate $w <<Right>> ; break"
		catch { bind $w.entry <ISO_Left_Tab> \
			"event generate $w <<Left>> ; break" }
		bind $w.entry <Shift-Tab> "event generate $w <<Left>> ; break"

		# attach it to the cell
		$w window conf active -window $w.entry -sticky news
	    }
	    set window($w) [$w index active]
	    focus $w.entry
	}
	clear {
	    if { [llength $window($w)] } {
		$w window delete $window($w)
		set window($w) {}
	    }
	}
    }
}

# navigation: need to know if a cell is edittable
proc table_entry::_can_edit { w cell } {
    # ptrace
    # Make sure that the requested cell is available,
    if { [catch { $w index $cell }] } { return 0 }
    # is not a title or disabled
    if { [$w tag includes title $cell] } { return 0 }
    if { [$w tag includes disabled $cell] } { return 0 }
    return 1
}


# called when the user is done editting and wants to save changes
# make sure that valid values are being entered into the table, and
# update the graph when the value changes
proc table_entry::_save { w {move ""}} {
    # ptrace
    variable window
    variable getset

    # try to save the current value
    if { [llength $window($w)] } {
	set row [$w index $window($w) row]
	set col [$w index $window($w) col]
	set val [$w.entry get]
	variable oldvalue
	if {![string equal $val oldvalue]} {
	    if { ![string equal {} $getset($w)] } {
		set map [list %c "$col" %r "$row" %C "$row,$col" %W "$w" %i 1 \
			%s "[$w get $window($w)]" %S [list $val]]
		set fail [catch [string map $map $getset($w)] success]
	    } else {
		set fail 0
		set success 1
		$w set $window($w) $val
	    }

	    if { $fail || $success == 0} {
		# The new value is bad so don't save it. Leave the user in the
		# edit widget (they can abort if they want to revert). The
		# callback should have reported any errors in an application
		# specific manner, so all we have to do is beep.
		bell

		# Force input back into the entry box
		$w activate $window($w)
		focus $w.entry
		return
	    }
	}
	# This is left over from the days when the entry window
	# was not always active
	# $w icursor end
	# focus $w
    } else {
	set row [$w index active row]
	set col [$w index active col]
    }

    # find the next cell according to move
    switch -- $move {
	up    { set idx [_move_up    $w $row $col ] }
	down  { set idx [_move_down  $w $row $col ] }
	right { set idx [_move_right $w $row $col ] }
	left  { set idx [_move_left  $w $row $col ] }
	""    { set idx $row,$col }
	default { set idx $move }
    }

    # move to that cell if it is different
    if { ![string equal $idx $row,$col] } {
	$w activate $idx
	$w see active
	_edit $w
    }
}

# navigation: user requested "up"
proc table_entry::_move_up {w row col} {
    # ptrace
    set top [$w index origin row]
    set start $row,$col
    incr row -1
    while {1} {
	if { $row < $top } {
	    return $start
	} elseif { [ _can_edit $w $row,$col] } {
	    return $row,$col
	} else {
	    incr row -1
	}
    }
}

# navigation: user requested "down"
proc table_entry::_move_down {w row col} {
    # ptrace
    set bottom [$w index end row]
    set start $row,$col
    incr row 1
    while {1} {
	if { $row > $bottom } {
	    return $start
	} elseif { [ _can_edit $w $row,$col ] } {
	    return $row,$col
	} else {
	    incr row
	}
    }
}

# navigation: user requested "left"
proc table_entry::_move_left {w row col} {
    # ptrace
    set top [$w index origin row]
    set left [$w index origin col]
    set right [$w index end col]
    set start $row,$col
    incr col -1
    while {1} {
	if { $col < $left } {
	    set col $right
	    incr row -1
	    if { $row < $top } { return $start }
	} elseif { [ _can_edit $w $row,$col] } {
	    return $row,$col
	} else {
	    incr col -1
	}
    }
}

# navigation: user requested "right"
proc table_entry::_move_right {w row col} {
    # ptrace
    set bottom [$w index end row]
    set left [$w index origin col]
    set right [$w index end col]
    set start $row,$col
    incr col
    while {1} {
	if { $col > $right } {
	    set col $left
	    incr row 1
	    if { $row > $bottom } { return $start }
	} elseif { [ _can_edit $w $row,$col] } {
	    return $row,$col
	} else {
	    incr col 1
	}
    }
}

# ======================= default key bindings ========================
# Paste into an entry should clear the current selection, especially
# on windows.
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


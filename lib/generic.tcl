package provide ncnrlib 0.1

# HELP developer
# Usage: opt widget property value property value ...
#
# Quick way to set a bunch of options and values in
# the options database using widgetDefault priority.
proc opt {w args} {
    set prefix "*[string range $w 1 end]"
    foreach {name val} $args {
        option add $prefix.$name $val widgetDefault 
    }
}

# ===================== console functions =====================
# HELP user
# Usage: plist list
#
# Display a list, one entry per line.
# E.g., plist [.graph conf]
#
# There is also a tkcon function dump widget which displays
# only the non-default widget options.
proc plist { list } { foreach l $list { puts $l } }

# HELP user
# Usage: parray array
#
# Display an array, one entery per line.
# E.g., parray ::symbols

# parray is part of standard tcl

# HELP winpath
# Usage: winpath
#
# Print the path to the next window you click on.
bind winpath <Button-1> { 
    puts [winfo containing %X %Y]
    grab release .tkcon
}
proc winpath {} {
    set tags [bindtags .tkcon]
    if { [lsearch $tags winpath]<0 } {
	bindtags .tkcon [concat winpath $tags]
    }
    grab set .tkcon
}

# ==================== resources ==============================

# HELP developer
# Usage: HOME ?newhome
#
# Sets or returns the home directory.  HOME is taken from
# the environment variable USERPROFILE if it exists,
# or from the environment variable HOME if it exists,
# or from the current directory.
#
# TODO: On windows, this should look for the appropriate
# TODO: registry keys for application settings if HOME
# TODO: does not exist.
proc HOME { args } {
    if { [llength $args] == 1 } {
	set ::HOME [lindex $args 0]
    } elseif { [llength $args] > 1 } {
	error "usage: HOME ?newhome"
    }

    if { ![info exists ::HOME] } {
	# Get the home directory from the environment, returning
	# the value from pwd.  We do it this way because we want
	# tilde substitution to work even when $HOME contains
	# a path with a symbolic link.  The pwd command returns the
	# actual path rather than linked path.
	set startdir [ pwd ]
	if { [catch { cd $::env(USERPROFILE) }] } {
	    if { [catch { cd $::env(HOME) }] } {
		set ::HOME $startdir
		return $::HOME
	    }
	}
	set ::HOME [ pwd ]
	cd $startdir
    }

    return $::HOME
}

# HELP developer
# Usage: load_resources dir app
#
# Load the application specific resource defaults from $dir/${app}rc
# and the user customizations from $HOME/.${app}rc.
#
# XXX FIXME XXX we need something more clever under windows
# since generally there is no home directory.  Where can
# we put .${app}rc?
proc load_resources { dir app } {

    # application defaults
    set file [file join $dir "${app}rc"]
    if [file exists $file] {
	if [catch { option readfile $file startupFile } err] {
	    app_fail "error in $file\n$err"
	}
    }

    # user defaults
    set file [file join [HOME] ".${app}rc"]
    if [file exists $file] {
	if [catch { option readfile $file userDefault } err] {
	    app_fail "error in $file\n$err"
	}
    }

}

# HELP developer
# Usage: tildesub path
#
# Replace the portion of the file name corresponding to a user's
# home directory with ~.  To get the name of the directory containing
# a particular file, use:
#    tildesub [file normalize [file dirname $file]]
proc tildesub { path } {
    if { [string match [HOME]* $path] } {
	return ~[string range $path [string length [HOME]] end]
    } else {
	return $path
    }
}

# ========================== help system ==========================

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

# HELP developer
# Usage: help dir name ?name...
#
# Defines the files containing a help system. All files should be
# stored in the $dir/name.help.  The help files will be reloaded
# whenever they are changed which makes it easy to modify and test
# your help system.  Help is not loaded until the user requests it.
#
# Currently all help files must reside in the directory containing
# htext.tcl.  This directory must be specified for each set of help
# files that you add.  This is probably going to be your application
# source directory.
proc help { dir args } {
    set ::helpdir $dir
    namespace eval ::Htext { variable photdir; set photodir $::helpdir }
    foreach file $args { set ::helpstamp([file join $dir $file.help]) {} }

    # define help key
    # XXX FIXME XXX this should be a resource
    bind all <F1> { gethelp %W }
    bind all <Shift-F1> { gethelp %W controls }

    # XXX FIXME XXX currently all help files need to be in the same
    # directory.  It is conceivable that a plugin might want to keep
    # its files in a separate directory.  Note that images also use
    # the same directory.
}

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
proc helpmenu { menu homepage } {
    menu  $menu.help
    .menu add cascade -label Help -menu $menu.help
    $menu.help add command -underline 0 -label "Browse" -command [list gethelp $homepage]
    $menu.help add command -underline 0 -label "Index" -command { gethelp Index }
    $menu.help add command -underline 0 -label "Search" -command { gethelp Search }
    $menu.help add separator
    $menu.help add command -underline 0 -label "About" -command { gethelp About }
}

# HELP developer
# Usage: gethelp page
# 
# Used by the menu system and by the context sensitive help system to
# load a help page.  You could also use this if you want to add a help
# button to a dialog.
proc gethelp {args} {
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

# ========================== config info =============================

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


# Usage: message ?[--|-bell|-box|-error|-fail] ?"text"
# Warn the user about something.  Works without GUI.  Uses the
# message widget of the window containing the focus or opens a
# warning dialog if not message widget is present.
# FIXME: need to support several warnings from the same action
# FIXME: need function to add status bar to toplevel
proc message { args } {
    if { [string match "-*" [lindex $args 0]] } {
	set opts [lindex $args 0]
	set msg [lindex $args 1]
    } else {
	set opts "--"
	set msg [lindex $args 0]
    }
    if {![info exists ::tk_version]} {
	# running without GUI, so output message to terminal
	switch -- $opts {
	    -- { set tag "" }
	    -bell { set tag "!" }
	    -box { set tag "warning: " }
	    -error { set tag "error: " }
	    -fail { set tag "fatal: " }
	}
	if {$msg != ""} { puts "$tag$msg" }
    } else {
	# If no message widget, force use of a warning box
	if { [catch {set top [winfo toplevel [focus]]}] } { set top none }
	if { $top == "." } { 
	    set msgbox .message 
	} else {
	    set msgbox $top.message
	}
	if {![winfo exists $msgbox] && ($opts=="--" || $opts=="-bell")} {
	    set opts -box
	}

	switch -- $opts {
	    -- { $msgbox conf -text $msg }
	    -bell { $msgbox conf -text $msg; bell }
	    -box {
		if {$msg != "" } {
		    tk_messageBox -title "$::argv0 Warning" -type ok \
			-icon warning -message $msg -parent $top
		}
	    }
	    -error - -fail {
		if {$msg != "" } {
		    tk_messageBox -title "$::argv0 Error" -type ok \
			-icon error -message $msg -parent $top
		}
	    }
	}
    }

    if { $opts == "-fail" } { exit 1 }
}

proc question {msg} {
    set answer [tk_messageBox -type yesno -icon question -message $msg]
    return [expr {$answer == "yes"}]
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
# values of the function that is executing.  By adding this
# to the top of a function you are debugging, you immediately
# give a context to the puts debugging statements you add to
# the function.
proc ptrace { {msg {}} } {
    # show the windows console if necessary
    catch {
	if { ![winfo exists .tkcon] } {
	    if { [console eval { wm state . }] eq "withdrawn" } { 
		console show 
	    }
	}
    }
    # find the caller info
    if { [info level] > 1 } {
	set call [info level -1]
    } else {
	set call {}
    }
    set fn [uplevel [list namespace which -command [lindex $call 0]]]
    # if no message, report calling parameters
    if { $msg eq "" } {
	set msg "called with [lrange $call 1 end]"
    }
    # display message
    puts "[expr {[info level]-1}] $fn $msg"
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
# Usage: vector_exists
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
# HELP developer
# Usage: asearch arrayname value
#
# Reverse lookup into an associative array.
#
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
# HELP developer
# Usage: sashconf w
# 
# BWidget does not use the option database for its widgets.  This 
# procedure replaces the configuration options used by BWidget for
# setting the sash properties of a PanedWindow with resources from
# the database.  Use the following database resources:
#
#   *sash1.but.size: long wide
#   *sash1.but.background: color
#
# XXX FIXME XXX we should probably use $w.sashsize and $w sashbackground
# rather than exporting details of the PanedWindow hierarchy to the
# resource file, but that's a project for another day.
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
# HELP developer
# Usage: listbox_ordered_insert .path_to_listbox item
# 
# Put the item into the listbox in alphabetical order
proc listbox_ordered_insert { w item } {
    set len [ $w size ]
    for { set idx 0 } { $idx < $len } { incr idx } {
	if { [string compare -nocase $item [ $w get $idx ]] < 0 } { break }
    }
    $w insert $idx $item
    return $idx
}

# HELP developer
# Usage: listbox_delete_by_name .path_to_listbox name
# 
# Remove an item from a listbox according to the item name.
proc listbox_delete_by_name { w item } {
    set len [ $w size ]
    for { set idx [expr {$len - 1}] } { $idx >= 0 } { incr idx -1 } {
	if { [string equal $item [ $w get $idx ]] } {
	    $w delete $idx
	}
    }
}

# =================== scrolled window helper functions =================
# HELP developer
# Usage: scroll .path_to_widget ?-scrollbar [vertical|horizontal]?
#        vscroll .path_to_widget
#        hscroll .path_to_widget
# Returns a scrolled frame containing the widget which can be used
# directly to place the widget in grid or pack.  This widget will 
# be named .path_to_widget#box.
#
# E.g.,
#    toplevel .test
#    grid [label .test.textlabel -text "Text box"] -sticky ew
#    grid [scroll [text .test.text -wrap none]] -sticky news
#    grid columnconf .test 0 -weight 1
#    grid rowconf .test 1 -weight 1
#    .test.text insert end "Here you will see
# a bunch of text
# that I insert into my
# window to test that the
# scrollbars are working
# as expected.
#
# Resize the box to see
# them in action."


proc scroll { w args } {
    eval [linsert $args 0 ScrolledWindow ${w}#box]
    $w#box configure -borderwidth [$w cget -borderwidth] -relief [$w cget -relief]
    $w configure -borderwidth 0
    $w#box setwidget $w
    raise $w
    return $w#box
}
proc vscroll { w } { return [scroll $w -scrollbar vertical] }
proc hscroll { w } { return [scroll $w -scrollbar horizontal] }

# ==================== text widget helper functions ====================

# HELP developer
# Usage: text_replace .path_to_text_widget "new text value"
#
# replace the text in the widget with the new text value
proc text_replace {w str} {
    set state [ $w cget -state ]
    $w conf -state normal
    $w delete 0.0 end
    $w insert 0.0 $str
    $w conf -state $state
    catch { $w edit reset } ;# Tk8.4 command to reset the undo stack
}

# HELP developer
#
# Usage: text_append .path_to_text_widget "new text"
# append new text on the end of the text in the widget
proc text_append {w str} {
    set state [ $w cget -state ]
    $w conf -state normal
    $w insert end $str
    $w conf -state $state
    catch { $w edit reset } ;# Tk8.4 command to reset the undo stack
}

# HELP developer
# Usage: text_clear .path_to_text_widget
#
# clear the text out of the widget
proc text_clear {w} {
    set state [ $w cget -state ]
    $w conf -state normal
    $w delete 0.0 end
    $w conf -state $state
    catch { $w edit reset } ;# Tk8.4 command to reset the undo stack
}

# HELP developer
# Usage: text_load .path_to_text_widget "filename"
#
# replace the text in the widget with the contents of the file
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
# HELP developer
# Usage: ldelete list value
#
# Delete a particular value from a list
proc ldelete { list value } {
    set index [ lsearch -exact $list $value ]
    if { $index >= 0 } {
	return [lreplace $list $index $index]
    } else {
	return $list
    }
}

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
# the line, we will replace its x-vector with _legend_hidden, and set
# the element bindtag to {legend_hidden xdata-value}.  AFAICT, it won't
# hurt anything since the bind tag is never bound, and it has the
# advantage over a global variable in that it will be freed with the
# element.
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
#    graph_select .graph {x y name idx}
# selects a single point and stores it in ::x, ::y.  The name of the line
# element containing the point is stored in ::name and the index is stored
# in ::idx
#    graph_select_list .graph var
# selects a set of points; when complete var is set to {{x1 y1 name1 idx1}
# ... {xk yk namek idxk}}.  Use vwait $var to synchronize.

# XXX FIXME XXX should have a way to select a list of points of unknown
# length.
# XXX FIXME XXX should be able to restrict the points to a subset of the
# available elements.
bind graph_select <Motion> {graph_select_motion %W %x %y}
bind graph_select <Button-1> {graph_select_press %W %x %y; break}
bind graph_select <B1-ButtonRelease> {graph_select_release %W %x %y; break}
bind graph_select <Button-3> { break }
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
    # ptrace "adding tag to [bindtags $w] for $w"
    bindtags $w [concat graph_select [bindtags $w]]
    # XXX FIXME XXX is there a way to save and restore stacking order?
    raise [winfo toplevel $w]
    $w marker create text -name selectPointText \
	    -text "Click to select [lindex $args 0]\nRight-Click to cancel"
    grab set $w
}

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

proc graph_select_release {w x y} {
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

# bind zoom-$w <ButtonPress-3> {}
bind active_graph <ButtonPress-3> { graph_activate_menu %W %X %Y %x %y; break }
bind active_graph <Motion> { graph_motion %W %x %y }
bind active_graph <Leave> { graph_motion_clear %W }

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

proc graph_motion {w x y} {
    # Move crosshairs to the current point
    $w crosshairs conf -position @$x,$y

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

    # Generate the default message as "legend_label:index (x, y)"
    $w element closest $x $y where -halo 1i
    if { ![info exists where(x)] } { 
	$wmsg configure -text ""
	return 
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
	
	# Update the message bar
	$wmsg configure -text $msg
    }
}
    
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
    $w.menu add command -underline 0 -label "Print" -command "PrintDialog $w"

    # Add zoom capability to graph, but use the menu to unzoom
    Blt_ZoomStack $w
    # bind zoom-$w <ButtonPress-2> [bind zoom-$w <ButtonPress-3>]
    bindtags $w [concat active_graph [bindtags $w]]

    # Add panning capability
    pan bind $w
}

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
	eval $w elem conf $el $args -showerrorbars $::active_graph($w,errbar)
    }
}

# ========================= Forms interface =======================

# HELP developer
# Usage: addfields .pathtoframe { field field ... }
#
#     where field is
#      { real variable label units help }
#      { string variable label comments help }
#      { bool variable label help }
#
# Primitive form layout manager
# Variable is placed in widget named .pathtoframe.variable
# Uses grid packing manager (3 columns)

# We can do a lot better here.  E.g., mini.net/tcl/layout
# but I'm sure we can do better than that.

proc addfields { frame fields } {
    foreach f $fields {
	switch -exact -- [lindex $f 0] {
	    string -
	    real { # variable label units
		set vname [lindex $f 1]
		set label [lindex $f 2]
		set units [lindex $f 3]
		set help [lindex $f 4]
		set lidx $frame.$vname-label
		label $lidx -text $label
		set eidx $frame.$vname
		entry $eidx -textvariable $vname
		if { $units != "" } {
		    set uidx $frame.$vname-units
		    label $uidx -text $units
		} else {
		    set uidx x
		}
		if { $help != "" } { balloonhelp $frame.$vname-label $help }
		grid $lidx $eidx $uidx -sticky w
		grid configure $eidx -sticky ew
	    }

	    bool { # variable label
		set vname [lindex $f 1]
		set label [lindex $f 2]
		set help [lindex $f 3]
		set idx $frame.$vname
		checkbutton $idx -text $label -variable $vname
		grid $idx - - -sticky w
		if { $help != "" } { balloonhelp $frame.$vname $help }
	    }
	    default {
		# set { set of check buttons }
		# choice { (list of choices }
		# int { integer value }
		error "Unknown field type [lindex $f 0]"
	    }
	}
    }
    grid columnconfigure $frame 1 -weight 1 -minsize 1c
}


# ======================= default key bindings ========================
# Paste into an entry should clear the current selection, especially
# on windows.
# XXX FIXME XXX do we want to override the default bindings?
bind Entry <<Paste>> {
    global tcl_platform
    catch {
	catch { %W delete sel.first sel.last }
	%W insert insert [selection get -displayof %W -selection CLIPBOARD]
	tkEntrySeeInsert %W
    }
}

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
# Usage: isgui
#
# Return true if Tk constructs such as tk_messageBox are allowed.
proc isgui {} {
    return [info exists ::tk_version]
}

# HELP developer
# Usage: app_error msg
#
# Display an error message. The error message may go to the console
# or to a message box depending on how the system is configured.
#
# Deprecated: use "message -error" instead
proc app_error { msg } {
    if {[isgui]} {
	tk_messageBox -icon error -message $msg -type ok
    } else {
	puts "Error: $msg"
    }
}

# HELP developer
# Usage: app_fail msg
#
# Display a message and exit.  We need this because sometimes
# we are not running on the console, so we can't rely on the
# user seeing stdout/stderr.
#
# Deprecated: use "message -error" instead

proc app_fail { msg } {
    if {[isgui]} {
	tk_messageBox -title $::argv0 -type ok -message $msg
    } else {
	puts "Fatal: $msg"
    }
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
    if {![isgui]} {
	# running without GUI, so output message to terminal
	switch -- $opts {
	    -- { set tag "" }
	    -bell { set tag "!" }
	    -box { set tag "Warning: " }
	    -error { set tag "Error: " }
	    -fail { set tag "Fatal: " }
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
	if { $top eq "none" } { set parent . } { set parent $top }

	switch -- $opts {
	    -- { $msgbox conf -text $msg }
	    -bell { $msgbox conf -text $msg; bell }
	    -box {
		if {$msg != "" } {
		    tk_messageBox -title "$::argv0 Warning" -type ok \
			-icon warning -message $msg -parent $parent
		}
	    }
	    -error - -fail {
		if {$msg != "" } {
		    tk_messageBox -title "$::argv0 Error" -type ok \
			-icon error -message $msg -parent $parent
		}
	    }
	}
    }

    if { $opts == "-fail" } { exit 1 }
}

proc question {msg} {
    if {[isgui]} {
	set answer [tk_messageBox -type yesno -icon question -message $msg]
	return [expr {$answer == "yes"}]
    } else {
	puts -nonewline "$msg \[y/n] "
	flush stdout
	gets stdin answer
	return [expr {$answer == "y"}]
    }
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


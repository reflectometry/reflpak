#!/bin/sh
# \
exec wish "$0" "$@"

# This code is in the public domain.

package provide tableentry 0.1

##-----------------------------------------------------------------
## PROCEDURE
##	tableentry
##
## DESCRIPTION
##	Provides a roving entry widget for Tktable input
##
## ARGUMENTS
##	tableentry w ?getset?
##
##      where w is a tktable table widget and getset is an optional
##	command to get/set entries.  See below for details.
##      
## BINDINGS
##
##      <Return> generates <<Accept>> to update table with current edit value
##      <Escape> generates <<Abort>> to recover original value from the table
##      <Up>     generates <<Up>> to move up in the current column
##      <Down>   generates <<Down>> to move down in the current column
##      <Tab>    generates <<Right>> to move to the next column or the start
##               of the next row if there are no more columns
##      <Shift-Tab> generates <<Left>> to move to the previous column or to
##               the end of the previous row if there are no more columns.

##-----------------------------------------------------------------
## PROCEDURE
##	tableentry::reset
##
## DESCRIPTION
##	When the table values have changed from outside the table
##	(e.g., because the user loads a new table from disk), the
##	program should use "$w clear cache" to reset the tktable
##	values and "tableentry::reset $w" to reset the roving entry
##	widget.
##
## ARGUMENTS
##	tableentry::reset w

##-----------------------------------------------------------------
## GET/SET COMMAND
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
## This need not be the same as the value displayed in the table.  
## For example, the display value may be chopped to 4 significant 
## figures, but all the digits are retained and available for 
## editting.  Or the display value is the number, but the stored 
## entry is a command such as =A6 which gets displayed as the 
## contents of row 1, column 6 of the table.
##
## If set returns 0 we continue editting the current field.
## That way set can be used to validate the entries.  The
## caller is responsible for ringing the bell and displaying
## a message.  Focus stays in the window until set returns 1.
##
## The get/set command will only be called for edittable cells, not
## for title or disabled cells.  For example, to disable cell 3,3
## use $w tag cell disabled 3,3.

## TODO: allow different widget types for each row/column/cell.
## TODO: moving focus within the application should save the entry
## TODO: make tableentry::reset happen automatically

namespace eval tableentry {
    
    namespace export -clear tableentry reset ?

    # The getset and window arrays are indexed by the table widget
    #   window is the index of the cell containing the entry widget,
    #     or {} if there is no entry widget
    #   getset is the callback for getting/setting cell values,
    #     or {} if there is no callback
    variable window
    variable getset

    proc tableentry { w { gs "" } } {

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
	foreach seq [bind Table] { bind $w $seq { continue } }
	
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
	bind $w <Return> { event generate %W <<Edit>> ; break }
	catch { 
	    bind $w <ISO_Left_Tab> { event generate %W <<Left>> ; break } 
	}
	bind $w <Shift-Tab> { event generate %W <<Left>> ; break }
	bind $w <KeyPress> [namespace code {_new %W %A ; break}]
	bind $w <ButtonRelease-1> { 
	    %W activate @%x,%y; event generate %W <<Edit>> 
	}
	## XXX FIXME XXX Should we remove the edit window when we leave
	## the table?  What happens when the user clicks a button without
	## first saving the value?  What if there is an error while saving
	## the variable?
	# bind $w <FocusOut> [namespace code { _save %W }]
	# bind $w <FocusIn>  [namespace code { reset %W }]
	
	# The commands associated with the virtual events
	bind $w <<Edit>>   [namespace code { _select %W }]
	bind $w <<Abort>>  [namespace code { _edit %W }]
	bind $w <<Accept>> [namespace code { _save %W }]
	bind $w <<Right>>  [namespace code { _save %W right}]
	bind $w <<Left>>   [namespace code { _save %W left}]
	bind $w <<Up>>	   [namespace code { _save %W up}]
	bind $w <<Down>>   [namespace code { _save %W down}]
    }

    # called when the user wants to revert to the original value
    # or when the program has changed the table contents
    proc reset { w } {
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
    proc _new { w char } {
	# ptrace
	# ignore titles and disabled fields
	if { ![_can_edit $w active] } { return }
	
	# put the user into an edit widget with the cursor at the end
	_entry set $w
	$w.entry delete 0 end
	$w.entry insert end $char
    }
    
    # called when user wants to edit a new cell
    proc _select { w } {
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
    proc _edit { w } {
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
    proc _get { w } {
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

    # helper function to convert entry events to table events
    proc _entry_event { w ev } {
	return "event generate $w $ev ; break"
    }

    # create an entry widget for the given cell of the table
    proc _entry { action w } {
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

		    # bind the motion keys to the editting widget
		    bind $w.entry <Escape> [_entry_event $w <<Abort>>]
		    bind $w.entry <Return> [_entry_event $w <<Accept>>]
		    bind $w.entry <Up>     [_entry_event $w <<Up>>]
		    bind $w.entry <Down>   [_entry_event $w <<Down>>]
		    bind $w.entry <Tab>    [_entry_event $w <<Right>>]
		    catch {
			bind $w.entry <ISO_Left_Tab> [_entry_event $w <<Left>>]
		    }
		    bind $w.entry <Shift-Tab> [_entry_event $w <<Left>>]
		    
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
    proc _can_edit { w cell } {
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
    # update the graph when the value changes; returns 1 if save is
    # successful, or 0 otherwise
    proc _save { w {move ""}} {
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
		    set map [list %c $col %r $row %C $row,$col %W $w %i 1 \
				 %s [$w get $window($w)] %S [list $val]]
		    if {[catch [string map $map $getset($w)] success]} {
			#bell
			#if { ![string equal $success {}] } {
			#    tk_messageBox -type ok -icon error \
			#	-message $success -parent $w
			#}
			set success 0
		    }
		} else {
		    set success 1
		    $w set $window($w) $val
		}
		
		if { !$success } {
		    # The new value is bad so don't save it. Leave the user in
		    # the edit widget (they can abort if they want to revert).
		    # The callback should have reported any errors in an 
		    # application specific manner.
		    $w activate $window($w)
		    focus $w.entry
		    return 0
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

	return 1
    }
    
    # navigation: user requested "up"
    proc _move_up {w row col} {
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
    proc _move_down {w row col} {
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
    proc _move_left {w row col} {
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
    proc _move_right {w row col} {
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
    
    proc ? {} {lsort [namespace export]}
}

# define tableentry in the global scope
namespace eval :: {namespace import -force ::tableentry::tableentry}

#--------------------------- Self-test code
if {[info exists argv0] && [file tail [info script]]==[file tail $argv0]} {
    switch -- [lindex $argv 0] {
	-version {
	    puts "tableentry [package present tableentry] exports [list [tableentry::?]]"
	    exit
	}

	"" - -demo {
	    package require Tktable
	    array set demodata { 
		0,0 ""  0,1  A  0,2  B  0,3  C
		1,0  1  1,1  0  1,2  0  1,3  0 
		2,0  2  2,1  0  2,2  0  2,3  0 
		3,0  3  3,1  0  3,2  0  3,3  0 
	    }
	    proc table_reset {} {
		array set ::demodata [list 1,1 [expr {4*atan(1)}] \
					  1,2 [expr {exp(1)}] \
					  2,1 [expr {sqrt(2)}] \
					  2,2 [expr {1}] ]
		.t clear cache
		tableentry::reset .t
	    }
	    proc show_entry {row col} {
		if { $row < 1 || $col < 1} {
		    return $::demodata($row,$col)
		} else {
		    return [format "%.5g" $::demodata($row,$col)]
		}
	    }
	    proc edit_entry { isset row col val } {
		if {!$isset} {
		    return $::demodata($row,$col)
		} elseif {[string equal {} $val] || ![string is double $val]} {
		    bell
		    return 0
		} else {
		    set ::demodata($row,$col) $val
		    return 1
		}
	    }
		    
	    table .t -titlerows 1 -titlecols 1 -rows 4 -cols 4 \
		-command { show_entry %r %c } -usecommand yes \
		-resizeborders col -colwidth 10 -colstretch unset
	    .t tag configure title -relief raised
	    .t width 0 6
	    tableentry .t { edit_entry %i %r %c %S }
	    entry .e
	    button .reset -text Reset -command { table_reset }
	    grid .t -sticky ew
	    grid .e -sticky ew
	    grid .reset -sticky e
	    grid columnconfigure . 0 -weight 1
	    table_reset
	}

	-index {
	    # Simple index generator, if the directory contains only this package
	    pkg_mkIndex -verbose [file dirname [info script]] [file tail [info script]]
	    exit
	}

	default {
	    puts "Usage: tableentry.tcl ?args"
	    puts ""
	    puts "  -version version info and function list"
	    puts "  -index   generate pkgIndex.tcl"
	    puts "  -demo    run demo"
	    exit
	}
    }
}

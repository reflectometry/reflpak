# Supertext.tcl v1.0b1
#
# Copyright (c) 1998 Bryan Oakley
# All Rights Reserved
#
# this code is freely distributable, but is provided as-is with
# no waranty expressed or implied.

# send comments to boakley@austin.rr.com

# What is this?
# 
# This is a replacement for (or superset of , or subclass of, ...) 
# the tk text widget. Its big feature is that it supports unlimited
# undo. It also has two poorly documented options: -preproc and 
# -postproc. 

# The entry point to this widget is Supertext::text; it takes all of
# the same arguments as the standard text widget and exhibits all of
# the same behaviors.  The proc Supertext::overrideTextCommand may be
# called to have the supertext widget be used whenever the command
# "text" is used (ie: it imports Supertext::text as the command "text"). 
# Use at your own risk...

# To access the undo feature, use ".widget undo". It will undo the
# most recent insertion or deletion. On windows and the mac
# this command is bound to <Control-z>; on unix it is bound to
# <Control-_>.  Use ".widget undo clear" to clear the undo stack.

# if you are lucky, you might find documentation here:
# http://www1.clearlight.com/~oakley/tcl/supertext.html

package provide Supertext 1.0

namespace eval Supertext {

    variable undo
    variable undoIndex
    variable text "::text"
    variable preProc
    variable postProc

    namespace export text
}

# this proc is probably attempting to be more clever than it should...
# When called, it will (*gasp*) rename the tk command "text" to "_text_", 
# then import our text command into the global scope. 
#
# Use at your own risk!

proc Supertext::overrideTextCommand {} {
    variable text

    set text "::_text_"
    rename ::text $text
    uplevel #0 namespace import Supertext::text
}

proc Supertext::text {w args} {
    variable text
    variable undo
    variable undoIndex
    variable preProc
    variable postProc

    # this is what we will rename our widget proc to...
    set original __$w

    # do we have any of our custom options? If so, process them and 
    # strip them out before sending them to the real text command
    if {[set i [lsearch -exact $args "-preproc"]] >= 0} {
	set j [expr $i + 1]
	set preProc($original) [lindex $args $j]
	set args [lreplace $args $i $j]
    } else {
	set preProc($original) {}
    }

    if {[set i [lsearch -exact $args "-postproc"]] >= 0} {
	set j [expr $i + 1]
	set postProc($original) [lindex $args $j]
	set args [lreplace $args $i $j]
    } else {
	set postProc($original) {}
    }

    # let the text command create the widget...
    eval $text $w $args

    # now, rename the resultant widget proc so we can create our own
    rename ::$w $original

    # here's where we create our own widget proc.
    proc ::$w {command args} \
        "namespace eval Supertext widgetproc $w $original \$command \$args"
    
    # set up platform-specific binding for undo; the only one I'm
    # really sure about is winders; what should the mac be? On unix
    # I just picked what I'm used to in emacs :-)
    switch $::tcl_platform(platform) {
	unix 		{event add <<Undo>> <Control-z>}
	windows 	{event add <<Undo>> <Control-z>}
	macintosh 	{event add <<Undo>> <Control-z>}
    }
    bind $w <<Undo>> "$w undo"

    set undo($original)	{}
    set undoIndex($original) -1
    set clones($original) {}

    return $w
}

# this is the command that we associate with a supertext widget. 
proc Supertext::widgetproc {this w command args} {

    variable undo
    variable undoIndex
    variable preProc
    variable postProc

    # these will be the arguments to the pre and post procs
    set originalCommand $command
    set originalArgs $args

    # is there a pre-proc? If so, run it. If there is a problem,
    # die. This is potentially bad, because once there is a problem
    # in a preproc the user must fix the preproc -- there is no
    # way to unconfigure the preproc. Oh well. The other choice
    # is to ignore errors, but then how will the caller know if
    # the proc fails?
    if {[info exists preProc($w)] && $preProc($w) != ""} {
	if {[catch "$preProc($w) command args" error]} {
	    return -code error "error during processing of -preproc: $error"
	}
    }


    # if the command is "undo", we need to morph it into the appropriate
    # command for undoing the last item on the stack
    if {$command == "undo"} {

	# if given undo clear, then clear out the list of undo ops
	if { $args == "clear" } {
	    set undo($w)	{}
	    set undoIndex($w) -1

	} elseif { $args != {} } {
	    ?* { error "bad option \"$args\": must be clear" }

	} else {

	    if {$undoIndex($w) == ""} {
		# ie: last command was anything _but_ an undo...
		set undoIndex($w) [expr [llength $undo($w)] -1]
	    }

	    # if the index is pointing to a valid list element, 
	    # lets undo it...
	    if {$undoIndex($w) < 0} {
		# nothing to undo...
		bell
		
	    } else {
		
		# data is a list comprised of a command token
		# (i=insert, d=delete) and parameters related 
		# to that token
		set data [lindex $undo($w) $undoIndex($w)]
		
		if {[lindex $data 0] == "d"} {
		    set command "delete"
		} else {
		    set command "insert"
		}
		set args [lrange $data 1 end]
		
		# adjust the index
		incr undoIndex($w) -1
		
	    }
	}
    }

    # now, process the command (either the original one, or the morphed
    # undo command
    switch $command {

	configure {
	    # we have to deal with configure specially, since the
	    # user could try to configure the -preproc or -postproc
	    # options...
	    
	    if {[llength $args] == 0} {
		# first, the case where they just type "configure"; lets 
		# get it out of the way
		set list [$w configure]
		lappend list [list -preproc preproc Preproc {} $preProc($w)]
		lappend list [list -postproc postproc Postproc {} $postProc($w)]
		set result $list
		
		
	    } elseif {[llength $args] == 1} {
		# this means they are wanting specific configuration 
		# information
		set option [lindex $args 0]
		if {$option == "-preproc"} {
		    set result [list -preproc preproc Preproc {} $preProc($w)]

		} elseif {$option == "-postproc"} {
		    set result [list -postproc postproc Postproc {} $postProc($w)]
		    
		} else {
		    if {[catch "$w $command $args" result]} {
			regsub $w $result $this result
			return -code error $result
		    }
		}

	    } else {
		# ok, the user is actually configuring something... 
		# we'll deal with our special options first
		if {[set i [lsearch -exact $args "-preproc"]] >= 0} {
		    set j [expr $i + 1]
		    set preProc($w) [lindex $args $j]
		    set args [lreplace $args $i $j]
		    set result {}
		}

		if {[set i [lsearch -exact $args "-postproc"]] >= 0} {
		    set j [expr $i + 1]
		    set postProc($w) [lindex $args $j]
		    set args [lreplace $args $i $j]
		    set result {}
		}

		# now, process any remaining args
		if {[llength $args] > 0} {
		    if {[catch "$w $command $args" result]} {
			regsub $w $result $this result
			return -code error $result
		    }
		}
	    }
	}

	undo {
	    # if an undo command makes it to here, that means there 
	    # wasn't anything to undo; this effectively becomes a
	    # no-op
	    set result {}
	}

	insert {

	    if {[catch {set index  [text_index $w [lindex $args 0]]}]} {
		set index [lindex $args 0]
	    }

	    # since the insert command can have an arbitrary number
	    # of strings and possibly tags, we need to ferret that out
	    # now... what a pain!
	    set myargs [lrange $args 1 end]
	    set length 0
	    while {[llength $myargs] > 0} {
		incr length [string length [lindex $myargs 0]]
		if {[llength $myargs] > 1} {
		    # we have a tag...
		    set myargs [lrange $myargs 2 end]
		} else {
		    set myargs [lrange $myargs 1 end]
		}
	    }

	    # now, let the real widget command do the dirty work
	    # of inserting the text. If we fail, do some munging 
	    # of the error message so the right widget name appears...

	    if {[catch "$w $command $args" result]} {
		regsub $w $result $this result
		return -code error $result
	    }

	    # we need this for the undo stack; index2 couldn't be
	    # computed until after we inserted the data...
	    set index2 [text_index $w "$index + $length chars"]

	    if {$originalCommand == "undo"} {
		# let's do a "see" so what we just did is visible;
		# also, we'll move the insertion cursor to the end
		# of what we just did...
		$w see $index2
		$w mark set insert $index2
		
	    } else {
		# since the original command wasn't undo, we need
		# to reset the undoIndex. This means that the next
		# time an undo is called for we'll start at the 
		# end of the stack
		set undoIndex($w) ""
	    }

	    # add a delete command on the undo stack.
	    lappend undo($w) "d $index $index2"

	}

	delete {

	    # this converts the insertion index into an absolute address
	    set index [text_index $w [lindex $args 0]]

	    # lets get the data we are about to delete; we'll need
	    # it to be able to undo it (obviously. Duh.)
	    set data [eval $w get $args]

	    # add an insert on the undo stack
	    lappend undo($w) [list "i" $index $data]

	    if {$originalCommand == "undo"} {
		# let's do a "see" so what we just did is visible;
		# also, we'll move the insertion cursor to a suitable
		# spot
		$w see $index
		$w mark set insert $index

	    } else {
		# since the original command wasn't undo, we need
		# to reset the undoIndex. This means that the next
		# time an undo is called for we'll start at the 
		# end of the stack
		set undoIndex($w) ""
	    }

	    # let the real widget command do the actual deletion. If
	    # we fail, do some munging of the error message so the right
	    # widget name appears...
	    if {[catch "$w $command $args" result]} {
		regsub $w $result $this result
		return -code error $result
	    }
	}
	
	default {
	    # if the command wasn't one of the special commands above,
	    # just pass it on to the real widget command as-is. If
	    # we fail, do some munging of the error message so the right
	    # widget name appears...
	    if {[catch "$w $command $args" result]} {
		regsub $w $result $this result
		return -code error $result
	    }
	}
    }

    # is there a post-proc? If so, run it. 
    if {[info exists postProc($w)] && $postProc($w) != ""} {
	if {[catch "$postProc($w) originalCommand originalArgs" error]} {
	    return -code error "error during processing of -postproc: $error"
	}
    }


    # we're outta here!
    return $result
}

# this returns a normalized index (ie: line.column), with special
# handling for the index "end"; to undo something we pretty much
# _have_ to have a precise row and column number.
proc Supertext::text_index {w i} {
    if {$i == "end"} {
	set index [$w index "end-1c"]
    } else {
	set index [$w index $i]
    }

    return $index
}


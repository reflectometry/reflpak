# This file contains a set of helper functions for various gui widgets
# such as the BWidget auto-scroll functions, and text and list boxes.
# See pkgindex.tcl for a list of exported functions.

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
# FIXME do we really want to override the default bindings?
proc init_gui {} {
    # Make standard Windows-style and Mac-style bindings work
    event add <<Paste>> <Shift-Insert>
    event add <<Cut>> <Shift-Delete>
    event add <<Copy>> <Control-Insert>
    bind Text <Control-Key-v> {}
    bind Entry <<Paste>> {
	global tcl_platform
	catch {
	    catch { %W delete sel.first sel.last }
	    %W insert insert [selection get -displayof %W -selection CLIPBOARD]
	    tkEntrySeeInsert %W
	}
    }


    switch $::tcl_platform(platform) {
	windows {
	    option add *Scrollbar.width 12 widgetDefault
	    option add *Text.background white widgetDefault
	    option add *Button.padY 0 widgetDefault
	    #option add *iPadX 5 widgetDefault
	    #option add *iPadY 5 widgetDefault
	    #option add *SelectBorderWidth 0 widgetDefault
	    option add *HighlightThickness 1 widgetDefault
	    option add *Frame.highlightThickness 0 widgetDefault
	    option add *Toplevel.highlightThickness 0 widgetDefault
	    option add *Labelframe.highlightThickness 0 widgetDefault
	    option add *Label.anchor w widgetDefault
	    #option add *BorderWidth 1 widgetDefault
	    #option add *Labelframe.borderWidth 2 widgetDefault
	    #option add *Menubutton.borderWidth 1 widgetDefault
	    #option add *Button.borderWidth 2 widgetDefault
	    #option add *Entry.selectBorderWidth 0 widgetDefault
	    #option add *Listbox.selectBorderWidth 0 widgetDefault
	    option add *HandleSize 0 widgetDefault
	    option add *sashWidth 4 widgetDefault
	    bind Button <Key-Return> {tk::ButtonInvoke %W}
	    
	    option add *Hiertable.ResizeCursor size_we 100
            option add *TreeView.ResizeCursor size_we 100
	    
	    option add *Graph.Legend.Font {{Arial Narrow} -10} widgetDefault
	}
	unix {
	    option add *Dialog.msg.font {Times -12} widgetDefault
	    option add *Dialog.msg.wrapLength 6i widgetDefault
	}
    }
}

# ======================== widget debugging ==========================
# HELP developer
# Usage: winpath
#
# Print the path to the next window you click on.
proc winpath {} {
    # Add a new tag to .tkcon so we can modify the <Button-1> action
    set tags [bindtags .tkcon]
    if { [lsearch $tags winpath]<0 } {
	bindtags .tkcon [concat winpath $tags]
	bind winpath <Button-1> { 
	    puts [winfo containing %X %Y]
	    grab release .tkcon
	}
    }
    grab set .tkcon
}

# HELP developer
# Usage: widget_browser root
# 
# Start the generic widget browser at the given root, or . if no
# root is specified.

proc widget_browser { { root . } } {
    if { [catch {
	if { ![info exists ::tablelist::library] } {
	    package require tablelist 
	    source [file join $::tablelist::library demos browse.tcl]
	}
	::demo::displayChildren $root
    } msg] } { app_error $msg }
}

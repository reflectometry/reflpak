# 2001-10-30 Paul Kienzle
# * modified from blt/library/bltGraph.tcl to use blt::table rather than
#   just table since otherwise it conflicts with TkTable.
# * add output destination selection
# 2002-04-30 Paul Kienzle
# * use resources to specify printer

# print options
option add *Printer "|lpr -Plp6" startupFile
option add *Graph.Postscript.Decorations false        startupFile
option add *Graph.Postscript.Landscape   true         startupFile
option add *Graph.Postscript.Colormode   color        startupFile
option add *Graph.Postscript.Center      true         startupFile
option add *Graph.Postscript.Padx        { 0 0 }      startupFile
option add *Graph.Postscript.Pady        { 0 0 }      startupFile
option add *Graph.Postscript.Width       { 850 }      startupFile
option add *Graph.Postscript.Height      { 650 }      startupFile

proc PrintDialog { graph } {
    set top $graph.print
    if { [winfo exists $top] } {
	raise $top
	return
    }

    toplevel $top
    wm title $top "[wm title [winfo toplevel $graph]] print"

    if { ![info exists ::PrintDialog_printer] } {
	set ::PrintDialog_printer \
		[option get $graph printer Printer]
    }
    foreach var { center landscape maxpect preview decorations padx 
	pady paperwidth paperheight width height colormode } {
	global $graph.$var
	set $graph.$var [$graph postscript cget -$var]
    }
    set row 1
    set col 0
    label $top.title -text "PostScript Options"
    blt::table $top $top.title -cspan 7
    foreach bool { center landscape maxpect preview decorations } {
	set w $top.$bool-label
	label $w -text "-$bool" -font *courier*-r-*12* 
	blt::table $top $row,$col $w -anchor e -pady { 2 0 } -padx { 0 4 }
	set w $top.$bool-yes
	global $graph.$bool
	radiobutton $w -text "yes" -variable $graph.$bool -value 1
	blt::table $top $row,$col+1 $w -anchor w
	set w $top.$bool-no
	radiobutton $w -text "no" -variable $graph.$bool -value 0
	blt::table $top $row,$col+2 $w -anchor w
	incr row
    }
    label $top.modes -text "-colormode" -font *courier*-r-*12* 
    blt::table $top $row,0 $top.modes -anchor e  -pady { 2 0 } -padx { 0 4 }
    set col 1
    foreach m { color greyscale } {
	set w $top.$m
	radiobutton $w -text $m -variable $graph.colormode -value $m
	blt::table $top $row,$col $w -anchor w
	incr col
    }
    set row 1
    frame $top.sep -width 2 -bd 1 -relief sunken
    blt::table $top $row,3 $top.sep -fill y -rspan 6
    set col 4
    foreach value { padx pady paperwidth paperheight width height } {
	set w $top.$value-label
	label $w -text "-$value" -font *courier*-r-*12* 
	blt::table $top $row,$col $w -anchor e  -pady { 2 0 } -padx { 0 4 }
	set w $top.$value-entry
	global $graph.$value
	entry $w -textvariable $graph.$value -width 8
	blt::table $top $row,$col+1 $w -cspan 2 -anchor w -padx 8
	incr row
    }
    blt::table configure $top c3 -width .125i

    frame $top.dest
    label $top.dest.label -text "Output (use |lpr for printer)" \
	    -font *courier*-r-*12*
    entry $top.dest.entry -textvariable ::PrintDialog_printer -width 20 
    pack $top.dest.label $top.dest.entry -side left
    blt::table $top $row,0 $top.dest -cspan 5
    incr row

    button $top.cancel -text "Cancel" -command "destroy $top"
    blt::table $top $row,0 $top.cancel  -width 1i -pady 2 -cspan 3
    #button $top.reset -text "Reset" -command "destroy $top"
    #blt::table $top $row,1 $top.reset  -width 1i
    button $top.print -text "Print" -command "if {\[SendPrint $graph]} { destroy $top }"
    blt::table $top $row,4 $top.print  -width 1i -pady 2 -cspan 2
}

proc SendPrint { graph } {
    foreach var { center landscape maxpect preview decorations padx 
	pady paperwidth paperheight width height colormode } {
	global $graph.$var
	set old [$graph postscript cget -$var]
	if { [catch {$graph postscript configure -$var [set $graph.$var]}] != 0 } {
	    $graph postscript configure -$var $old
	    set $graph.$var $old
	}
    }

    set printer [string trim $::PrintDialog_printer]
    if { "[string index [string trim $printer] 0]" == "|" } {
	if { [catch { open $printer w } fid ] } {
	    tk_messageBox -icon error -message $fid \
		    -title "Printer error" -type ok -parent $graph.print
	    return 0
	} else {
	    puts $fid [ $graph postscript output ]
	    close $fid
	    return 1
	}
    } elseif {[string equal $printer ""]} {
	tk_messageBox -icon error -message "no print file or command given" \
		-title "Printer error" -type ok -parent $graph.print
	return 0
    } else {
	$graph postscript output $printer
	return 1
    }
}

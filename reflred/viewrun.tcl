namespace import blt::graph blt::vector blt::hiertable
source [file join $::VIEWRUN_HOME generic.tcl]
source [file join $::VIEWRUN_HOME reduce.tcl]

# XXX FIXME XXX how can I make this automatic?
set OCTAVE_SUPPORT_FILES {
    interp1err psdslice 
    run_div run_include run_interp run_poisson_avg 
    run_scale run_sub run_tol run_trunc
    plotrunop runlog
}

# XXX FIXME XXX fix blt::busy problem with 8.4
if { [string equal $::tcl_version 8.4] } {
    rename blt::busy {}
    proc blt::busy {args} {}
}    

# on-demand loading
proc PrintDialog {args} {
    uplevel #0 [list source [file join $::VIEWRUN_HOME print.tcl]]
    eval PrintDialog $args
}
proc choose_dataset {args} {
    uplevel #0 [list source [file join $::VIEWRUN_HOME choose.tcl]]
    eval choose_dataset $args
}
proc psd {args} {
    uplevel #0 [list source [file join $::VIEWRUN_HOME psd.tcl]]
    eval psd $args
}
proc help {args} {
    rename help {}
    uplevel #0 [list source [file join $::VIEWRUN_HOME htext.tcl]]
    namespace import htext::*
    set ::helpfile [file join $::VIEWRUN_HOME viewrun.help]
    set ::helpstamp {}
    proc help { args } {
	# auto-reload help file based on modification time
	set stamp [file mtime $::helpfile]
	if { "$stamp" != "$::helpstamp" } {
	    uplevel #0 [list source $::helpfile]
	    set ::helpstamp $stamp
	}
	eval htext .htext $args
    }
    eval help $args
}

# Delay starting octave as long as possible
rename octave octave_orig
proc octave {args} {
    rename octave {}
    rename octave_orig octave
#    uplevel #0 [list source [file join $::VIEWRUN_HOME octave.tcl]]
    restart_octave
    eval octave $args
}

# define help key
# XXX FIXME XXX should this be a resource?
bind all <F1> { help %W }
bind all <Shift-F1> { help %W controls }

# process command line args, if any
if { $argc == 1 } {
    if { [ string match $argv "-h" ] } {
	puts "usage: $argv0 \[data directory]"
	exit
    } elseif { [file isdirectory $argv] } {
	set pattern [file join $argv *]
    } else {
#       puts "$argv0: directory $argv does not exist"
#       exit
	set pattern $argv
    }
} elseif { $argc == 0 } {
    set pattern [file join . *]
} else {
#    set pattern $argv
    puts "usage: $argv0 \[data directory]"
    exit
}

# useful constants
set ::log10 [expr log(10.0)]
set ::pitimes4 [expr 16.0*atan(1.0)]
set ::piover360 [ expr atan(1.0)/90.0]
set ::piover180 [ expr atan(1.0)/45.0]
proc a3toQx {a3 a4over2 lambda} {
    return "[expr [a4toQz 2*$a4over2 $lambda]] * atan( ($a3-$a4over2)*$::piover180 )"
}
proc a4toQx {a4 a3 lambda} {
    return "[expr {[a3toQz $a3 $lambda]}] * atan( ($a3 - ($a4)/2)*$::piover180 )"
}
proc a3toQz {a3 lambda} {
    return "$::pitimes4*sin($a3*$::piover180) / $lambda"
}
proc a4toQz {a4 lambda} {
    return "$::pitimes4*sin($a4*$::piover360) / $lambda"
}

load_resources $::VIEWRUN_HOME tkviewrun

# XXX FIXME XXX turn these into resources
set ::xraywavelength 1.5416
set ::ng1wavelength 4.75
set ::ng7wavelength 4.768
set ::logaddrun 0
set ::erraddrun y
set ::background_default [option get . backgroundBasis BackgroundBasis]

# default user preferences
set appname [file tail $argv0]

proc init_tree_select_images {} {
    set box9 {
	{ 111111111}
	{ 100000001}
	{ 100000001}
	{ 100000001}
	{ 100000001}
	{ 100000001}
	{ 100000001}
	{ 100000001}
	{ 111111111}
    }
    set ::image(clear) [image create photo]
    $::image(clear) put [string map { 0 "white " 1 "black " } $box9]
    set ::image(select) [image create photo]
    $::image(select) put [string map { 0 "red " 1 "black " } $box9]
}
init_tree_select_images
rename init_tree_select_images {}

# draw the selector window
proc init_selector { } {
    menu .menu
    . config -menu .menu
    .menu add command -label "Data..." -command { choose_dataset setdirectory }
    .menu add command -label "Reduce..." -command {
	wm deiconify .reduce
	raise .reduce
    }
    .menu add command -label "Attenuators..." -command { atten_table }
    # XXX FIXME XXX want menu options for setting Xray/Neutron wavelength
    # XXX FIXME XXX some users want separate scan directory and fit directory
    menu .menu.options
    .menu add cascade -label Options -menu .menu.options
    .menu.options add radiobutton -label "Background Q(A3)" \
	    -variable ::background_default -value A3 \
	    -command reset_backgrounds
    .menu.options add radiobutton -label "Background Q(A4)" \
	    -variable ::background_default -value A4 \
	    -command reset_backgrounds
    .menu.options add command -label "Monitor..." -command { set_monitor }
    # XXX FIXME XXX This needs to be an option on the y-axis for the graph
    .menu.options add checkbutton -label "Show Temperature" \
	    -variable ::show_temperature \
	    -command { atten_set $::addrun }
    .menu.options add separator
    .menu.options add command -label "Restart octave" -command restart_octave
    .menu.options add command -label "Tcl console" -command { start_tkcon }
    menu .menu.help
    .menu add cascade -label Help -menu .menu.help
    .menu.help add command -label "Browse" -command { help tkviewrun }
    .menu.help add command -label "Index" -command { help Index }
    .menu.help add command -label "Search" -command { help Search }


    PanedWindow .treebydata -side top
    set treepane [.treebydata add -weight 1 -minsize 20]
    set datapane [.treebydata add -weight 5 -minsize 20]
    sashconf .treebydata

    PanedWindow $datapane.filebygraph -side left
    set filepane [$datapane.filebygraph add -weight 1 -minsize 10]
    set graphpane [$datapane.filebygraph add -weight 5 -minsize 20]
    sashconf $datapane.filebygraph


    # tree to hold the list of runs
    Tree .tree -selectcommand view_file -padx 11
    .tree configure -width [option get .tree width Width]
    scroll .tree -side left -in $treepane

    # Yuck!  It would be nicer to put the resources nearer to where they
    # are being used.  Unfortunately, I can't initialize them until after
    # I've created the tree.
    set ::qrange_fill [option get .tree qFill QFill] 
    set ::qrange_color [option get .tree qColor QColor]
    set ::qrange_outline [option get .tree qOutline QOutline]
    set ::qrange_outlinewidth [option get .tree qOutlineWidth QOutlineWidth]
    set ::qrange_barcolor [option get .tree qBarColor QBarColor]
    set ::qrange_barwidth [option get .tree qBarWidth QBarWidth]

    ## This is a bit sloppy: by default tree doesn't take focus.  Since none
    ## of the other widgets take focus, though, we can simply bind keyboard
    ## events to the toplevel window.
    bind . <Return> { message; toggle_section }
    bind . <Shift-Return> { message; toggle_section -force 1 }
    bind . <Control-Return> { message; toggle_section -extend 1 }
    bind . <Shift-Control-Return> { message; toggle_section -force 1 -extend 1 }
    ## To do this "properly" we may have to do the following:
    # bind .tree <Enter> { focus .tree } ;# grab focus when mouse enters
    # bind .tree <Delete> { unjoin [%W selection get] }
    # bind .tree <Return> { join [%W selection get] }
    ## I don't know how to put ourselves on the tab focus loop

    foreach b { bindImage bindText } {
	.tree $b <Button-1> "message; toggle_section -node "
	.tree $b <Shift-Button-1> "message; toggle_section -force 1 -node "
	.tree $b <Double-Button-1> "toggle_section -keep 1 -extend 1 -node "
	.tree $b <Shift-Double-Button-1> \
		"toggle_section -extend 1 -force 1 -node "
    }

    # XXX FIXME XXX don't want to leak that .tree.c exists from tree.tcl
    bind .tree.c <Button-2> { message; addrun accept }
    bind .tree.c <Button-3> { message; addrun clear }
#    bind .tree.c <Shift-Control-Button-3> { addrun clearscan }
    bind . <Delete> { message; addrun clear }
    bind . <Insert> { message; addrun accept }

#    bind . <Escape> { exit }

    label .filename
    pack .filename -side top -in $filepane

    text .text -state disabled -wrap none
    scroll .text -side top -in $filepane

    graph .graph
#    vector create ::x_data ::y_data
#    .graph element create data -xdata ::x_data -ydata ::y_data -pixels 3 -label ""
    .graph marker create text -name rocklab -coords { 0 -Inf }
    .graph marker create line -name rockbar -coords { 0 -Inf 0 Inf }
    .graph marker create text -name date -coords {Inf Inf} -anchor ne
    .graph axis conf y -title "Counts" -logscale $::logaddrun

    .graph pen create excludePoint

    # add zoom capability.
    Blt_ZoomStack    .graph

    # crosshairs if the users wishes
    if { [string is true [option get .graph crosshairs Crosshairs]] } {
	.graph crosshairs on
    }

    # add a legend so that clicking on the legend entry toggles the display
    # of the corresponding line and moving over the lines highlights the
    # corresponding legend entry
    .graph legend conf -hide 0
    .graph legend bind all <Button-1> { zoom %W off ; legend_toggle %W }
    .graph legend bind all <ButtonRelease-1> { zoom %W on }
    .graph element bind all <Enter> {
	%W legend activate [%W element get current]
    }
    .graph element bind all <Leave> {
	%W legend deactivate [%W element get current]
    }

    set ::colorlist [option get .graph lineColors LineColors]

    # click axis to change log/linear scale
    active_axis .graph y

    # put graph coordinates into message box
    bind .graph <Leave> { message "" }
    bind .graph <Motion> { graph_motion %W %x %y }

    # click with middle button to exclude a value
    bind .graph <2> { graph_exclude %W %x %y }


    frame .b
    checkbutton .b.scale -text "Align" -indicatoron 1 \
	    -variable ::prefer_aligned \
	    -command { addrun align }
    pack .b.scale -side left -anchor w

    if [blt_errorbars] {
	checkbutton .b.err -text Errorbar -variable ::erraddrun \
		-indicatoron 1 -offvalue none -onvalue y \
		-command {
	    foreach id $::addrun {
		.graph elem conf $id -showerrorbar $::erraddrun
	    }
	}
	pack .b.err -side left
    }

    # button to accept the current scan
    button .b.accept -text Accept -command { addrun accept }
    button .b.clear -text Clear -command { addrun clear }
    button .b.print -text Print... -command { PrintDialog .graph }
    # button .b.clearscan -text "Clear all" -command { addrun clearscan }
    pack .b.accept .b.clear .b.print -side left -anchor w

    # status message dialog
    set ::message {}
    label .message -relief ridge -anchor w -textvariable ::message
    pack .message -side bottom -expand no -fill x

    pack .b -fill x -expand no -in $graphpane -side bottom
    pack .graph -side top -expand yes -fill both -in $graphpane

    pack $datapane.filebygraph -fill both -expand yes
    pack .treebydata -fill both -expand yes
    set geometry [option get . geometry Geometry]
    if { ![string equal $geometry ""] } { wm geometry . $geometry }

#   # Maximize the window on opening; this doesn't quite work on X since
#   # it resizes the interior not the frame, and some wm's don't catch the
#   # oversizing.  Use [wm frame .] to get the frame
#   if { [catch { wm state . zoomed }] } {
#	wm geometry [wm frame .] [join [wm maxsize .] x]
#   }
    wm positionfrom . program
    wm sizefrom . program
}

# XXX FIXME XXX incomplete untested code which is never called
# This is more difficult than it ought to be.  In order to change the
# monitor we have to change the ylabel on the graphs which use that
# monitor.  Also, it is nonsensical to use a neutron counts monitor for
# time data and vice versa, so we need to support two different monitors.
# So much for this being a Quick Fix.
set ::monitor_inuse 0
set ::monitor_value {}
proc set_monitor {} {
    set top .monitor
    if { [winfo exists $top] } { raise $top; return }

    toplevel $top
    wm title $top "Monitor value"
    checkbutton $top.inuse -text "Fixed monitor" \
	    -indicatoron 1 -variable ::monitor_inuse \
	    -command { atten_set $::addrun}
    label $top.label -text "Monitor value"
    entry $top.value -textvariable ::monitor_value
    frame $top.b
    button $top.b.accept -text Accept \
	    -command { atten_set $::addrun }
    button $top.b.reset -text Close \
	    -command "atten_set \$::addrun; destroy $top"
    pack $top.b.accept $top.b.reset -side left
    grid $top.inuse - -sticky w
    grid $top.label $top.value
    grid $top.b - -sticky e
    bind $top.value <Return> { set ::monitor_inuse 1; atten_set $::addrun }
}

# XXX FIXME XXX do we really want the message to show up in all the windows?
proc message { {msg "" } } { set ::message $msg }

# show the coordinates of the nearest point
proc graph_motion { w x y } {
    $w crosshairs conf -position @$x,$y
    $w element closest $x $y where -halo 1i
    if { [info exists where(x)] } {
	## XXX FIXME XXX better way to get the currently viewed record?
	## (moot since we no longer support viewfile, only addrun)
	#if { [string equal $where(name) "data"] || [string } {
	#    upvar #0 [.tree selection get] rec
	#    set elid "Run $rec(legend)
	#} elseif [string matches rec* ::$where(name)] {
	#    upvar #0 $where(name) rec
	#    set elid "Run $rec(legend)
	#}
	set ptid "[$w elem cget $where(name) -label]:[expr $where(index)+1]"
	set ptx "[fix $where(x)]"
	set pty "[fix $where(y) {} {} 5]"
	if { [info exists ::xth_$where(name)] } {
	    message "$ptid  ([fix [set ::xth_$where(name)($where(index))]]$::symbol(degree), $ptx A$::symbol(inverse)) $pty"
	} else {
	    message "$ptid  $ptx, $pty"
	}
    } else {
	message
    }
}

proc graph_exclude { w x y } {
    $w element closest $x $y where -halo 1i
    if { [info exists where(x)] } {
	# find the data record
	if { [string match rec* $where(name) ] } {
	    upvar #0 $where(name) rec
	} else {
	    return
	}
	# construct an index vector if needed
	set vec ::idx_$rec(id)
	if { ![vector_exists $vec] } {
	    vector create $vec
	    $vec expr 1+0*::x_$rec(id)
	    $w element conf $where(name) -weight $vec -styles { {excludePoint -0.5 0.5} }
	}
	# negate the particular index
	set idx $where(index)
	set ${vec}($idx) [expr 1.0 - [set ${vec}($idx)]]
    } else {
	message "No points under mouse"
	bell
    }
}


# ======================================================


if 0 {
# XXX FIXME XXX is this code in use?
# This is just a macro for savescan.  It gets fid, log and rec
# from there
proc write_scan {} {
    upvar rec rec
    upvar fid fid
    upvar log log
    puts $fid "# date: [clock format $rec(date) -format %Y-%m-%d]"
    puts $fid "# title: $rec(comment)"
    puts $fid "# xlabel: $rec(xlab)"
    if { $log } {
	puts $fid "# ylabel: log $rec(ylab)"
    } else {
	puts $fid "# ylabel: $rec(ylab)"
    }
    puts $fid "# source: $rec(instrument) [typelabel $rec(type)]"
    puts -nonewline $fid "# runs: $rec(dataset)"
    foreach id $::addrun {
	# XXX FIXME XXX nothing to stop files from being in
	# other datasets, instruments, directories, etc.
	# XXX FIXME XXX don't we want xml data format here?  After
	# my experience with icp you would think I would know better
	# than to create an ad hoc format.
	puts -nonewline $fid " [set ::${id}(run)]"
	if { [set ::${id}(k)] != 1.0 } {
	    puts -nonewline $fid "x[fix [set ::${id}(k)]]([fix [set ::${id}(dk)]])"
	}
    }
    puts $fid ""
    puts $fid "# columns: x y dy"
    # XXX FIXME XXX are we guaranteed that x_scan, y_scan, dy_scan are
    # available?
    if { $log } {
	foreach x $::x_scan(:) y $::y_scan(:) dy $::dy_scan(:) {
	    if { $y <= 0.0 } { set y 0.0 } else { set y [expr log($y)] }
	    if { $dy <= 0.0 } { set dy 0.0 } else { set dy [expr log($dy)] }
	    puts $fid "$x $y $dy"
	}
    } else {
	foreach x $::x_scan(:) y $::y_scan(:) dy $::dy_scan(:) {
	    puts $fid "$x $y $dy"
	}
    }
}

# savescan [-query all|existing|none] [-record id] [-vector id]
# XXX FIXME XXX there is no way to trigger savescan
# XXX FIXME XXX make sure reduce uses the same file format
proc savescan { args } {
    array set opt [list -query none -record [lindex $::addrun 0] -vector]
    # XXX FIXME XXX often one run is the entire scan so it is not obvious
    # that you should use addrun to save it.  And you do want to save it
    # because of things like monitor count corrections, error bars and
    # log scaling.
    if { [string equal $::addrun ""] } {
	message "No runs selected"; bell;
	return
    }

    upvar #0 [lindex $::addrun 0] rec
    # Determine the valid extensions (these will eventually depend on
    # the type since we need to distinguish between bg and avg bg for
    # some background runs and between spec, background subtraction,
    # slit corection and polarization correction), all with the same
    # prefix.
    set logext .log
    set linext .dat

    # XXX FIXME XXX do I really need to hardcode NG1p stuff here?
    if { [string equal $rec(instrument) "NG1p"] } {
	set index [string tolower [string index $rec(file) -1]]]
	set logext [string replace $logext end-1 end $index]
	set linext [string replace $linext end-1 end $index]
    }

    # Get the filename to use
    # XXX FIXME XXX will the user be surprised that the default format
    # is set by ::logaddrun?  Maybe we should add a log/linear option
    # for scripting control
    # XXX FIXME XXX need to be able to overwrite the title; the way to
    # do this is to move the title into a separate widget, but we will
    # have to add it to the graph before printing.  Maybe an EPS canvas?
    # Maybe nice to annotate the graphs as well.
#    if { $::logaddrun } {
	set filename [file rootname $rec(file)]$logext
#    } else {
#	set filename [file rootname $rec(file)]$linext
#    }
    if { [string equal $opt "as"] } {
	set filename [ tk_getSaveFile -defaultextension $logext \
		-title "Save scan data" \
		-filetypes [list [list Log $logext] [list Linear $linext]]]
	if { [string equal $filename ""] } { return }
    } elseif { [string equal $opt "verify"] && [file exists $filename] } {
	set ans [tk_messageBox -type yesno -default yes \
		-icon warning \
		-message "$filename exists. Do you want to overwrite it?" \
		-title "Save scan data" -parent .]
	if { [string equal $ans no] } { return }
    }

    # Linear or log?
    set log [string equal [file extension $filename] $logext]

    # Write the file
    if { [catch { open $filename w } fid] } {
	message $fid; bell;
    } else {
	if { [catch { write_scan } msg] } {
	    message $msg; bell
	}
	close $fid
    }

}

}

proc restart_octave {} {
    catch { octave close }
    octave connect $::OCTAVE_HOST
    octave eval "cd /tmp"
    foreach file $::OCTAVE_SUPPORT_FILES {
	octave mfile [file join $::VIEWRUN_HOME octave $file.m]
    }
    foreach ext { x y dy m } {
	foreach id [vector names ::scan*_$ext] {
	    octave send $id [string map { : {} _ . } $id]
	}
    }
    set ::NG7_monitor_calibration_loaded 0

    # Use the following function to send an x,y,dy structure to tcl
    octave eval {
	function send_run(name, val)
	   if isempty(val)
	      send(sprintf(name,'x'),[]);
	      send(sprintf(name,'y'),[]);
	      send(sprintf(name,'dy'),[]);
	   else
	      send(sprintf(name,'x'),val.x);
	      send(sprintf(name,'y'),val.y);
	      send(sprintf(name,'dy'),val.dy);
	      if struct_contains(val,'m')
	         send(sprintf(name,'m'),val.m); 
              endif
	   endif
	endfunction
    }
}

proc write_data { fid data {log 0} } {

    if { $log } {
	puts $fid "# columns x logy dlogy"
	foreach x [set ${data}_x(:)] \
		y [set ${data}_y(:)] \
		dy [set ${data}_dy(:)] {
#	    puts "writing $x $y $dy"
	    if { $y <= $dy/1000 } {
		# XXX FIXME XXX can dy be <= 0?
		if { abs($y) <= $dy/1000 } {
		    tk_messageBox -parent . \
			    -message "excluding (x,y,dy)=($x,$y,$dy)" \
			    -type ok
		    continue
		}
		message "truncating counts below dy/1000 to log_10(dy)-3 $::symbol(plusminus) dy/(ln(10)*|y|)"
		set newdy [expr $dy / ($::log10*abs($y)) ]
		set y [expr log($dy) / $::log10 - 3 ]
		set dy $newdy
	    } else {
		set dy [expr $dy / ($::log10*$y)]
		set y [expr log($y) / $::log10 ]
	    }
	    puts $fid "$x $y $dy"
	}
    } else {
	puts $fid "# columns x y dy"
	foreach x [set ${data}_x(:)] \
		y [set ${data}_y(:)] \
		dy [set ${data}_dy(:)] {
	    puts $fid "$x $y $dy"
	}
    }
}

proc write_scan { fid scanid } {
    upvar #0 $scanid rec
    puts $fid "# date [clock format $rec(date) -format %Y-%m-%d]"
    puts $fid "# title \"$rec(comment)\""
    puts $fid "# instrument $rec(instrument)"
    puts $fid "# monitor $rec(monitor)"
    puts $fid "# temperature $rec(T)"
    if { [info exists rec(Tavg)] } {
	puts $fid "# average temperature $rec(Tavg)"
    }
    puts $fid "# field $rec(H)"
    puts $fid "# wavelength $rec(L)"
    puts $fid "# xlabel $rec(xlab)"
    puts $fid "# ylabel $rec(ylab)"
    puts $fid "# $rec(type) $rec(files)"
    write_data $fid ::$scanid
}

proc savescan { scanid } {
    upvar #0 ::$scanid rec
    set filename [file rootname $rec(file)].$rec(type)$rec(index)
    if [file exists $filename] {
	set ans [tk_messageBox -type yesno -default yes \
		    -icon warning -parent . \
		    -message "$filename exists. Do you want to overwrite it?" \
		    -title "Save scan data" ]
	switch $ans { no { return }	}
    }

    if { [catch { open $filename w } fid] } {
	message $fid; bell;
    } else {
	if { [catch { write_scan $fid $scanid } msg] } {
	    message $msg; bell
	} else {
	    message "Saving data in $filename"
	}
	close $fid
    }
}

# XXX FIXME XXX what do we do when we are running without reduce?
# should setscan call reduce_newscan directly or what?
#
# assumes atten_set has been called so that the triple:
#     x_$id, ky_$id, kdy_$id
# are the runs to be averaged
set ::scancount 0
proc setscan { runs } {
    # XXX FIXME XXX do we need an error message here?
    if { [llength $runs] == 0 } { error "no runs" }

    # Records are created in dictionary order, so sorting by record
    # number sorts by dictionary order (with 'other' files pushed to
    # the end).  Mostly, things within the same dataset will work
    # fine.  There may be problems if data comes from multiple datasets
    # so users will have to be sure to override the names if that is
    # the case.
    set runs [lsort -dictionary $runs]

    upvar #0 [lindex $runs 0] rec
    set name "$rec(instrument):$rec(dataset)-$rec(run)$rec(index)"
    if [info exists ::scanindex($name)] {
	set scanid $::scanindex($name)
	# XXX FIXME XXX scan names are not unique!!  If the type or
	# comment has changed, then we will have to remove and reinsert
	# the scan in the reduce box lists.
    } else {
	# scanid must be a valid octave name and blt vector name
	set scanid scan[incr ::scancount]
	# XXX FIXME XXX this should be the user editted comment for the
	# scan. It should maybe be a property of addrun rather than the
	# record since it is conceivable that a new scan would be
	# created having the same header, but different runs and different
	# comment.  If the comment has changed, then this should be reflected
	# in the reduce box lists.
	array set ::$scanid [array get rec]
	array set ::$scanid [list \
	    id $scanid name $name \
	    runs $runs \
	]
	set ::scanindex($name) $scanid

	# XXX FIXME XXX need a better way to change scan types
	if [string equal $rec(type) "other"] {
	    array set ::$scanid { type spec }
	}

    }
    upvar #0 $scanid scanrec

    # if {$::monitor_inuse} { set $scanrec(monitor) $::monitor_value }

    # need to recalculate since the run list may have changed
    octave eval $scanrec(id)=\[]
    set scanrec(files) {}
    foreach id $runs {
	upvar #0 $id rec
	octave eval r=\[]

	# data
	octave send ::x_${id} r.x
	octave send ::y_${id} r.y
	octave send ::dy_${id} r.dy

	# monitor and attenuator
	octave eval "r = run_scale(r,$scanrec(monitor))"
	octave eval "r = run_scale(r,$rec(k),$rec(dk))"

	# slit motor position if required
	if {[info exists rec(slit)]} { 
	    octave send ::$rec(slit) r.m
	}

	# remove exclusions (and generate note for the log)
	if [vector_exists ::idx_$id] {
	    octave send ::idx_${id} idx
	    octave eval { r = run_include(r,idx) }
	    set exclude " \[excluding 0-origin [::idx_$id search 0]]"
	} else {
	    set exclude ""
	}

	# append run
	octave eval "$scanid = run_poisson_avg($scanid,r)"

	# pretty scale
	if { $rec(k) == 1 && $rec(dk) == 0 } {
	    set scale {}
	} elseif { $rec(dk) == 0 } {
	    set scale "*$rec(k)"
	} else {
	    set scale "*$rec(k)($rec(dk))"
	}

	# list file with scale and exclusions in the log
	lappend scanrec(files) "[file tail $rec(file)]$scale$exclude"
    }
    vector create ::${scanid}_x ::${scanid}_y ::${scanid}_dy
    octave recv ${scanid}_x ${scanid}.x
    octave recv ${scanid}_y ${scanid}.y
    octave recv ${scanid}_dy ${scanid}.dy
    # slit motor position, if defined for all sections, will be in 'm'
    octave eval "if struct_contains(${scanid},'m'), send('${scanid}_m',${scanid}.m); end"
    vector create ::${scanid}_ky
    vector create ::${scanid}_kdy
    octave sync

    savescan $scanid
    reduce_newscan $scanid
    return $scanid
}

# Clear the scan from memory and from the compose graph.
# If -all, remove all scans.
proc clearscan { scanid } {
    # Compose and reduce may be using the scan, so make them let it go
    # XXX FIXME XXX rather than trying to record everywhere that the scan
    # is used, can't we add a watch to the scanid in every widget which
    # uses it?
    reduce_clearscan $scanid
    addrun clearscan $scanid

    # remove the scan from memory
    if { [string equal $scanid -all] } {
	catch { unset ::scanindex }
	foreach var [info vars ::scan*] { array unset $var }
	set var [vector names ::scan*]
	if [llength $var] { eval vector destroy $var }
    } else {	
	array unset ::scanindex [set ::${scanid}(name)]
	catch { array unset ::$scanid }
	set var [vector names ::${scanid}_*]
	if [llength $var] { eval vector destroy $var }
    }
}

proc editscan { scanid } {
    set runs [set ::${scanid}(runs)]
    if ![info exists ::[lindex $runs 0]] {
	message "File selection has changed --- cannot edit"
	return
    }

    if [llength $::addrun] {
	set msg [addrun matches [lindex $runs 0]]
	if ![string length $msg] {
	    set msg "You already have some files selected."
	}
	set ans [tk_messageBox -type yesnocancel -default yes \
		-icon warning -parent . \
		-message "$msg\nClear existing selection?" \
		-title "Edit scan" ]
	switch $ans {
	    cancel { return }
	    yes { addrun clear }
	}
    }
    foreach id $runs { addrun add $id }
    if { $::prefer_aligned } {atten_calc $::addrun }
    atten_set $::addrun
    raise .
}


# ======================================================

## XXX FIXME XXX need to be able to choose ratio from a list
## XXX FIXME XXX need to be able to calc ratio relative to
## another
proc atten_table_reset {} {
    if { ![winfo exists .attenuator] } { return }
    unset ::atten_table
    array set ::atten_table { -1,0 Run -1,1 attenuator -1,2 "std. error" }
    set row -1
    foreach id $::addrun {
	upvar #0 $id rec
	incr row
	array set ::atten_table [list $row,0 "$rec(run)$rec(index)" $row,1 $rec(k) $row,2 $rec(dk)]
    }
    .attenuator.t conf -rows [expr 1 + [llength $::addrun]]
}

proc atten_table {} {
    if { [winfo exists .attenuator] } {
	raise .attenuator
	focus .attenuator
	return
    }

    toplevel .attenuator
    wm geometry .attenuator 300x150
    table .attenuator.t -cols 3 -resizeborders col -colstr unset \
	    -titlerows 1 -titlecols 1 -roworigin -1 -variable ::atten_table
    .attenuator.t width 0 4
    vscroll .attenuator.t
    atten_table_reset
    # XXX FIXME XXX want a combo box here
    table_entry .attenuator.t { if { %i } { atten_update %r %c %S } else { set ::atten_table(%r,%c) } }
}

proc atten_update { row col val } {
#    puts "[info level 0] [.attenuator.t index active]"
    if {![string is double $val]} {
	error "number expected"
    } elseif {$val < 0} {
	error "must be non-negative"
    }

    # the new value is good so save it in the appropriate record
    upvar #0 [lindex $::addrun $row] rec
    if { $col == 1 } {
	set rec(k) $val
    } else {
	set rec(dk) $val
    }

    # update the graph
    # XXX FIXME XXX this is overkill; minimum is "[lindex $::addrun 0] $id"
    atten_set $::addrun

    # return the value to display in the table
    return $val
}


# =====================================================

# XXX FIXME XXX not using either of these but should be
# will need to move entire scale calc algorithm to octave, so delay.
proc average_seq {} {
    octave send ::x_seq r.x
    octave send ::y_seq r.y
    octave send ::dy_seq r.dy
    # XXX FIXME XXX what about excluded points?
    octave eval "r = run_poisson_avg(r)"
    octave recv x_seq r.x
    octave recv y_seq r.y
    octave recv dy_seq r.dy
}
proc average_seq_tcl {} {
    # pure tcl version, gaussian statistics
    set dups {}
    for {set i 1; set j 0} { $i < [::x_seq length] } { incr i; incr j } {
	if { abs($::x_seq($j) - $::x_seq($i)) < 1e-8 } {
	    ## usual average of x1 and x2 -> x1
	    set ::x_seq($j) [expr ($::x_seq($i)+$::x_seq($j))/2];
	    ## error-weighted average of y1 and y2 -> y1
	    set si [expr 1./($::dy_seq($i)*$::dy_seq($i))]
	    set sj [expr 1./($::dy_seq($j)*$::dy_seq($j))]
	    set w [expr $si + $sj]
	    set inerr "$::dy_seq($i) $::dy_seq($j)"
	    if { $w == 0.0 } {
		puts "dyi=$::dy_seq($i), dyj=$::dy_seq($j), w=$w"
	    }
	    set ::y_seq($j) [expr ($::y_seq($i)*$si + $::y_seq($j)*$sj)/$w]
	    set ::dy_seq($j) [expr 1./sqrt($w)];
	    puts "avg: $inerr -> $::dy_seq($j)"
	    ## remove y2 from set
	    lappend dups $i
	}
    }
    if { ![string equal $dups ""] } {
	eval ::x_seq delete $dups
	eval ::y_seq delete $dups
	eval ::dy_seq delete $dups
    }
}



# calculate the amount of overlap between x_$id1 and x_$id2
proc find_overlap { id1 id2 } {
    upvar $id1 x1
    upvar $id2 x2

    # xrange is monotonic but not necessarily increasing
    if { $x2(0) <= $x2(end) } {
	set idx [ $id1 search $x2(0) $x2(end) ]
    } else {
	set idx [ $id1 search $x2(end) $x2(0) ]
    }
#   puts "overlap at idx $idx"
    set n [llength $idx]
    if { $n == 0 } {
#	puts "none"
	return -1;
    } else {
#	puts "range [expr $x1([lindex $idx end]) -  $x1([lindex $idx 0]) ]"
	return [expr 1.0e-30 + $x1([lindex $idx end]) - $x1([lindex $idx 0]) ]
    }
}

proc join_one {id seq} {
    upvar ::x_$id x
    upvar ::y_$id y
    upvar ::dy_$id dy
    # xrange is monotonic but not necessarily increasing
    if { $x(0) <= $x(end) } {
	set y1idx [ ::x_seq search $x(0) $x(end) ]
    } else {
	set y1idx [ ::x_seq search $x(end) $x(0) ]
    }
    if { $::x_seq(0) < $::x_seq(end) } {
	set y2idx [ ::x_$id search $::x_seq(0) $::x_seq(end) ]
    } else {
	set y2idx [ ::x_$id search $::x_seq(end) $::x_seq(0) ]
    }
    ### XXX FIXME XXX need better estimate of scaling factor
    ### for now only using one point
    set y1 $::y_seq([lindex $y1idx 0])
    set y2 $y([lindex $y2idx 0])
    set dy1 $::dy_seq([lindex $y1idx 0])
    set dy2 $dy([lindex $y2idx 0])
    upvar #0 $id rec
    if { $y2 == 0 } {
	# XXX FIXME XXX need better handling of this, but it should
	# come when we clean up the atten factor code
	message "ignoring 0 when scaling"
	set rec(k) 1.0
	set rec(dk) 0.0
#puts "appending ::x_$id to ::x_seq"
	::x_seq append ::x_$id
	::y_seq append ::y_$id
	::dy_seq append ::dy_$id
    } elseif { $y1 >= $y2 } {
#	puts "scale new run against the old"
	set rec(k) [expr $y1/$y2]
	set p [expr $dy1/$y2]
	set q [expr ($y1/$y2)*($dy2/$y2)]
	set rec(dk) [expr sqrt($p*$p + $q*$q)]
	::ky_$id expr "$rec(k)*::y_$id"
	::kdy_$id expr "sqrt($rec(k)^2*::dy_$id^2 + ::y_$id^2*$rec(dk)^2)"
#puts "appending ::x_$id to ::x_seq"
	::x_seq append ::x_$id
	::y_seq append ::ky_$id
	::dy_seq append ::kdy_$id
    } else {
#	puts "scale all old runs against the new"
	set rec(k) 1.0
	set rec(dk) 0.0
	set k [expr $y2/$y1]
	set p [expr $dy2/$y1]
	set q [expr ($y2/$y1)*($dy1/$y1)]
	set dk [expr sqrt($p*$p + $q*$q)]
	foreach oldid $seq {
	    #puts "updating [set ::${oldid}(run)] by $k +/- $dk"
	    set ::${oldid}(dk) [vector expr "sqrt($k^2*[set ::${oldid}(dk)]^2 + [set ::${oldid}(k)]^2*$dk^2)"]
	    set ::${oldid}(k) [expr $k*[set ::${oldid}(k)]]
	}
	::dy_seq expr "sqrt( $k^2 * ::dy_seq^2 + ::y_seq^2 * $dk^2 )"
	::y_seq expr "$k * ::y_seq"
	#puts "appending [set ::${id}(run)] to ::x_seq"
	::x_seq append ::x_$id
	::y_seq append ::y_$id
	::dy_seq append ::dy_$id
    }
    ::x_seq sort ::y_seq ::dy_seq

}

# Find a connected sequence of runs and join them together with
# scaling relative to the peak
proc get_seq {runs monitor} {
    # start with the first run
    set seq [lindex $runs 0]
    set ::${seq}(k) 1.0
    set ::${seq}(dk) 0.0
    set runs [lrange $runs 1 end]
    ::x_$seq dup ::x_seq
    ::y_$seq dup ::y_seq
    ::dy_$seq dup ::dy_seq

    ## XXX FIXME XXX the following fails with unable to find peakid if
    ## the first thing we do is double click on a file which is all zeros.
    ## E.g., ~borchers/Neutron/G126a/g126a010.na1

    # cycle through the remaining runs, extracting
    # the maximally overlapping one. This is an n^2 algorithm,
    # but we could easily make it nlogn by sorting the
    # runs by ::x_$id(0) and using the first overlapping run.
    set seqnum [set ::${seq}(run)]
    while {1} {
	# find the maximal overlap
	set peak -1
	foreach id $runs {
#puts -nonewline "checking overlap between {$seqnum} ($::x_seq(0) ... $::x_seq(end)) and [set ::${id}(run)] ([set ::x_${id}(0)] ... [set ::x_${id}(end)]): "
	    set v [find_overlap ::x_seq ::x_$id]
	    if { $v > $peak } {
		set peak $v
		set peakid $id
	    }
	}

	if { $peak >= 0 } {
	    # overlap so add it to our sequence
	    join_one $peakid $seq
#puts "x_seq: $::x_seq(:)"
	    lappend seq $peakid
	    lappend seqnum [set ::${peakid}(run)]
	    set runs [ldelete $runs $peakid]
	} else {
	    # no overlap so finished the current sequence
	    break;
	}
    }
    return $runs
}

# Given a set of run ids $runs, find k/dk which joins them.
proc atten_calc {runs} {
    if { [string equal $runs {}] } { return }
    upvar #0 [lindex $runs 0] rec
    set runs [get_seq $runs $rec(monitor)]
    while { [llength $runs] > 0 } {
puts "remaining runs: $runs"
	# get the next connected sequence out of $runs, removing the elements
	# it uses and constructing ::x_seq, ::y_seq, ::dy_seq
	set runs [get_seq $runs $rec(monitor)]
    }
}

proc valid_monitor { } {
    if { !$::monitor_inuse } { 
	return 0
    } elseif [llength $::monitor_value] {
	return [string is double $::monitor_value]
    } else {
	return 0
    }
}

proc atten_set { runs }  {

    # Ghost scans we have to deal with in addition to runs
    set scans [.graph elem names scan*]

    # Determine which monitor to use
    # XXX FIXME XXX Have to set the y-axis, etc.  Atten_set is NOT the 
    # place to do it!  Ideally it would be done in addrun_accept, and
    # be based on the scan containing the record which used to be the
    # head so that the monitor scaling doesn't change, but then we need
    # a way of propogating the monitor to atten_set.
    if [llength $runs] {
	if [valid_monitor] {
	    set monitor $::monitor_value
	} else {
	    # scale by monitor/prefactor of the first run
	    upvar #0 [lindex $runs 0] rec
	    set monitor $rec(monitor)
	}
	decorate_graph [lindex $runs 0]
    } elseif [llength $scans] {
	if [valid_monitor] {
	    set monitor $::monitor_value
	} else {
	    upvar #0 [lindex $scans 0] scanid
	    set monitor $scanid(monitor)
	}
	decorate_graph [lindex $scans 0]
    } else {
	return
    }


    # Ugly hack to show temperature
    if { $::show_temperature } {
	foreach id $runs {
	    ::ky_$id delete :
	    ::kdy_$id delete :
	    if { [vector_exists ::TEMP_$id] } { ::ky_$id expr "::TEMP_$id" }
	}
	foreach id $scans {
	    ::${id}_ghosty delete :
	    ::${id}_ghostdy delete :
	}
	return
    }

    # scale runs by monitor and attenuation
    foreach id $runs {
	upvar #0 $id rec
	::ky_$id expr "$monitor*$rec(k)*::y_$id"
	::kdy_$id expr "$monitor*sqrt($rec(k)*$rec(k)*::dy_$id*::dy_$id \
		+ ::y_$id*::y_$id*$rec(dk)*$rec(dk))"
    }

    # XXX FIXME XXX do we really want to update the scan _every_ operation?
    # If so, then we need some way to delete the junk scans that get
    # created as we explore our data.
    # If not, then we need some other even to trigger the update, but what?
    # Save scan would work --- do we want to force every scan to be saved
    # before it can be reduced?
    # setscan $runs

    # XXX FIXME XXX ugly quick hack --- please figure out how to do this
    # cleanly.  The problem is that the ghosts of scans past which share
    # the screen with the pieces of the new scan need to be displayed
    # with the same monitor count.  Maybe separate monitor scaling from
    # attenuator scaling so that all graph elements are handled the same
    # way?
    foreach id $scans {
	upvar #0 $id scanrec
	::${id}_ghosty expr "$monitor/$scanrec(monitor)*::${id}_y"
	::${id}_ghostdy expr "$monitor/$scanrec(monitor)*::${id}_dy"
    }
}

proc atten_revert { runs } {
    foreach id $runs {
	upvar #0 $id rec
	set rec(k) 1.0
	set rec(dk) 0.0
    }
}

proc pretty_slit { m b } {
    if { $m == 0.0 } {
	return $b;
    } elseif { $b == 0.0 } {
	return "[fix $m] theta"
    } elseif { $b < 0.0 } {
	return "[fix $m] theta - [expr -$b]"
    } else {
	return "[fix $m] theta + $b"
    }
}

proc slit_ratio { id slit Q } {
    upvar #0 $id rec
    if { [info exists rec($slit)] && [info exists rec($Q)] } {
	set slope [expr ($rec(stop,$slit) - $rec(start,$slit))/($rec(stop,$Q)-$rec(start,$Q))]
	set intercept [expr $rec(start,$slit) - $slope*$rec(start,$Q)]
    } else {
	set slope NaN
	set intercept NaN
    }
    return [list $slope $intercept]
}

proc compare_slits { baseid thisid } {
    upvar #0 $baseid base
    upvar #0 $thisid this

    error "compare slits is not yet implemented"
    # XXX FIXME XXX this is old code.  The new code will have to call
    # slit_ratio itself (maybe caching the result).  Note that the
    # ratio will be based on motor 3 in some cases and motor 4 in others
    # (for NG1).  Fixed slits and variable slits should be allowed to
    # overlap (at least at one point).  Ideally, slits would only be
    # checked for the overlapping region.
    if { [info exists base(slits)] != [info exists this(slits)] } {
	return "internal error --- missing slit ratio for $base(file) or $this(file)"
    }
    if { [info exists base(slits)] } {
	foreach slit $base(slits) {
	    if { abs($base_m-$this_m)>1e-10 || abs($base_b-$this_b)>1e-10 } {
		set base_eq [pretty_slit $base_m $base_b]
		set this_eq [pretty_slit $this_m $this_b]
		message "different slit $slit: $base_eq != $this_eq"
	    }
	}
    }

}

# Return true if two runs contain the same sort of thing (same instrument
# same slits, etc.)
proc run_matches { base_rec target_rec } {
    # returns error string if no match, otherwise return {}
    upvar #0 $base_rec base
    upvar #0 $target_rec this
    if { ![string equal $this(dataset) $base(dataset)] } {
	return "different data sets: $base(dataset) != $this(dataset)"
    }
    if { ![string equal $this(instrument) $base(instrument)] } {
	return "different extension: $base(instrument) != $this(instrument)"
    }
    if { ![string equal $this(type) $base(type)] } {
	return "different data types: [typelabel $base(type)] != [typelabel $this(type)]"
    }
    if { ![string equal $this(index) $base(index)] } {
	return "different index: $base(index) != $this(index)"
    }
    if { ![string equal $this(base) $base(base)] } {
	return "different monitor counting style: $base(base) != $this(base)"
    }
    # the following should never be true since we just determined
    # that the types matched
    if { [info exists this(rockbar)] } {
	if { ![info exists base(rockbar)] } {
	    return "internal error --- missing 2 theta center indicator for $base(file)"
	}
	if { abs($this(rockbar) - $base(rockbar)) > 1e-10 } {
	    return "different 2 theta centers: $base(rockbar) != $this(rockbar)"
	}
    } else {
	if { [info exists base(rockbar)] } {
	    return "internal error --- missing 2 theta center indicator for $this(file)"
	}
    }
    # XXX FIXME XXX put slit comparison code back in? Yes.

    if { $base(T) != $this(T) } {
	return "different temperature: $base(T) != $this(T)"
    }
    if { $base(H) != $this(H) } {
	return "different field: $base(H) != $this(H)"
    }
    return {}
}

# Return true if the given run extends the given list of runs.
# This is the case when if run starts before the leftmost run
# in the runlist or ends after the rightmost.
proc run_extends { runlist run } {
    if { [llength $runlist] == 0 } { return 1 }
    set start 1.e308
    set stop -1.e308
    foreach id $runlist {
	upvar #0 $id rec
	set fstart $rec(start)
	set fstop $rec(stop)
	if { $fstart < $start } { set start $fstart }
	if { $fstop > $stop } { set stop $fstop }
    }
    upvar #0 $run rec
    set fstart $rec(start)
    set fstop $rec(stop)
    return [expr ($fstart<$start && $fstop<$stop) \
	    || ($fstart>$start && $fstop>$stop)]
}

# based on the symbol density, decide how we will display them
proc addrun_pretty_symbols { } {
    return
    # XXX FIXME XXX there has got to be a better way to make it look pretty

    # count number of symbols to display
    set count 0
    foreach id $::addrun { incr count [::x_$id length] }
    if { $count > 100 } {
	foreach el $::addrun { .graph elem conf $el -pixels 1 -scalesymbol 0 }
    } else {
	foreach el $::addrun { .graph elem conf $el -pixels 1 -scalesymbol 0 }
    }
}

# load the data for a record and add it to the graph
proc addrun_add { id } {
    if { [lsearch $::addrun $id] >= 0 } {
	return ;# it isn't an error to add it again
	error "addrun add already contains [set ::${id}(file)]"
    } elseif { [info exists ::${id}(loading)] } {
	# puts "Patientez s'il vous plait, on attend l'octave sync."
	return ;
    } elseif { ![load_run $id] } {
	return ;# the error should be reported via message
	error "addrun add could not open [set ::${id}(file)]"
    }


    ## XXX FIXME XXX need to verify slit ratios.  Something like:
    ## foreach old $::addrun
    ##   if [find_overlap $old $id] > 0
    ##     if !equal_slit_ratios
    ##       if mean(new which overlaps old) > mean(old which overlaps new)
    ##         vector create ::idx_$new(length(new))
    ##         ::idx_$new(overlap) set 0
    ##       elseif vector exists ::idx_$old
    ##         ::idx_$old(overlap) set 0
    ##       else
    ##         vector create ::idx_$old(length(old))
    ##         ::idx_$old(overlap) set 0
    ##         .graph elem conf $old -weight ::idx_$old -styles {{excludePoint -0.5 0.5}}
    ##       endif
    ##     endif
    ##   endif
    ## endfor


    # XXX FIXME XXX want the legend order to be add[0:end] but
    # display order to be add[end:-1:0] (that is, the last item
    # added should appear last in the legend but its data line
    # should be drawn above the first dataline so that the first
    # is hidden.  Unfortunately display order equals legend order.
    # Since display order is more important, use lappend and
    # display the legend in reverse order.
    # XXX WARNING XXX Don't change the order of the elements in $::addrun
    # since remove, matches, atten_set, atten_revert, etc. all use the
    # properties of the first element as the properties for the entire list.
    lappend ::addrun $id

    catch { if { [set ::${id}(psd)] } { psd $id } }

    set ::${id}(legend) "[set ::${id}(run)][set ::${id}(index)]"
    if { [llength $::addrun] == 1 } {
	.graph axis conf x -min "" -max ""
	decorate_graph $id
	.graph conf -title "\[[set ::${id}(dataset)]] [set ::${id}(comment)]"
	set ::addrun_color 0
    } else {
	if { [incr ::addrun_color] >= [llength $::colorlist] } {
	    set ::addrun_color 0
	}
    }
    set color [lindex $::colorlist $::addrun_color]
    .graph elem create $id -color $color \
	    -xdata ::x_$id -ydata ::ky_$id \
	    -label "[set ::${id}(legend)]" -labelrelief raised
    .graph elem show [concat [ldelete [.graph elem show] $id] $id]
    if [blt_errorbars] {
	.graph elem conf $id -yerror ::kdy_$id -showerrorbar $::erraddrun
    }
    if [vector_exists ::idx_$id] {
	.graph elem conf $id -weight ::idx_$id -styles {{excludePoint -0.5 0.5}}
    }
    ## XXX FIXME XXX how to be sure the most recently added is not covered?
#    .graph elem show "[lsort [.graph elem names scan*]] $::addrun"

    .tree itemconfigure $id -image $::image(select)
}

proc addrun_addscan { id } {
    # if scan is already displayed then don't do anything
    if { [llength [.graph element names $id]] == 1 } { return }

    # If no scans displayed then reset the colour index.  Note that
    # scan colors count backward from the end of the list so that they
    # tend not to collide with the new scan part colours.
    if { [llength [.graph element names scan*]] == 0 } {
	set ::addrun_scancolor [llength $::colorlist]
    }
    if { [incr ::addrun_scancolor -1] < 0 } {
	set ::addrun_scancolor [expr [llength $::colorlist] - 1]
    }
    set color [lindex $::colorlist $::addrun_scancolor]

    # Create vectors to hold the ghosted scans.  We need separate vectors
    # because the values need to be displayed with the same monitor as the
    # new scans, and this is different from the monitor of the scans in the
    # reduce graph.
    ::${id}_y dup ::${id}_ghosty
    ::${id}_dy dup ::${id}_ghostdy

    # Display the ghosted scan with error bars
    .graph element create $id -xdata ::${id}_x -ydata ::${id}_ghosty \
	    -color $color -label "[set ::${id}(type)] [set ::${id}(legend)]" \
	    -pixels 1 -scalesymbol 0 -labelrelief raised
    if [blt_errorbars] {
	.graph elem conf $id -yerror ::${id}_ghostdy -showerrorbar $::erraddrun
    }
}

proc addrun_clearscan {idlist} {
    if {[string equal $idlist -all] } {
	set idlist [.graph element names scan*]
    }
    foreach id $idlist {
	catch { .graph element delete $id }
	catch { vector destroy ::${id}_ghosty ::${id}_ghostdy }
    }
}

# remove a record from the graph and free its associated data
set ::addrun {} ;# start with nothing
proc addrun_remove { id } {
    # check first if the record has been added
    if { [lsearch $::addrun $id] < 0 } { return }

    # remove it from the graph
    catch { .graph element delete $id }

    # remove it from the list
    set ::addrun [ldelete $::addrun $id]

    # remove the vectors from memory
    clear_run $id

    # remove the "selected" indicator from the tree
    .tree itemconfigure $id -image $::image(clear)

    # redraw the graph
    if { [llength $::addrun] > 0 } {
	# Redraw the title and labels in case the first run changed
	set id [lindex $::addrun 0]
	decorate_graph $id
	.graph conf -title "\[[set ::${id}(dataset)]] [set ::${id}(comment)]"
    }
}

proc addrun_accept {} {
    blt::busy hold . 

    # sort run list by index
    foreach id $::addrun {
	lappend runlist([set ::${id}(index)]) $id
    }

    # build indices as separate lines
    foreach index [lsort [array names runlist]] {
	lappend scanlist [setscan $runlist($index)]
    }

    # clear the runs
    addrun clear

    # add the scans
    foreach scan $scanlist {
	addrun_addscan $scan
    }

    # set the scale on the ghost scans
    atten_set {}

    blt::busy release .
}

proc addrun_matches { arg } {
    if { [llength $::addrun] == 0 } { return {} }

    # build a list of indexes used
    foreach id $::addrun {
	set index [set ::${id}(index)]
	if ![info exists heads($index)] { set heads($index) $id }
    }

    # if the new run shares an existing index, check that it conforms
    set index [set ::${arg}(index)]
    if [info exists heads($index)] {
	return [run_matches $heads($index) $arg]
    } else {
	return {}
    }
}

proc addrun { command args } {
    switch -- $command {
	align {
	    # recalculate alignment
	    if { $::prefer_aligned } {
		atten_calc $::addrun
	    } else {
		atten_revert $::addrun
	    }
	    atten_set $::addrun
	    atten_table_reset
	}
	create {}
	element {}
	head { return [lindex $::addrun 0] }
	load {}
	accept {
	    addrun_accept
	}
	save {
	    addrun clear
	}
	clear {
	    if { [llength $::addrun] == 0 } {
		addrun_clearscan -all
	    } else {
		foreach id $::addrun { addrun_remove $id }
	    }
	}
	clearscan {
	    addrun_clearscan $args
	}
	print {	}
	empty {
	    return [expr [llength $::addrun] == 0]
	}
	contains {
	    return [expr [lsearch $::addrun $args] >= 0 ]
	}
	add {
	    addrun_add $args
	}
	remove {
	    addrun_remove $args
	}
	matches {
	    return [addrun_matches $args]
	}
	extends {
	    return [run_extends $::addrun $args]
	}
	default {
	    error "addrun load|save|empty|contains|add|remove|matches|extends"
	}
    }
}

proc toggle_background { node } {
    # update indicator in tree
    set newtext [string map {A3 A4 A4 A3} [.tree itemcget $node -text]]
    .tree itemconfigure $node -text $newtext

    # make sure new records use the new indicator
    set dataset $::background_basis_nodes($node)
    set ::background_basis($dataset) \
	    [string map { A3 A4 A4 A3 } $::background_basis($dataset)]

    # Clear the cumulative range from the cache
    array unset ::grouprange $node

    # Update existing records to use the new Q range (including records
    # currently displayed on the graph).
    switch $::background_basis($dataset) {
	A3 {
	    foreach id [.tree nodes $node] {
		set ::${id}(start) [set ::${id}(start,3)]
		set ::${id}(stop) [set ::${id}(stop,3)]
		if {[vector_exists ::x_$id]} {
		    ::A3_$id dup ::xth_$id
		    ::x_$id expr [ a3toQz ::A3_$id [set ::${id}(L)] ]
		}
	    }
	}
	A4 {
	    foreach id [.tree nodes $node] {
		set ::${id}(start) [set ::${id}(start,4)]
		set ::${id}(stop) [set ::${id}(stop,4)]
		if {[vector_exists ::x_$id]} {
		    ::xth_$id expr ::A4_$id/2
		    ::x_$id expr [ a4toQz ::A4_$id [set ::${id}(L)] ]
		}
	    }
	}
    }
}

proc redraw_range_indicators {} {
    # redraw range bars in tree using new start/stop values
    # XXX FIXME XXX I don't want to expose this much of the internals of Tree
    Tree::_draw_tree .tree
    Tree::_redraw_selection .tree
    Tree::_update_scrollregion .tree
}

proc reset_backgrounds { } {
    foreach node [array names ::background_basis_nodes] {
	set dataset $::background_basis_nodes($node)
	if {![string equal $::background_default \
		$::background_basis($dataset)]} {
	    toggle_background $node
	}
    }
    redraw_range_indicators
}

# toggle_section {-keep bool} {-force bool} {-extend bool} -node node
proc toggle_section { args } {
#puts toggle_section:$args
    array set opt { -force 0 -extend 0 -keep 0 -node {}}
    array set opt $args
    if { [string equal $opt(-node) {}] } {
	set node [.tree selection get]
    } else {
	set node $opt(-node)
	.tree selection set $node
    }

    # make sure it is a leaf node
    if { ![string equal [.tree itemcget $node -data] "record" ] } {
	# click on background to change to A3 rather than A4
	if { ![info exists ::background_basis_nodes($node)] } { return }
	toggle_background $node
	redraw_range_indicators
	return
    }

    # build list of nodes we want to work with
    if { $opt(-extend) } {
	set nodes {}
	# autoselect following nodes which extend the range
	set rest [.tree nodes \
		[.tree parent $node] [.tree index $node] end]
	foreach id $rest {
	    set message [run_matches $node $id]
	    #puts "trying [array get ::$id]"
	    #puts "message: \"$message\""
	    if { [string equal $message ""] } {
		if { [run_extends $nodes $id] } {
		    lappend nodes $id
		} else {
		    break
		}
	    }
	}
    } else {
	set nodes $node
    }

#puts "contains: [ addrun contains $node ], keep: $opt(-keep)"
    if { !$opt(-force) && ([ addrun contains $node ] ^ $opt(-keep)) } {
	# remove entire list
	foreach node $nodes { addrun remove $node }
    } else {
	# add entire list
	set message [addrun matches $node]
	if { ![string equal $message ""] } {
	    # .message conf -text $message
	    if { $opt(-force) == 0 } {
		message "$message --- use Shift-Click to override"
		bell
		return
	    } else {
		message $message
	    }
	}
	foreach node $nodes { addrun add $node }
    }
    if { $::prefer_aligned } { atten_calc $::addrun }
    atten_set $::addrun
}

proc clear_run {id} {
    upvar #0 $id rec
    if { [incr rec(loaded) -1] > 0} { return }
    if { $rec(loaded) < 0 } {
	set rec(loaded) 0
	error "reference count error for $id"
    }
    eval vector destroy [vector names ::*_$id]
}


proc decorate_graph { id } {
    upvar #0 $id rec
    .graph axis conf x -title $rec(xlab)
    # XXX FIXME XXX Ewww!  If the user controls the monitor and we
    # are plotting something vs. the monitor, then we need to use that
    # monitor in the graph.
    if { [valid_monitor] && [string match "Counts per *" $rec(ylab)] } {
	.graph axis conf y -title [monitor_label $rec(base) $::monitor_value]
    } else {
	.graph axis conf y -title $rec(ylab)
    }
    if { [info exists rec(Qrockbar)] } {
	.graph marker conf rockbar -hide 0
	# XXX FIXME XXX may have multiple Qz on same graph!
	.graph marker conf rocklab -hide 0 \
		-text "Qz=[fix $rec(Qrockbar)] $::symbol(invangstrom)"
    } else {
	.graph marker conf rockbar -hide 1
	.graph marker conf rocklab -hide 1
    }
    set date [clock format $rec(date) -format "%d-%b-%Y"]
    .graph marker conf date -hide 0 -text \
	"$rec(instrument) [typelabel $rec(type)] $rec(index)\n$date"
}

proc clear_graph {} {
    # clear the graph
    .graph marker conf rockbar -hide 1
    .graph marker conf rocklab -hide 1
    .graph axis conf x -min "" -max ""
    .graph conf -title ""
    .graph marker conf date -hide 1
}

# node is now active in the tree widget, so display it
proc view_file {widget node} {
    # show the data only if it is a leaf node
    if { ![string equal [$widget itemcget $node -data] "record"] } {
	# clear the text
	.filename conf -text ""
	text_clear .text
	return
    }

    upvar #0 $node rec

    # make the current record available to tkcon
    upvar #0 $node ::rec


    ## display the filename
    .filename conf -text "$rec(file) ($node)"

    ## display the file contents as text
    text_load .text $rec(file)
}

# XXX FIXME XXX chop superfluous code
# This is code for viewing a single file, which is something we don't
# do anymore.  Everything we view now is part of the scan we are building
# or a previous scan we have built.  There is probably no reason to keep
# this code around except maybe to show how 
if {0} {
    ## get the data from the file
    if { ![load_run $node] } {
	error "Could not load $rec(file)"
    }

    ## copy it to x,y,dy
    vector create ::x_data ::y_data ::dy_data
    ::x_$node dup ::x_data
    ::y_data expr "::y_$node * $rec(monitor)"
    ::dy_data expr "::dy_$node * $rec(monitor)"
    if { [info exists ::xth_$node] } {
	::xth_$node dup ::xth_data
    } else {
	catch { unset ::xth_data }
    }

    ## free the data record
    clear_run $node

    ## decorate the graph
    if [blt_errorbars] { .graph elem conf data -yerror ::dy_data }
    .graph element conf data -hide 0 -showerrorbar $::errviewfile
    decorate_graph $node
    .graph conf -title "\[$rec(dataset) $rec(run)] $rec(comment)"

    ## show the direction of the rocking curve using white space
    if { [info exists rec(Qrockbar)] } {
	set Qbase $rec(Qrockbar)

	# shift the graph x-axis if the rockbar isn't showing
	set max $::x_data(max)
	set min $::x_data(min)
	set range [expr $max - $min]
	.graph axis conf x -min "" -max ""
	if { $Qbase <= $min - $range } {
	    .graph axis conf x -min [expr $min - $range]
	} elseif { $Qbase > $min - $range  && $Qbase <= $min } {
	    .graph axis conf x -min [expr $Qbase - $range/10]
	}
	if { $Qbase >= $max + $range } {
	    .graph axis conf x -max [expr $max + $range]
	} elseif { $Qbase < $max + $range && $Qbase >= $max } {
	    .graph axis conf x -max [expr $Qbase + $range/10]
	}
    }
    update idletasks
}

## Show what portion of the total data range is used by a particular node.
## This is called by my hacked version of the BWidget Tree widget, which
## first draws the label for $node, then gives you the canvas widget $w and
## the bounding box [x0 y0 x1 y1] of the label on the canvas, and lets you
## add your own canvas annotations.  The tags used on the canvas items
## must be listed in the order given if the user is to click on your
## annotations to select the node.
proc decorate_node { node w x0 y0 x1 y1 } {
    # make sure it is a leaf node
    if { [string equal [.tree itemcget $node -data] "record"] } {
	upvar #0 $node rec
	# XXX FIXME XXX need a better way to indicate no bar
	if [string equal $rec(type) other] return
        set gid [ .tree parent $node ]
	group_range $gid shift end
	if { $end == $shift } {
	    set shift [expr $shift - 0.1]
	    set end [expr $end + 0.1]
	}

	set scale [expr 50.0/($end - $shift)]
	set x1 [expr $x0 + 40.0 ]
	set y0 [expr $y0 + 1.0 ]
	set y1 [expr $y1 - 1.0 ]
	$w create rect $x1 $y0 [expr $x1+50.0] $y1 \
		-fill $::qrange_fill \
		-outline $::qrange_outline \
		-width $::qrange_outlinewidth \
		-tags "TreeItemSentinal img i:$node"
	$w create rect \
	        [expr ($rec(start)-$shift)*$scale + $x1] $y0 \
	        [expr ($rec(stop)-$shift)*$scale + $x1] $y1 \
	        -fill $::qrange_color \
		-outline $::qrange_outline \
		-width $::qrange_outlinewidth \
		-tags "TreeItemSentinal img i:$node"
	if {[info exists rec(rockbar)]} {
	    # there is a rockbar, try to show Qx=0
	    set bar $rec(rockbar)
	} else {
	    # if no rockbar, try to show Qz=0
	    set bar 0
	}

	# make sure the rocking curve bar is in the data range
	if { $bar >= $shift && $bar <= $end } {
	    set bar [expr ($bar-$shift)*$scale + $x1 - floor($::qrange_barwidth/2)]
	    $w create rect \
		    $bar [expr $y0 + $::qrange_outlinewidth] \
		    [expr $bar + $::qrange_barwidth] $y1 \
		    -fill $::qrange_barcolor -width 0 \
		    -tags "TreeItemSentinal img i:$node"
	}
    }
}

# The variable ::rec_count is the maximum used record number.  It is
# used to generate new record IDs.
set ::rec_count 0

# clear the current set of records from memory
proc clear_set {} {
    catch { unset ::group }
    catch { unset ::grouprange }
    catch { array unset ::background_basis_nodes }
    catch { array unset ::background_basis }
    foreach var [info vars ::recR*] { array unset $var }
    set var [vector names ::*_recR*]
    if { [llength $var] > 0 } { eval vector destroy $var }
    catch { unset ::dataset }
    ## Don't reuse record numbers so that way we know whether or not
    ## we can reload the scan
    # set ::rec_count 0
}

proc markother {file} {
    # create a new record
    # XXX FIXME XXX make this generic
    set id recR[incr ::rec_count]
    upvar #0 $id rec
    set rec(id) $id
    set rec(file) $file
    
    set rec(load) loadother
    
    set root [file rootname $file]
    set run [string range $root end-2 end]
    set dataset [string range [file tail $root] 0 end-3]

    set rec(date) [file mtime $file]
    set rec(type) [file extension $file]
    set rec(comment) "Preprocessed file $file"
    set rec(T) unknown
    set rec(H) unknown
    set rec(base) unknown
    set rec(run) $run
    set rec(index) {}
    set rec(start) 0
    set rec(stop) 0

    if { [info exists ::dataset($dataset)] } {
	set rec(dataset) $dataset
	set rec(instrument) [lindex [split [lindex [lsort [array names ::group $dataset,*]] 0] ,] 1]
    } else {
	set rec(dataset) other
	set rec(run) [file tail $root]
	set rec(instrument) other
    }
    categorize
}

proc marktype {type {start 0} {stop 0} {index ""}} {
    upvar rec rec
    set root [file rootname $rec(file)]
    set rec(run) [string range $root end-2 end] ;# 3 digit run number
    set rec(dataset) [string range [file tail $root] 0 end-3] ;# run name
    set rec(type) $type
    set rec(start) $start
    set rec(stop) $stop
    set rec(index) $index
    categorize
}

proc categorize {} {
    upvar rec rec

    # keep track of the date range for the dataset
    if { [info exists ::dataset($rec(dataset))] } {
	if { $rec(date) > $::dataset($rec(dataset)) } {
	    set ::dataset($rec(dataset)) $rec(date)
	}
    } else {
	set ::dataset($rec(dataset)) $rec(date)
    }
    lappend ::group($rec(dataset),$rec(instrument),$rec(type)) $rec(id)
}

proc dataset_list {} {
    return [lsort [array names ::dataset]]
}

proc group_list {dataset} {
    return [lsort -dictionary [array names ::group "$dataset,*"]]
}

proc group_range {gid Vstart Vstop } {
    upvar $Vstart start
    upvar $Vstop stop
    if { [info exists ::grouprange($gid)] } {
	foreach {start stop} $::grouprange($gid) {}
    } else {
	set start 1.e100
	set stop -1.e100
	foreach id $::group($gid) {
	    upvar #0 $id rec
	    if { $start > $rec(start) } { set start $rec(start) }
	    if { $stop < $rec(stop) } { set stop $rec(stop) }
	}
	set ::grouprange($gid) [list $start $stop]
    }
}


proc parse1 {line} {
    upvar rec rec
    foreach { a rec(internal_name) b date \
	    c rec(scantype) d rec(base) \
	    e f g g1 g2 g3 g4 g5 g6 } [split $line "'"] {}
    if {[catch { clock_scan $date } rec(date)]} {
	message "clock scan fails for $date: $rec(date)"
	#puts $rec(date)
	set rec(date) 0
    }
    # a,g are empty, b,c is space between fields, d is monitor/prefactor,
    # f is 'RAW', g1 ... g6 are guard values in case the format changes
    foreach { rec(mon) rec(prf) rec(pts) g1 g2 g3 g4 g5 g6 } "$d $e" {}
}

proc parse2ng1 {line} {
    upvar rec rec
    # XXX FIXME XXX foreach magic is dangerous if the file format changes
    # Hconv dH ... g6 are guard values against new fields
    foreach { a b c d e f g rec(L) rec(T) rec(dT) rec(H) rec(\#Det) Hconv dH g3 g4 g5 g6 } $line {}
    set rec(monitor) [expr $rec(mon)*$rec(prf)]
}

proc parse2ng7 {line} {
    upvar rec rec
    foreach { rec(Mon1) rec(Exp) rec(Dm) rec(L) rec(T) rec(dT) rec(H) \
	    rec(\#Det) rec(SclFac) g1 g2 g3 g4 g5 g6 } $line {}
    set rec(monitor) 1.0
}



# MACRO loadhead
# - defines lines as the head lines of the file
# - calling procedure automatically returns if there is an error
# - creates a new record
# naughty, yes, but hopefully fast.
proc loadhead {file} {
    # slurp file
    if [catch {open $file r} fid] {
	puts "couldn't open $file";
	return -code return
    }
    set text [read $fid]
    close $fid

    # if it has a motor line, then assume the format is good
    set offset [ string first "\n Mot: " $text]
    if { $offset < 0 } {
	# puts "couldn't find Mot: line in $file";
	return -code return
    }
    set lines [split [string range $text 0 [incr offset -1]] "\n"]

    # create a new record
    set id recR[incr ::rec_count]
    upvar #0 $id rec
    set rec(id) $id
    set rec(file) $file

    # parse the header1 line putting the fields into "rec"
    parse1 [lindex $lines 0] ;# grab record variables from line 1

    # parse the comment line
    set rec(comment) [string trim [lindex $lines 2]]

    # parse the motor lines
    upvar fixed fixed
    set fixed 1
    foreach line [lrange $lines 5 end] {
	foreach { name start step stop } $line {
	    set rec(stop,$name) $stop
	    # make sure start is before end
	    # (you can tell if is backward from step)
	    # XXX FIXME XXX rename start/stop to lo/hi
	    if { $start <= $stop } {
		set rec(start,$name) $start
		set rec(step,$name) $step
		set rec(stop,$name) $stop
	    } else {
		set rec(start,$name) $stop
		set rec(step,$name) $step
		set rec(stop,$name) $start
	    }
	    if { $start != $stop } { set fixed 0 }
	}
    }

    # return the header2 line
    upvar header2 header2
    set header2 [lindex $lines 3]
    return $id
}

proc load_run {id} {
    upvar #0 $id rec

    # It is an error to load while a load is pending
    # Unfortunately it could happen if for example the user clicks
    # to load the file again before the file could be loaded in the
    # first place.
    # XXX FIXME XXX this works if there is only one 'client' for the
    # loaded record since that client doesn't need multiple copies.
    # If there are multiple clients, then the other clients should
    # block until loading completes.  This didn't work when I tried
    # it using "vwait rec(loading)", presumably because the octave
    # sync block which allowed another thread to enter was waiting
    # on a separate variable.
    if [info exists rec(loading)] { 
	puts "shouldn't be here if already loading" 
    }

    # check if already loaded (using reference counts)
    if {![info exists rec(loaded)]} { set rec(loaded) 0 }
    if {$rec(loaded) > 0} { incr rec(loaded); return 1 }

    # kill load from a separate "thread"
    set rec(loading) 1

    # default values for everything
    set rec(ylab) R
    set rec(xlab) Q
    # attenuator factor; if you remove the condition, then it
    # will keep the last value used for the attenuator.
    # XXX FIXME XXX do we want to reset it?
    # if { ![info exists rec(k)] } {
	set rec(k) 1.0
	set rec(dk) 0.0
    # }

    
    # call the type-specific loader
    if { [$rec(load) $id] } {

	# define scaled vectors (atten_set sets their values according to the
	# scale factor and the current monitor)
	vector create ::ky_$id ::kdy_$id

	# register the successful load
	incr rec(loaded)
    }

    # okay to try load again now
    unset rec(loading)

    # let the loader know if load was successful.
    return $rec(loaded)

}


# Convert a matrix of 
# val val val \n val val val \n ...
# into vectors Col1 Col2 Col3
proc get_columns { id columns data } {
    # convert newlines to spaces so that we can change the data to a list
    set data [string map { "\n" " " } $data]
    if { [catch { eval list $data } valuelist] } {
	message "data isn't a matrix of numbers"
	return 0
    }

    # create data columns
    foreach col $columns { 
	vector create ::${col}_$id 
	::${col}_$id length 0
    }

    # translate rows of data to BLT vectors
    # XXX FIXME XXX maybe faster to do this in octave until BLT has
    # the ability to process ranges of the form start:step:stop
    if [catch {
	foreach $columns $valuelist {
	    foreach col $columns {
		::${col}_$id append [set $col]
	    }
	}
    }] {
	message "data isn't a matrix of numbers"
	return 0
    }
    return 1
}

# textkey text label name
#
# Set name to the value associated with label in text. 
#
# Label can be a pattern such as temp\w*.  The match is case insensitive 
# unless the label starts with (?c). If you want to be less accepting,
# you can use non-capturing grouping followed by ? to optionally match the
# suffix.  For example, the label {T(?:emp(?:erature)?)?} matches "t", 
# "temp" and "temperature", but not "time". Alternate labels can be 
# specified with non-grabbing branch patterns such as (?:H|field).
#
# The format is line oriented, with any sort of comment characters allowed
# at the start of the line, followed by label, possibly followed by : or =
# followed by a value which may or may not be in quotes.
# The following are all valid label-value pairs:
#    Title This is the title
#    !date 2002-12-10
#    % DATE     Dec 10, 2002
#    # wavelength: 1.75
#    # temperature=15
#    field "17"
#
# XXX FIXME XXX how can we support units?  Perhaps we don't.  We can process
# the returned string just like we do for date.
proc textkey { text label name } {
    set pattern {(?:\s*[:=]\s*|\s+)"?(.*?)"?\s*$}
    upvar $name value
    return [regexp -line -nocase "^\\W*$label$pattern" $text {} value]
}

proc loadother {id} {
    upvar #0 $id rec

    # suck in the data file
    if {[ catch { open $rec(file) r } fid ] } { return 0 }
    set data [read $fid]
    close $fid

    # XXX FIXME XXX could extract whatever info I can from
    # the file such as comment, type, etc.
    set rec(L) 4.75   ;# fixme don't want to default L!!
    set rec(monitor) 1.0
    textkey $data xlab(?:el)? rec(xlab)
    textkey $data ylab(?:el)? rec(ylab)
    textkey $data mon(?:itor)? rec(monitor)
    textkey $data (?:source|inst(?:rument)?) rec(instrument)
    textkey $data (?:wavelength|L) rec(L)
    textkey $data (?:title|comment) rec(comment)
    textkey $data (?:field|H) rec(H)
    textkey $data t(?:emp(?:erature)?)? rec(T)
    textkey $data linear islinear
    if [textkey $data date date] {
	catch { set rec(date) [clock_scan $date] }
    }

    # guess instrument and experiment type
    # We might have some combination of the following:
    #   # source <inst> <type>
    #   # source <inst>
    #   # inst[rument] <inst>
    #   # type <type>
    #   # spec <files>
    #   # back <files>
    #   # slit <files>
    # XXX FIXME XXX we should take the guesswork out of this
    unset rec(type)
    if [textkey $data source source] {
	set rec(instrument) [lindex $source 0]
	set sourcelab [lrange $source 1 end]
	# lookup label in type label table
	foreach {type label} [array get ::typelabel] {
	    if [string equal $sourcelab $label] {
		set rec(type) $type
		break;
	    }
	}
    }
    if ![info exists rec(instrument)] {
	textkey $data inst(?:rument)? rec(instrument)
    }
    if ![info exists rec(type)] {
	if ![textkey $data type rec(type)] {
	    # XXX FIXME XXX it's bogus trying to guess when I can just
	    # print out the type and forget about it
	    set havespec [textkey $data spec junk]
	    set haveback [textkey $data back junk]
	    set haveslit [textkey $data slit junk]
	    set havefoot [textkey $data foot\w* junk]
	    if { $havespec && $havefoot } {
		message "corrected reflectivity curve"
		set rec(type) spec
	    } elseif { $havespec && $haveback && $haveslit } {
		message "uncorrected reflectivity curve"
		set rec(type) spec
	    } elseif { $havespec && $haveslit } {
		message "uncorrected specular"
		set rec(type) spec
	    } elseif { $havespec && $haveback } {
		message "background subtracted"
		set rec(type) spec
	    } elseif { $havespec } {
		message "specular"
		set rec(type) spec
	    } elseif { $haveback && $haveslit } {
		message "background / slitscan"
		set rec(type) back
	    } elseif { $haveback } {
		message "background"
		set rec(type) back
	    } elseif { $haveslit } {
		message "slit scan"
		set rec(type) slit
	    } else {
		message "unknown curve type"
		set rec(type) other
	    }
	}
    }
    

    if { [string match -nocase {*[abcd]} $rec(file)] } {
	# oops --- the usual extension .spec ends with C
	if { ![string match -nocase {*spec} $rec(file)] } {
	    set rec(index) [string toupper [string index $rec(file) end]]
	}
    }

    # Strip all comments and blank lines
    # Comments start with # / ! ; or % and go to the end of the line so
    # no block comments allowed.  This will prepend a \n.
    regsub -all -line {(?:[[:blank:]]*(?:[#/!%;].*$)?\n)+[[:blank:]]*} \n$data\n \n data

    # Check that whether we have QR or QRdR data
    set D {[-+0-9dDeE.]+}

    if {[regexp "^\n(?:$D\\s+$D\n)+$" $data]} {
	set rec(col) [list x y]
	if ![get_columns $id $rec(col) $data] { return 0 }
	vector create ::dy_$id
	::dy_$id expr "sqrt(::y_$id)"
    } elseif { [regexp "^\n(?:$D\\s+$D\\s+$D\n)+$" $data]} {
	set rec(col) [list x y dy]
	if ![get_columns $id $rec(col) $data] { return 0 }
    } else {
	message "$rec(file) is not a Q,R or Q,R,dR data file"
	return 0
    }

    # if data is log, exponentiate
    if [info exists islinear] {
	set islinear [string is true $islinear]
    } else {
	set islinear 1
        if [string match {[Ll]og *} $rec(ylab)] {
	    set rec(ylab) [string range $rec(ylab) 4 end]
	    set islinear 0
        } elseif [vector expr "sum(::y_$id > 0) < length(::y_$id)/3"] {
	    set islinear 0
	}
    }
    if { !$islinear } {
	::y_$id expr "exp(log(10) * ::y_$id)"
	::dy_$id expr "::y_$id * ::dy_$id/log(10)"
    }
    

    # correct for monitor
    ::y_$id expr "::y_$id/$rec(monitor)"
    ::dy_$id expr "::dy_$id/$rec(monitor)"

    return 1
}

proc icp_load {id} {
    upvar #0 $id rec

    # suck in the data file
    if {[ catch { open $rec(file) r } fid ] } { return 0 }
    set data [read $fid]
    close $fid

    # chop everything until after the Mot: line
    set offset [string last "\n Mot: " $data ]
    if { $offset < 0 } { return 0 }
    set offset [string first "\n" $data [incr offset]]
    set data [string range $data [incr offset] end]

    # convert the column headers into a list (with special code for #1,#2)
    set offset [string first "\n" $data]
    set col [string range $data 0 [incr offset -1]]
    set col [string map { "#1 " "" "#2 " N2 } $col]
    set col [string map { COUNTS y } $col]
    set rec(col) [eval list $col ]
    set data [string range $data [incr offset] end]

    # load the data columns into ::<column>_<id>
    if { [string first , $data] >= 0 } {
	# XXX FIXME XXX this is the wrong place to clear the psd.
	psd clear

	# Data contains position sensitive detector info.
	#   c1 c2 ... c_k\np1, p2, ..., p_i,\n..., p_n\n
	#   ...
	#   c1 c2 ... c_k\np1, p2, ..., p_j,\n..., p_n\n
	# Count the number of lines as the number times we see
	#   c_k \n p1,
	# Note that we cannot count the number of lines without
	# commas, since p_n might be on a line by itself.
	set lines [regexp -all {[0-9] *\n *[0-9]+,} $data]

	# Strip the commas so that sscanf can handle it
	set data [ string map {"," " " "\n" " "} $data ]
	octave eval "x=sscanf('$data', '%f ',Inf)"

	# Reshape into a matrix of the appropriate number of lines
	octave eval "x=reshape(x,length(x)/$lines,$lines)'"

	# Return the first k columns into $rec_$col, and put the
	# rest into psd. I'll leave it to the data interpreter to
	# decide what to do with the psd table.
	# XXX FIXME XXX it seems a little silly to send the string
	# from tcl to octave, send the columns back to tcl as vectors,
	# then send the vectors back to octave --- I'm doing this because
	# in the non-psd case, I do not use octave to interpret the
	# columns, but maybe I should be.
	set i 0
	foreach c $rec(col) { 
	    vector create ::${c}_$id 
	    octave recv ${c}_$id x(:,[incr i])
	}
	octave eval "psd = x(:,[incr i]:columns(x))"
	octave eval { psderr = sqrt(psd) + (psd==0) }
	octave sync
	set rec(psd) 1
    } else {
	if ![get_columns $id $rec(col) $data] { return 0 }
	set rec(psd) 0
    }
    
    # Define error bars.
    # When y == 0, dy = sqrt(y) + !y -> 1
    # When y != 0, dy = sqrt(y) + !y -> sqrt(y)
    vector create ::dy_$id
    ::dy_$id expr "sqrt(::y_$id) + !::y_$id"
    ::y_$id expr "::y_$id/$rec(monitor)"
    ::dy_$id expr "::dy_$id/$rec(monitor)"

    # average temperature
    if { [vector_exists ::TEMP_$id] } {
	set rec(Tavg) "[vector expr mean(::TEMP_$id)]([vector expr sdev(::TEMP_$id)])"
    }

    return 1
}

proc default_x {id} {
    upvar #0 $id rec
    
    set col [lindex $rec(col) 0]
    switch -- $col {
	MON { 
	    ::MON_$id dup ::x_$id
	    cumsum ::x_$id
	    set rec(xlab) "Monitor count" 
	}
	MIN { 
	    ::MIN_$id dup ::x_$id
	    cumsum ::x_$id
	    set rec(xlab) "Time (min)" 
	}
	default { 
	    ::${col}_$id dup ::x_$id
	    set rec(xlab) $col 
	}
    }
}

proc monitor_label { base monitor } {
    
    # set ylabel according to count type
    if { [string equal -nocase $base "TIME"] } {
	set units "second"
    } else {
	set units "monitor count"
    }
    if { $monitor == 1 } {
	return "Counts per $units"
    } else {
	return "Counts per $monitor ${units}s"
    }
}

# set ::idx_$id to 0 for all points in the record $id for which 2*A3 != A4
proc exclude_specular_ridge {id} {
    upvar #0 $id rec
    vector create off_specular_ridge
    off_specular_ridge expr "2*::A3_$id != ::A4_$id"
    if {[vector expr prod(off_specular_ridge)] == 0.0} {
	if { ![vector_exists ::idx_$id] } {
	    off_specular_ridge dup ::idx_$id
	} else {
	    ::idx_$id expr "::idx_$id * off_specular_ridge"
	}
    }
    vector destroy off_specular_ridge
}

# Load contents of id(file) into x_id, y_id, dy_id
# Set id(xlab) and id(ylab) as appropriate
proc NG1load {id} {
    upvar #0 $id rec

    if ![icp_load $id] { return 0 }

    if { $rec(L) == 0.0 } { set rec(L) $::ng1wavelength }
    # yuck! wavelength in file may be wrong, so override but warn
    if { $rec(L) != $::ng1wavelength } {
	message "using wavelength $::ng1wavelength for $rec(L) in $rec(file)"
	set rec(L) $::ng1wavelength
    }

    # If column A1 is not stored in the datafile because the slits
    # are fixed, we need to set it to a column which is the value
    # of motor 1.  
    # XXX FIXME XXX Similarly for A2, but do we need A2?
    if { ![vector_exists ::A1_$id] } {
	lappend rec(col) A1
	vector create ::A1_${id}([::y_$id length])
	set ::A1_${id}(:) $rec(start,1)
    }

    # Exclude points which exceed 10000 counts/sec
    # The time column is rounded to the nearest hundredth, so all times
    # less than 0.005 minutes will go to 0.  The center of the time
    # range is 0.0025, so we will use that instead.
    # XXX FIXME XXX 1/x is not linear!  Perhaps we want the geometric
    # mean of the range?
    if { [vector_exists ::MIN_$id] } {
	vector create ::idx_$id
	::idx_$id expr "(::MIN_$id+(0.0025*(::MIN_$id==0.0)))*(600000/$rec(monitor)) > ::y_$id"
	if { [vector expr prod(::idx_$id)] == 1.0 } {
	    vector destroy ::idx_$id
	} else {
	    message "excluding points which exceed 10000 counts/second"
	}
    }

    switch $rec(type) {
	rock {
	    vector create ::x_$id
	    ::x_$id expr [ a3toQx ::A3_$id $rec(rockbar) $rec(L) ]
	    ::A3_$id dup ::xth_$id 
	    set rec(Qrockbar) [expr [a3toQz $rec(rockbar) $rec(L)]]
	    set rec(xlab) "Qx ($::symbol(invangstrom))"
	}
        rock3 {
            vector create ::x_$id
            ::x_$id expr [ a4toQx ::A4_$id [expr -$rec(rockbar)/2] $rec(L) ]
            ::A4_$id dup ::xth_$id
            set rec(Qrockbar) [expr [a4toQz -$rec(rockbar) $rec(L)]]
            set rec(xlab) "Qx ($::symbol(invangstrom))"
        }
	spec {
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	    vector create ::x_$id
	    ::x_$id expr [ a4toQz ::A4_$id $rec(L) ]
	    vector create ::xth_$id
	    ::xth_$id expr ::A4_$id/2
	    set rec(slit) A1_$id
	}
	slit {
	    # XXX FIXME XXX if slit 1 is fixed, should we use slit 2?
	    set rec(xlab) "slit 1 opening"
	    ::A1_$id dup ::x_$id
	}
	back {
	    exclude_specular_ridge $id
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	    set col $::background_basis($rec(dataset),$rec(instrument))
	    switch $col {
		A3 { 
		    vector create ::x_$id
		    ::x_$id expr [ a3toQz ::A3_$id $rec(L) ] 
		    ::A3_$id dup ::xth_$id
		}
		A4 {
		    vector create ::x_$id
		    ::x_$id expr [ a4toQz ::A4_$id $rec(L) ]
		    vector create ::xth_$id
		    ::xth_$id expr ::A4_$id/2
		}
	    }
	}
	default { default_x $id }
    }
    set rec(ylab) [monitor_label $rec(base) $rec(monitor)]

    if { $rec(psd) } {
	if { [vector_exists ::xth_$id] } {
	    octave send ::xth_$id Qz	    
	} else {
	    octave send ::x_$id Qz
	}
	vector create ::psd_$id ::psderr_$id
	octave recv psd_$id psd
	octave recv psderr_$id psderr
    }

    return 1
}

# Load contents of id(file) into x_id, y_id, dy_id
# Set id(xlab) and id(ylab) as appropriate
proc XRAYload {id} {
    upvar #0 $id rec

    if ![icp_load $id] { return 0 }

    if { $rec(L) == 0.0 } { set rec(L) $::xraywavelength }
    # yuck! wavelength in file may be wrong, so override but warn
    if { $rec(L) != $::xraywavelength } {
	message "using wavelength $::xraywavelength for $rec(L) in $rec(file)"
	set rec(L) $::xraywavelength
    }

    switch $rec(type) {
	rock {
	    vector create ::x_$id
	    ::x_$id expr [ a3toQx ::A3_$id $rec(rockbar) $rec(L) ]
	    ::A3_$id dup ::xth_$id 
	    set rec(Qrockbar) [expr [a3toQz $rec(rockbar) $rec(L)]]
	    set rec(xlab) "Qx ($::symbol(invangstrom))"
	}
	spec {
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	    vector create ::x_$id
	    ::x_$id expr [ a4toQz ::A4_$id $rec(L) ]
	    vector create ::xth_$id
	    ::xth_$id expr ::A4_$id/2
	}
	back {
	    exclude_specular_ridge $id
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	    set col $::background_basis($rec(dataset),$rec(instrument))
	    switch $col {
		A3 { 
		    vector create ::x_$id
		    ::x_$id expr [ a3toQz ::A3_$id $rec(L) ] 
		    ::A3_$id dup ::xth_$id
		}
		A4 {
		    vector create ::x_$id
		    ::x_$id expr [ a4toQz ::A4_$id $rec(L) ]
		    vector create ::xth_$id
		    ::xth_$id expr ::A4_$id/2
		}
	    }
	}
	default { default_x $id }
    }
    set rec(ylab) [monitor_label $rec(base) $rec(monitor)]

    return 1
}

set ::NG7_monitor_calibration_loaded 0
proc load_NG7_monitor_calibration {} {
    if { $::NG7_monitor_calibration_loaded } { return }

    # read the monitor calibration data
    set filename NG7monitor.cal
    if { [catch {open [file join $::VIEWRUN_HOME $filename]} fid] } {
	message "Unable to load NG7 monitor calibration $filename"
	# no monitor correction
	set ::NG7_monitor_calibration { 0\t1\n1e100\t1 }
    } else {
	set ::NG7_monitor_calibration [read $fid]
	close $fid
    }

    # Send it to octave.  Use constant extrapolation beyond the
    # xrange read from the file.
    # XXX FIXME XXX confirm what to do when counts/second exceeds 31000
    set data [string map { "\n" " " } $::NG7_monitor_calibration]
    octave eval "NG7monitor=sscanf('$data', '%f ', Inf)"
    octave eval {
	NG7monitor = reshape(NG7monitor,2,length(NG7monitor)/2)';
	if NG7monitor(1,1) != 0
	  NG7monitor = [0, NG7monitor(1,2); NG7monitor];
	endif
	n = length(NG7monitor);
	if NG7monitor(n,1) < 1e100
	  NG7monitor = [NG7monitor; 1e100, NG7monitor(n,2)];
	endif
    }
    set ::NG7_monitor_calibration_loaded 1
}

# Load contents of id(file) into x_id, y_id, dy_id
# Set id(xlab) and id(ylab) as appropriate
proc NG7load {id} {
    upvar #0 $id rec

    if ![icp_load $id] { return 0 }

    # If column S1 is not stored in the datafile because the slits
    # are fixed, we need to set it to a column which is the value
    # of motor 1.  
    # XXX FIXME XXX Similarly for S2, S3, S4.
    # XXX FIXME XXX Sushil says no slit scans for NG7
    if { ![vector_exists ::S1_$id] } {
	lappend rec(col) S1
	vector create ::S1_${id}([::y_$id length])
	set ::S1_${id}(:) $rec(start,S1)
    }

    # monitor calibration
    if { [vector_exists ::MON_$id]} {
	# XXX FIXME XXX if there are 0 monitor counts in a bin for some 
	# reason then this section will fail.  Find some way to make it
	# fail cleanly.

	load_NG7_monitor_calibration
	# for fixed Qz, use the Qz motor start position
	# for moving Qz
	if { ![vector_exists ::QZ_$id] } {
	    octave eval Qz=abs($rec(start,Qz))
	} else {
	    ::QZ_$id expr abs(::QZ_$id)
	    octave send ::QZ_$id Qz
	}

	# from Qz and file header, compute monitor time
	# XXX FIXME XXX verify that this is correct
	octave eval "seconds = $rec(prf)*$rec(mon) + \
		+ $rec(prf)*$rec(Mon1)*exp(log(abs(Qz))*$rec(Exp))"

	# convert monitor counts and monitor time to monitor rate
	# XXX FIXME XXX what to do with 0 monitor counts
 	octave send ::MON_$id monitors
	octave eval {
	    dmonitors = sqrt(monitors);
	    rate = monitors./seconds;
	    correction = interp1(NG7monitor(:,1), NG7monitor(:,2), rate);
	    monitors = monitors .* correction;
	    dmonitors = dmonitors .* correction;
	    monitors(monitors==0) = 1;
	}

	if { $rec(psd) } {
	    octave eval { 
	        monitors = monitors * ones(1,columns(psd));
		dmonitors = dmonitors * ones(1,columns(psd));
		psderr = sqrt ( (psderr./monitors) .^ 2 + ...
				(psd.*dmonitors./monitors.^2) .^ 2 );
		psd = psd ./ monitors;
	    }
	    vector create ::psd_$id ::psderr_$id
	    octave recv psd_$id psd
	    octave recv psderr_$id psderr
	} else {
	    vector create ::monitors_$id ::dmonitors_$id
	    octave recv monitors_$id monitors
	    octave recv dmonitors_$id dmonitors
	    octave sync
	    # XXX FIXME XXX what's the error on the monnl interpolation?
	    ::dy_$id expr "sqrt((::dy_$id/::monitors_$id)^2 + \
		(::y_$id*::dmonitors_$id/::monitors_$id^2)^2)"
	    ::y_$id expr "::y_$id/::monitors_$id"
	}
    } else {
	message "$rec(file) has no monitor counts"
    }

    switch $rec(type) {
	rock {
	    ::13_$id dup ::x_$id
	    set rec(Qrockbar) $rec(start,Qz)
	    set rec(xlab) "Qx (motor 13 units)"
	}
	spec {
	    ::QZ_$id dup ::x_$id
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	    set rec(slit) S1_$id
	}
	slit {
	    ::S1_$id dup ::x_$id
	    set rec(xlab) "slit opening (motor S1 units)"
	}
	height {
	    ::12_$id dup ::x_$id
	    set rec(xlab) "height (motor 12 units)"
	}
	back {
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	    ::QZ_$id dup ::x_$id
	}
	default { default_x $id }
    }
    set rec(ylab) "Reflectivity"

    return 1
}



proc XRAYmark {file} {
    # loadhead is a naughty function: it defines "rec", "m*" and "header2" in
    # our scope. If there is an error it causes us to return.
    set id [loadhead $file]
    upvar #0 $id rec
    set rec(load) XRAYload

    # instrument specific initialization
    set rec(instrument) "XRAY"
    # parse2... parses the second set of fields into "rec".
    parse2ng1 $header2


    # based on motor movements, guess the type of the experiment
    if { ![info exists rec(start,3)] || ![info exists rec(start,4)] } {
	marktype ?
    } elseif { $fixed } {
	marktype time 0 [expr $rec(monitor)*$rec(pts)]
    } elseif { $rec(start,3) == 0.0 && $rec(stop,3) == 0.0 \
	    && $rec(start,4) == 0.0 && $rec(stop,4) == 0.0 } {
	# XXX FIXME XXX confirm no slitscan for XRay
	marktype ?
    } elseif { $rec(step,4) == 0.0 } {
	set rec(rockbar) [expr $rec(start,4)/2.0]
	marktype rock $rec(start,3) $rec(stop,3)
    } elseif { abs($rec(stop,4) - 2.0*$rec(stop,3)) < 1e-10 } {
	marktype spec $rec(start,4) $rec(stop,4)
    } elseif { abs($rec(step,4) - 2.0*$rec(step,3)) < 1e-10 } {
	# offset background
	set m [string index $::background_default 1]
	if { $rec(start,4) > 2.0*$rec(start,3) } {
	    marktype back $rec(start,4) $rec(stop,4) +
	} else {
	    marktype back $rec(start,4) $rec(stop,4) -
	}
	set ::background_basis($rec(dataset),$rec(instrument)) \
		$::background_default
    } else {
	# mark anything else as some sort of background for now
	marktype back $rec(start,4) $rec(stop,4)
    }
}

# XXX FIXME XXX we only need the motors to determine the file type
# and display the data range bar.  So we can delay parsing the header
# until later.  Later in this case is when we try [addrun matches] since
# that's when we need temperature and field.  When we actually load the
# data for graphing is when we will need other fields like monitor and
# comment.
proc NG1mark {file {index ""}} {
    # loadhead is a naughty function: it defines "rec", "m*" and "header2" in
    # our scope. If there is an error it causes us to return.
    set id [loadhead $file]
    upvar #0 $id rec
    set rec(load) NG1load
    # fixup comment string from polarized data
    set offset [string first "F1: O" $rec(comment)]
    if { $offset > 0 } {
        set rec(comment) [string trim [string range $rec(comment) 0 [incr offset -1]]]
    }

    # instrument specific initialization
    if { ![string equal $index ""] } {
	set rec(instrument) "NG1p"
    } else {
	set rec(instrument) "NG1"
    }
    # parse2... parses the second set of fields into "rec".
    parse2ng1 $header2

    # based on motor movements, guess the type of the experiment
    if { ![info exists rec(start,1)] || ![info exists rec(start,3)] \
	    || ![info exists rec(start,4)] } {
	marktype ? 0 0 $index
    } elseif { $rec(start,3) == 0.0 && $rec(stop,3) == 0.0 \
	    && $rec(start,4) == 0.0 && $rec(stop,4) == 0.0 } {
	marktype slit $rec(start,1) $rec(stop,1) $index
    } elseif { $fixed } {
	marktype time 0 [expr $rec(monitor)*$rec(pts)] $index
    } else {
	# XXX FIXME XXX check if still using slit constraints in run_matches
	if { $rec(start,3) == $rec(stop,3) } {
	    # XXX FIXME XXX why not use slits when motor 3 is fixed?
	    set rec(slits) {}
	} else {
	    set rec(slits) { 1 2 5 6 }
	}

	if { $rec(step,4) == 0.0 } {
	    set rec(rockbar) [expr $rec(start,4)/2.0]
	    marktype rock $rec(start,3) $rec(stop,3) $index
        } elseif { $rec(step,3) == 0.0 } {
            set rec(rockbar) [expr -2*$rec(start,3)]
            marktype rock3 [expr 0-$rec(stop,4)] [expr 0-$rec(start,4)] $index
	} elseif { abs($rec(stop,4) - 2.0*$rec(stop,3)) < 1e-10 } {
	    marktype spec $rec(start,3) $rec(stop,3) $index
	} else {
	    # use default background basis
	    set m [string index $::background_default 1]
	    if { $rec(stop,4) > 2.0*$rec(stop,3) } {
		marktype back $rec(start,$m) $rec(stop,$m) $index+
	    } else {
		marktype back $rec(start,$m) $rec(stop,$m) $index-
	    }
	    set ::background_basis($rec(dataset),$rec(instrument)) \
		    $::background_default
	}
#	elseif { abs($rec(step,4) - 2.0*$rec(step,3)) < 1e-10 } {
#	    # offset background
#	    if { $rec(stop,4) > 2.0*$rec(stop,3) } {
#		marktype back $rec(start,4) $rec(stop,4) $index+
#	    } else {
#		marktype back $rec(start,4) $rec(stop,4) $index-
#	    }
#	} else {
#	    # mark anything else as some sort of background for now
#	    marktype back $rec(start,4) $rec(stop,4) $index
#	}
    }

}

proc NG7mark {file} {
    # loadhead is a naughty function: it defines "rec", "m*" and "header2" in
    # our scope. If there is an error it causes us to return.
    set id [loadhead $file]
    upvar #0 $id rec
    set rec(load) NG7load

    # instrument specific initialization
    set rec(instrument) "NG7"
    # parse2... parses the second set of fields into "rec".
    parse2ng7 $header2

    # based on motor movements, guess the type of the experiment
    if { ![info exists rec(start,Qz)] || ![info exists rec(start,S1)] } {
	marktype ?
    } elseif { $fixed } {
	# XXX FIXME XXX confirm time range
	marktype time 0 [expr $rec(mon)*$rec(prf)*$rec(pts)]
    } elseif { [info exists rec(start,13)] && $rec(step,13)!=0 } {
	if { $rec(start,Qz) == $rec(stop,Qz) } {
	    set rec(rockbar) $rec(start,Qz)
	    marktype rock $rec(start,13) $rec(stop,13)
	} else {
	    if { $rec(step,13) > 0 } {
		marktype back $rec(start,Qz) $rec(stop,Qz) +
	    } else {
		marktype back $rec(start,Qz) $rec(stop,Qz) -
	    }
	}
    } elseif { [info exists rec(start,12)] } {
	marktype height $rec(start,12) $rec(stop,12)

    } elseif { [info exists rec(start,S1)] } {
	if { $rec(start,Qz) != 0.0 && $rec(stop,Qz) != 0.0 } {
	    marktype spec $rec(start,Qz) $rec(stop,Qz)
	} else {
	    marktype slit $rec(start,S1) $rec(stop,S1)
	}
    } else {
	marktype ?
    }
}

array set ::typelabel { \
	slit "Slit scan" back "Background" \
	spec "Specular" rock "Rocking curve" \
	? "Unknown" height "Height scan" \
	time "Time evolution" other "Processed" \
    }

proc typelabel { type } {
    if { [info exists ::typelabel(type)] } {
	return $::typelabel(type)
    } else {
	return $type
    }
}

proc setdirectory { args } {
    # if no directory is given, ask for a new one in the parent
    # XXX FIXME XXX pwd/cd need to handle symbolic links reasonably
    if { [llength $args] == 0 } {
	set pattern [file join [pwd] *]
    } else {
	set pattern [lindex $args 0]
    }

    # if currently loading a directory, abort before loading the new one
    if { [winfo exists .loading ] } {
	# Can't abort directly, so instead signal an abort as if the
	# user pressed the stop button, and check back every 50 ms until
	# the abortion is complete.
	set ::loading_abort 1
	after 50 [list setdirectory $pattern ]
	return
    }

    # clear the old data
    addrun clear
    .tree delete [.tree nodes root]
    clear_set
    .filename conf -text ""
    text_clear .text
    clear_graph

    # set up a progress bar so that the user knows what percentage of
    # the files in the tree have been processed.
    set ::loading_text "Categorizing files..."
    set ::loading_abort 0
    set ::loading_progress 0
    ProgressDlg .loading -textvariable ::loading_text -stop Stop \
	    -variable ::loading_progress -maximum 100 \
	    -command { set ::loading_abort 1 ; set ::loading_text "Stop..." }
#   grab release .loading ;# allow user interaction while loading

    # set steps between progress bar updates based on number of files
    set files [lsort -dictionary [glob -nocomplain $pattern]]
    set n [llength $files]
    if { 0 < $n && $n <= 100 } {
	.loading configure -maximum $n
	set step 1
    } else {
	set step [expr $n/100.0]
    }
    update idletasks

    # process all the files
    set count 0
    set next 0
    if { [ catch {
	set others {}
	foreach f $files {
	    if { [incr count] >= $next } {
		incr ::loading_progress
		update
		set next [expr $next + $step]
		if { $::loading_abort } { break }
	    }
	    if [file isdirectory $f] continue
	    switch [string tolower [file extension $f]] {
		.na1 { NG1mark $f A }
		.nb1 { NG1mark $f B }
		.nc1 { NG1mark $f C }
		.nd1 { NG1mark $f D }
		.ng1 { NG1mark $f }
		.xr0 { XRAYmark $f }
		.ng7 { NG7mark $f }
		default { lappend others $f }
	    }
	}
    } msg ] } {
	tk_messageBox -message "Died with $msg\nwhile loading $f"
    }

    # Delay marking others so that we know what datasets are available
    # We want to try to match the 'other' to the dataset it may have
    # come from, but we can't do that without knowing the datasets
    foreach f $others { markother $f }

    # display the tree
    set ::loading_text "Building tree..."
    update
    foreach dataset [dataset_list] {
	.tree insert end root $dataset -open 0 -data dataset \
		-text "[clock format $::dataset($dataset) -format "%Y-%m-%d"]  $dataset"
	foreach gid [group_list $dataset] {
	    foreach { setname instrument type } [split $gid ","] {}
	    # Indicate the basis for background offsets in the section header.
	    # Remember which section headers have the indicator so that we
	    # toggle it between A3 and A4.
	    set bgbasis {}
	    if {[string equal $type back]} {
		if {[info exists ::background_basis($dataset,$instrument)]} {
		    set bgbasis " Q($::background_basis($dataset,$instrument))"
		    set ::background_basis_nodes($gid) $dataset,$instrument
		}
	    }
	    .tree insert end $dataset $gid -data group\
		-text "$instrument [typelabel $type]$bgbasis" -open 0
	    foreach id $::group($gid) {
		upvar #0 $id rec
		.tree insert end $gid $id -text $rec(run)$rec(index) -image $::image(clear) -data record
	    }
	}
    }

    # all done --- remove the progress dialog
    destroy .loading

    set first [lindex [.tree nodes root] 0]
    if { [string equal $first ""] } {
	choose_dataset setdirectory
    } else {
	# unhide the main window
	focus .tree
	.tree itemconfigure $first -open 1
	.tree selection set [lindex [.tree nodes $first] 0]
	set sets [.tree nodes $first]
	if { [llength $sets] == 1 } { .tree itemconfigure $sets -open 1 }
    }


}

init_selector

# XXX FIXME XXX shouldn't require the reduce window just for looking at
# a few data files
reduce_init

# ---------------------------------------------------------------------------
#  Command Tree::_draw_node
#  *** This is modified from BWidget's Tree::_draw_node ***
#  Modified to call the user-supplied decorate_node after the node is
#  drawn so that the user can add their own canvas decorations beside
#  the node:
#
#  	proc decorate_node { node canvas x0 y0 x1 y1 }
#
#  Note that bounding box is just for the node text and not any associated
#  window or image.  The window or image, if it exists, starts at x0-padx.
#
#  If you want your decorations to respond to the bindImage script, then
#  the first three tags must be TreeItemSentinal img i:$node.  E.g.,
#    $canvas create rect [expr $x1 + 3] $y0 [expr $x1 + 10] $y1 \
#         -fill black -tags "TreeItemSentinal img i:$node"
#
#  Note that tree.tcl must already be loaded before you can override the
#  _draw_node command.  The easiest way to do this is to create the tree
#  before this routine and insert the first nodes after.
# ---------------------------------------------------------------------------
proc ::Tree::_draw_node { path node x0 y0 deltax deltay padx showlines } {
    global   env
    variable $path
    upvar 0  $path data

    set x1 [expr {$x0+$deltax+5}]
    set y1 $y0
    if { $showlines } {
        $path.c create line $x0 $y0 $x1 $y0 \
            -fill    [Widget::getoption $path -linesfill]   \
            -stipple [Widget::getoption $path -linestipple] \
            -tags    line
    }
    $path.c create text [expr {$x1+$padx}] $y0 \
        -text   [Widget::getoption $path.$node -text] \
        -fill   [Widget::getoption $path.$node -fill] \
        -font   [Widget::getoption $path.$node -font] \
        -anchor w \
        -tags   "TreeItemSentinal node n:$node"
    set len [expr {[llength $data($node)] > 1}]
    set dc  [Widget::getoption $path.$node -drawcross]
    set exp [Widget::getoption $path.$node -open]

    if { $len && $exp } {
        set y1 [_draw_subnodes $path [lrange $data($node) 1 end] \
                    [expr {$x0+$deltax}] $y0 $deltax $deltay $padx $showlines]
    }

    if { [string compare $dc "never"] && ($len || ![string compare $dc "allways"]) } {
        if { $exp } {
            set bmp [file join $::BWIDGET::LIBRARY "images" "minus.xbm"]
        } else {
            set bmp [file join $::BWIDGET::LIBRARY "images" "plus.xbm"]
        }
        $path.c create bitmap $x0 $y0 \
            -bitmap     @$bmp \
            -background [$path.c cget -background] \
            -foreground [Widget::getoption $path -linesfill] \
            -tags       "cross c:$node" -anchor c
    }

    if { [set win [Widget::getoption $path.$node -window]] != "" } {
        $path.c create window $x1 $y0 -window $win -anchor w \
		-tags "TreeItemSentinal win i:$node"
    } elseif { [set img [Widget::getoption $path.$node -image]] != "" } {
        $path.c create image $x1 $y0 -image $img -anchor w \
		-tags "TreeItemSentinal img i:$node"
    }
    eval "decorate_node $node $path.c [$path.c bbox n:$node]"
    return $y1
}

# load the initial directory (as set by the command line arguments if any)
setdirectory $pattern


# rec filename
#   finds the record associated with filename and binds it to rec
#
# This is meant to be user callable from the tcl console.  It is never
# called by the rest of the application.  Note that this implementation
# is very inefficient since it searches the whole array every time.  A
# better strategy if it is needed in a loop is to first build an index
# mapping files to records and use that index in the loop.
proc rec { file } {
    foreach r [info var ::recR*] {
	if [string equal [file tail [set ${r}(file)]] f524b074.na1] {
	    upvar #0 $r ::rec
	    return [string range $r 2 end]
	}
    }
    return {}
}

# load user extensions
proc app_source { f } {
    if { [file exists $f] } {
        if { [catch { uplevel #0 [list source $f] } msg] } {
           tk_messageBox -icon error -msg "Error sourcing $f:\n$msg" -type ok
        }
    }
}
app_source [file join $::HOME .reflred.tcl]
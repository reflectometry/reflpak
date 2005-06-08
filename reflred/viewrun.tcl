package require Tk
package require BLT
namespace import blt::graph blt::vector blt::hiertable
package require Tktable
package require BWidget
package require tkcon
package require ncnrlib
package require octave

if { ![info exists ::app_version] } {
    set ::app_version "[clock format [clock seconds] -format %Y%m%d]-CVS"
}

register_icp
register_uxd
register_reduced

help $::VIEWRUN_HOME reflred help
wm protocol . WM_DELETE_WINDOW { exit }
# XXX FIXME XXX getting icons to work properly for unix will require
# changes to the Tk core
catch { wm iconbitmap . -default [file join $::VIEWRUN_HOME red.ico] }

set ::title Reflred
    
# XXX FIXME XXX how can I make this automatic?
set OCTAVE_SUPPORT_FILES { 
    psdslice reduce reduce_part run_invscale
    run_div run_include run_interp run_poisson_avg 
    run_scale run_sub run_tol run_trunc
    plotrunop runlog run_send run_send_pol fitslits polcor
    common_values inputname polyconf qlfit wsolve
    confidence qlconf wpolyfit interp1err
}

# XXX FIXME XXX fix blt::busy problem with 8.4
if { [string equal $::tcl_version 8.4] } {
    rename blt::busy {}
    proc blt::busy {args} {}
}

# Delay starting octave as long as possible
rename octave octave_orig
proc octave {args} {
    rename octave {}
    rename octave_orig octave
    restart_octave
    eval octave $args
}

# process command line args, if any
if { [ string match $argv "-h" ] } {
    puts "usage: $argv0 \[data directory]"
    exit
}
if { $argc == 0 } {
    set pattern {{}}
} else {
    set pattern $argv
}

# useful constants
set ::log10 [expr {log(10.)}]
set ::pitimes16 [expr {64*atan(1.)}]
set ::pitimes4 [expr {16.*atan(1.)}]
set ::pitimes2 [expr {8.*atan(1.)}]
set ::piover360 [ expr {atan(1.)/90.}]
set ::piover180 [ expr {atan(1.)/45.}]
proc a3toQz {a3 lambda} {
    return "$::pitimes4*sin($a3*$::piover180) / $lambda"
}
proc a4toQz {a4 lambda} {
    return "$::pitimes4*sin($a4*$::piover360) / $lambda"
}

load_resources $::VIEWRUN_HOME tkviewrun

# XXX FIXME XXX turn these into resources
set ::logaddrun 0
set ::erraddrun y
set ::background_default [option get . backgroundBasis BackgroundBasis]

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
    set ::image(new) [image create photo]
    $::image(new) put [string map { 0 "white " 1 "black " } $box9]
    set ::image(clear) [image create photo]
    $::image(clear) put [string map { 0 "#ccaeae " 1 "black " } $box9]
    set ::image(select) [image create photo]
    $::image(select) put [string map { 0 "red " 1 "black " } $box9]
}
init_tree_select_images
rename init_tree_select_images {}

# draw the selector window
proc init_selector { } {
    menu .menu
    . config -menu .menu
    menu .menu.file
    .menu add cascade -underline 0 -label File -menu .menu.file
    .menu.file add command -label "Data..." -command { choose_dataset setdirectory }
    .menu.file add command -underline 0 -label "Quit" -command { exit }
    .menu add command -label "Reduce..." -command { reduce_show }
    .menu add command -label "Attenuators..." -command { atten_table }
    # XXX FIXME XXX want menu options for setting Xray/Neutron wavelength
    # XXX FIXME XXX some users want separate scan directory and fit directory

    menu .menu.transform
    .menu add cascade -label Transform -menu .menu.transform
    .menu.transform add command -label "Q -> |Q|" -command { set_absolute_all }

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
    .menu.options add radiobutton -label "Show Temperature" \
	-variable ::graph_scaling -value "Temperature" \
	-command { atten_set $::addrun }
    .menu.options add radiobutton -label "Q^4 scaling" \
	-variable ::graph_scaling -value "Q4" \
	-command { atten_set $::addrun }
    .menu.options add radiobutton -label "Fresnel scaling" \
	-variable ::graph_scaling -value "Fresnel" \
	-command { atten_set $::addrun }
    .menu.options add radiobutton -label "Unscaled" \
	-variable ::graph_scaling -value "none" \
	-command { atten_set $::addrun }
    set ::graph_scaling none
    set ::Q4_cutoff 1e-2
    # From Alan Munter's Neutron SLD calculator for Si at 2.33 g/cm^3
    set ::Fresnel_rho Si
    set ::Fresnel_Qcsq [expr {$::pitimes16*2.07e-6}]
    .menu.options add separator
    .menu.options add command -label "Restart octave" -command restart_octave
    .menu.options add command -label "Tcl console" -command { tkcon show }
    helpmenu .menu windows

    PanedWindow .treebydata -side top
    set treepane [.treebydata add -weight 1 -minsize 20]
    set datapane [.treebydata add -weight 5 -minsize 20]
    sashconf .treebydata

    PanedWindow $datapane.filebygraph -side left
    set filepane [$datapane.filebygraph add -weight 1 -minsize 10]
    set graphpane [$datapane.filebygraph add -weight 5 -minsize 20]
    sashconf $datapane.filebygraph


    # tree to hold the list of runs
    Tree .tree -selectcommand view_file -padx 1
    .tree configure -width [option get .tree width Width]
    pack [scroll .tree] -side left -in $treepane -fill both -expand yes

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
    pack [scroll .text] -side top -in $filepane -fill both -expand yes

    graph .graph
#    vector create ::x_data ::y_data
#    .graph element create data -xdata ::x_data -ydata ::y_data -pixels 3 -label ""
    .graph marker create text -name rocklab -coords { 0 -Inf }
    .graph marker create line -name rockbar -coords { 0 -Inf 0 Inf }
    .graph marker create text -name date -coords {Inf Inf} -anchor ne -under 1
    .graph axis conf y -title "Counts" -logscale $::logaddrun

    .graph pen create excludePoint

    set ::colorlist [option get .graph lineColors LineColors]

    # put graph coordinates into message box
    bind .graph <Leave> { message "" }
    bind .graph <Motion> { graph_motion %W %x %y }

    # add graph controls
    active_graph .graph
    active_axis .graph y
    active_legend .graph
    
    .graph.menu add separator
    .graph.menu add command -label Exclude \
        -command { exclude_point [active_graph .graph element] [active_graph .graph index] }

    # buttons to toggle polarization states
    # XXX FIXME XXX these should only appear for polarized data
    pol_toggle_init .graph

    # click with middle button to exclude a value
    bind .graph <2> { graph_exclude %W %x %y }

    frame .b
    if 0 { # suppress Align until it is robust
	button .b.scale -text "Align" -command { addrun align }
	pack .b.scale -side left -anchor w
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
    wm deiconify .
#    set geometry [option get . geometry Geometry]
    set geometry 620x420
    if { ![string equal $geometry ""] } { wm geometry . $geometry }

#   # Maximize the window on opening; this doesn't quite work on X since
#   # it resizes the interior not the frame, and some wm's don't catch the
#   # oversizing.  Use [wm frame .] to get the frame
#   if { [catch { wm state . zoomed }] } {
#	wm geometry [wm frame .] [join [wm maxsize .] x]
#   }

    # After wm geometry commands, use wm positionfrom/sizefrom program
    # so that the wm doesn't think these came direct from the user.
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

# Polarization cross-section toggling

bind pol_toggle <<Elements>> { pol_toggle_enable %W }

proc pol_toggle_init {w} {
    frame $w.toggle
    foreach {n t} {a A b B c C d D} {
	button $w.toggle.$n -text $t -padx 2p -pady 1p \
	    -command [list pol_toggle $w $n]
	pack $w.toggle.$n -side left
    }
    bindtags $w [linsert [bindtags $w] 0 pol_toggle]
}

proc pol_toggle_enable {w} {
    set show 0
    foreach el [$w elem names *] {
	if { [string match {*[ABCD]} [$w elem cget $el -label]] } {
	    set show 1
	    break
	}
    }
    if { $show} {
	place $w.toggle -relx 1.0 -rely 1.0 -anchor se
    } else {
	place forget $w.toggle
    }
}

proc pol_toggle {w n} { 
    switch -- $n {
	a { set pattern *A }
	b { set pattern *B }
	c { set pattern *C }
	d { set pattern *D }
    }
    set state 0
    foreach el [$w elem names *] { 
	if {[string match $pattern [$w elem cget $el -label]] \
		&& [legend_hidden $w $el]} { 
	    set state 1; 
	    break 
	}
    }
    foreach el [$w elem names *] {
	if {[string match $pattern [$w elem cget $el -label]]} { 
	    legend_set $w $el $state 
	}
    }
    if {$state} {
	$w.toggle.$n conf -relief raised
    } else {
	$w.toggle.$n conf -relief ridge
    }
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
	set ptx [fix $where(x)]
	# XXX FIXME XXX eliminate temperature/Q^4 hacks
	switch -- $::graph_scaling {
	    Q4 { set y [Q4_unscale_point $where(x) $where(y)] }
	    Fresnel { set y [Fresnel_unscale_point $where(x) $where(y)] }
	    default { set y $where(y) }
	}
	set pty [fix $y {} {} 5]
	if { [info exists ::xth_$where(name)] } {
	    set theta [fix [set ::xth_$where(name)($where(index))]]
	    message "$ptid  ($theta $::symbol(degree), $ptx A$::symbol(inverse)) $pty"
	} else {
	    message "$ptid  $ptx, $pty"
	}
    } else {
	message
    }
}

proc exclude_point { id index } {
    if { ![string match rec* $id] } { return }
    
    # construct an index vector if needed
    set vec ::idx_$id
    if { ![vector_exists $vec] } {
        vector create $vec
        $vec expr 1+0*::x_$id
        # XXX FIXME XXX do we have to leak info about the
        # name of the graph widget here?
        catch { .graph element conf $id -weight $vec -styles { {excludePoint -0.5 0.5} } }
    }
    # negate the particular index
    set ${vec}($index) [expr 1.0 - [set ${vec}($index)]]
}

proc graph_exclude { w x y } {
    # Find the data record and exclude the point
    $w element closest $x $y where -halo 1i
    if { [info exists where(x)] } {
        exclude_point $where(name) $where(index)
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
}
proc disp x { 
    octave eval { retval='\n' }
    octave eval "retval=$x"
    octave eval { send(sprintf('set ::ans {%s}',disp(retval))) }
    vwait ::ans 
    return [string range $::ans 0 end-1]
}

proc write_data { fid data {pol {}} {log 0} } {

    if { $log } {
	puts $fid "# columns x logy dlogy"
	foreach x [set ${data}_x${pol}(:)] \
		y [set ${data}_y${pol}(:)] \
		dy [set ${data}_dy${pol}(:)] {
#	    puts "writing $x $y $dy"
	    if { $y <= $dy/1000. } {
		# XXX FIXME XXX can dy be <= 0?
		if { abs($y) <= $dy/1000. } {
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
	foreach x [set ${data}_x${pol}(:)] \
		y [set ${data}_y${pol}(:)] \
		dy [set ${data}_dy${pol}(:)] {
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
    set name "$rec(dataset)-$rec(run)$rec(index)"
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

    # notify application that graph elements have changed
    event generate .graph <<Elements>>
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
    addrun add $runs
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
    tableentry::reset .attenuator.t
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
    pack [vscroll .attenuator.t] -fill both -expand yes

    if 0 { # suppress Align until it is robust
	frame .attenuator.b
	button .attenuator.b.align -text "Align" -command { addrun align }
	button .attenuator.b.unalign -text "Revert" -command { addrun unalign }
	pack .attenuator.b.align .attenuator.b.unalign -side left -anchor w
	grid .attenuator.b
    }

    # XXX FIXME XXX want a combo box here
    tableentry .attenuator.t { if { %i } { atten_update %r %c %S } else { set ::atten_table(%r,%c) } }
    atten_table_reset
}

proc atten_update { row col val } {
#    ptrace
    if {![string is double $val] || $val < 0} {
        message "expected non-negative scale factor"
        return 0
    } elseif {$val < 0} {
	message "must be non-negative"
        return 0
    }

    # the new value is good so save it in the appropriate record
    set ::atten_table($row,$col) $val
    # attenuator.t clear cache
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
    return 1
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
	    set ::x_seq($j) [expr ($::x_seq($i)+$::x_seq($j))/2.];
	    ## error-weighted average of y1 and y2 -> y1
	    set si [expr 1./($::dy_seq($i)*$::dy_seq($i))]
	    set sj [expr 1./($::dy_seq($j)*$::dy_seq($j))]
	    set w [expr $si + $sj]
	    set inerr "$::dy_seq($i) $::dy_seq($j)"
	    if { $w == 0.0 } {
		puts "dyi=$::dy_seq($i), dyj=$::dy_seq($j), w=$w"
	    }
	    set ::y_seq($j) [expr double($::y_seq($i)*$si + $::y_seq($j)*$sj)/$w]
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
	set rec(k) [expr double($y1)/$y2]
	set p [expr double($dy1)/$y2]
	set q [expr (double($y1)/$y2)*(double($dy2)/$y2)]
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
	set k [expr double($y2)/$y1]
	set p [expr double($dy2)/$y1]
	set q [expr (double($y2)/$y1)*(double($dy1)/$y1)]
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

proc Q4_scale_vector { x y dy } {
    vector create S
    S expr "(abs($x)<=$::Q4_cutoff)*$::Q4_cutoff + (abs($x)>$::Q4_cutoff)*$x"
    S expr "(S/$::Q4_cutoff)^4"
    $y expr "$y*S"
    $dy expr "$dy*S"
}

proc Q4_unscale_point {x args} {
    if {abs($x) <= $::Q4_cutoff} { set x $::Q4_cutoff }
    set S [expr {pow(abs($x)/$::Q4_cutoff,4)}]
    set ret {}
    foreach y $args { lappend ret [expr {$y / $S}] }
    return $ret
}

proc Fresnel {Q} {
    set Qsq [expr {$Q*$Q}]
    if { $Q < 0. } {
	if { $Qsq <= -$::Fresnel_Qcsq } {
	    set F 1.
	} else {
	    set F [expr {sqrt($::Fresnel_Qcsq - $Qsq)}]
	    set F [expr {($Q + $F)/($Q - $F)}]
	}
    } else { 
	if { $Qsq <= $::Fresnel_Qcsq } {
	    set F 1.
	} else {
	    set F [expr {sqrt($Qsq - $::Fresnel_Qcsq)}]
	    set F [expr {($Q - $F)/($Q + $F)}]
	}
    }
    return [expr {$F*$F}]
}

proc Fresnel_scale_vector { Qvec y dy } {
    set Flist {}
    foreach Q [set ${Qvec}(:)] { lappend Flist [Fresnel $Q] }
	
    vector create Fvec
    Fvec set $Flist
    $y expr "$y/Fvec"
    $dy expr "$dy/Fvec"
    vector destroy Fvec
}

proc Fresnel_unscale_point {Q args} {
    set F [Fresnel $Q]
    set ret {}
    foreach y $args { lappend ret [expr {$y * $F}] }
    return $ret
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

    # scale runs by Q^4 or by Fresnel reflectivity
    switch -- $::graph_scaling {
	Temperature {
	    # Ugly hack to show temperature
	    .graph axis conf y -title "Temperature"
	    foreach id $runs {
		::ky_$id delete :
		::kdy_$id delete :
		if { [vector_exists ::TEMP_$id] } { ::ky_$id expr "::TEMP_$id" }
	    }
	    foreach id $scans {
		::${id}_ghosty delete :
		::${id}_ghostdy delete :
	    }
	}

	Q4 {
	    .graph axis conf y -title "[.graph axis cget y -title] x Q^4"
	    foreach id $runs {
		Q4_scale_vector ::x_$id ::ky_$id ::kdy_$id 
	    }
	    foreach id $scans {
		Q4_scale_vector ::${id}_x ::${id}_ghosty ::${id}_ghostdy 
	    }
	}

	Fresnel {
	    .graph axis conf y -title "[.graph axis cget y -title] / Fresnel($::Fresnel_rho)"
	    foreach id $runs { 
		Fresnel_scale_vector ::x_$id ::ky_$id ::kdy_$id 
	    }
	    foreach id $scans { 
		Fresnel_scale_vector ::${id}_x ::${id}_ghosty ::${id}_ghostdy 
	    }	
	}
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
	set slope [expr double($rec(stop,$slit) - $rec(start,$slit))/($rec(stop,$Q)-$rec(start,$Q))]
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

# XXX FIXME XXX building an extension could be faster if we didn't
# start from scratch every time we added a new run to the extension.
# For now the speed seems adequate.

# Return true if the run extends the range covered by the list of runs.
# The range is extended if there are x values in the run which are not
# in the run list.  This will fill holes in the coverage of the run list.
proc run_extends { runlist run } {
    upvar #0 $run rec
    set start $rec(start)
    set stop $rec(stop)
    set progress 1
    while { $progress } {
	set remainder {}
	set progress 0
	foreach id $runlist {
	    upvar #0 $id rec
	    if { $start >= $rec(start) && $start < $rec(stop) } {
		set progress 1
		set start $rec(stop)
	    } elseif { $stop > $rec(start) && $stop <= $rec(stop) } {
		set progress 1
		set stop $rec(start)
	    } elseif { $start >= $rec(start) && $stop <= $rec(stop) } {
		lappend remainder $id
	    } else {
	    }
	}
	set runlist $remainder
    }
    return [expr {$start < $stop}]
}


# Return true if the run extends the range covered by the list of runs.
# The range is extended if there are x values in the run which are beyond
# the ends of the run list.  This will not fill holes in the coverage of
# the run list.
proc run_extends_total_range { runlist run } {
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
    graph_error	.graph $id -yerror ::kdy_$id
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
    graph_error .graph $id -yerror ::${id}_ghostdy
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

    if { [llength $::addrun] == 0 } { return }

    blt::busy hold . 

    # sort run list by index
    foreach id $::addrun {
	lappend runlist([set ::${id}(index)]) $id
    }

    # build indices as separate lines
    foreach index [lsort [array names runlist]] {
	set scanid [setscan $runlist($index)]
	lappend scanlist $scanid
	# XXX FIXME XXX I hate the automatic saving of intermediates, and
	# this is almost certainly the wrong place to do it.
	savescan $scanid
    }

    # clear the runs
    addrun clear

    # add the scans
    foreach scan $scanlist { addrun_addscan $scan }

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
	    atten_calc $::addrun
	    atten_set $::addrun
	    atten_table_reset
	}
	create {}
	element {}
	head { return [lindex $::addrun 0] }
	load {}
	accept {
	    addrun_accept
	    event generate .graph <<Elements>>
	    event generate .reduce.graph <<Elements>>
	    atten_table_reset
	}
	save {
	    addrun clear
	}
	clear {
	    if { [llength $::addrun] == 0 } {
		addrun_clearscan -all
	    } else {
		foreach id $::addrun { addrun_remove $id }
		atten_table_reset
	    }
	    event generate .graph <<Elements>>
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
	    foreach id [lindex $args 0] { addrun_add $id }
	    atten_table_reset
	    event generate .graph <<Elements>>
	}
	remove {
	    foreach id [lindex $args 0] { addrun_remove $id }
	    atten_table_reset
	    event generate .graph <<Elements>>
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

proc set_absolute {id} {
    if {[info exists ::x_$id]} { ::x_$id expr abs(::x_$id) }
    if {[info exists ::xth_$id]} { ::xth_$id expr abs(::xth_$id) }
}

proc set_absolute_all { } {
    foreach id $::addrun { set_absolute $id }
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
		set A3 [set ::${id}(A3)]
		if {[vector_exists ::x_$id]} {
		    $A3 dup ::xth_$id
		    ::x_$id expr [ a3toQz $A3 [set ::${id}(L)] ]
		}
	    }
	}
	A4 {
	    foreach id [.tree nodes $node] {
		set ::${id}(start) [set ::${id}(start,4)]
		set ::${id}(stop) [set ::${id}(stop,4)]
		set A4 [set ::${id}(A4)]
		if {[vector_exists ::x_$id]} {
		    ::xth_$id expr $A4/2.
		    ::x_$id expr [ a4toQz $A4 [set ::${id}(L)] ]
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
	addrun add $nodes
    }
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
    if { [info exists ::rec(view)] } {
	$::rec(view) $node .text
    } else {
	text_load .text $rec(file)
    }
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
    graph_error .graph data -yerror ::dy_data
    .graph element conf data -hide 0
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
	    .graph axis conf x -min [expr $Qbase - $range/10.]
	}
	if { $Qbase >= $max + $range } {
	    .graph axis conf x -max [expr $max + $range]
	} elseif { $Qbase < $max + $range && $Qbase >= $max } {
	    .graph axis conf x -max [expr $Qbase + $range/10.]
	}
    }
    update idletasks
}

## Show what portion of the total data range is used by a particular node.
## This is called by my hacked version of the BWidget Tree widget, which
## first draws the label for $node, then gives you the canvas widget $w and
## the bounding box {x0 y0 x1 y1} of the label on the canvas, and lets you
## add your own canvas annotations.  The tags used on the canvas items
## must be listed in the order given if the user is to click on your
## annotations to select the node.
proc decorate_node { node w bbox } {
    # make sure it is a leaf node
    if { [string equal [.tree itemcget $node -data] "record"] } {
	upvar #0 $node rec

	# determine range for the entire group
        set gid [.tree itemcget [ .tree parent $node ] -data]
	group_range $gid shift end

	# if no range, don't leave space for a range bar
	if { $end == $shift } {
	    set offset 12
	} else {
	    set offset 65
	}

	# draw the label
	foreach {x0 y0 x1 y1 } $bbox break
	$w create text [expr {$x0+$offset}] $y1 \
		-text   $rec(run)$rec(index) \
		-fill   [Widget::getoption .tree.$node -fill] \
		-font   [Widget::getoption .tree.$node -font] \
		-anchor sw \
		-tags   "TreeItemSentinal img i:$node"

	# if no bar (hence no space for bar) then we are done
	if { $end == $shift } { return }

	# Draw the bar and the active range within the bar
	set scale [expr {50./($end - $shift)}]
	set x1 [expr {$x0 + 12.} ]
	set y0 [expr {$y0 + 1.} ]
	set y1 [expr {$y1 - 1.} ]
	$w create rect $x1 $y0 [expr {$x1+50.}] $y1 \
		-fill $::qrange_fill \
		-outline $::qrange_outline \
		-width $::qrange_outlinewidth \
		-tags "TreeItemSentinal img i:$node"
	$w create rect \
	        [expr {($rec(start)-$shift)*$scale + $x1}] $y0 \
	        [expr {($rec(stop)-$shift)*$scale + $x1}] $y1 \
	        -fill $::qrange_color \
		-outline $::qrange_outline \
		-width $::qrange_outlinewidth \
		-tags "TreeItemSentinal img i:$node"

	# Draw Qx=0 or Qz=0 if it is visible in the group range
	if {[info exists rec(rockbar)]} {
	    # there is a rockbar, try to show Qx=0
	    set bar $rec(rockbar)
	} else {
	    # if no rockbar, try to show Qz=0
	    set bar 0
	}
	if { $bar >= $shift && $bar <= $end } {
	    set bar [expr {($bar-$shift)*$scale + $x1 - floor($::qrange_barwidth/2.)}]
	    $w create rect \
		    $bar [expr {$y0 + $::qrange_outlinewidth}] \
		    [expr {$bar + $::qrange_barwidth}] $y1 \
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

proc note_rec { id args } {
    if { [llength $args] } {
	lappend ::${id}(notes) $args
    } else {
	set ::${id}(notes) {}
    }
	
}

proc new_rec { file } {
    set id recR[incr ::rec_count]
    set ::${id}(id) $id
    set ::${id}(file) $file

    return $id
}

proc marktype {type {start 0} {stop 0} {index ""}} {
    upvar rec rec
    set root [file rootname $rec(file)]
#    set rec(run) [string range $root end-2 end] ;# 3 digit run number
#    set rec(dataset) [string range [file tail $root] 0 end-3] ;# run name
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
	foreach {start stop} $::grouprange($gid) break
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

    # avoid loading from a separate "thread" while this thread is loading
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

    # XXX FIXME XXX these should be post-loding operations, but loadreduced
    # jumps immediately to ghost mode.

    # define scaled vectors (atten_set sets their values according to the
    # scale factor and the current monitor)
    vector create ::ky_$id ::kdy_$id
    
    # set other fields
    set ::${id}(legend) "[set ::${id}(run)][set ::${id}(index)]"

    # call the type-specific loader
    if { [$rec(load) $id] } {
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
    # ptrace

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

proc setdirectory { pattern_set } {
    # if currently loading a directory, abort before loading the new one
    if { [winfo exists .loading ] } {
	# Can't abort directly, so instead signal an abort as if the
	# user pressed the stop button, and check back every 50 ms until
	# the abortion is complete.
	set ::loading_abort 1
	after 50 [list setdirectory $pattern_set ]
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

    # glob the patterns
    set files {}
    foreach p $pattern_set {
        # implicitly extend patterns as if they are prefixes
	set p [file normalize $p]
        if { [file isdirectory $p] } {
            set p [file join $p *]
        } else {
            set p "$p*"
        }
        set files [concat $files [glob -nocomplain $p]]
    }
    set files [lsort -dictionary $files]

    # Display data path in the window header.
    set p [file dirname [lindex $files 0]]
    catch { set p [file normalize $p] } ;# Tcl8.4 feature
    wm title . "$::title [tildesub $p]"

    # set steps between progress bar updates based on number of files
    set n [llength $files]
    if { 0 < $n && $n <= 100 } {
	.loading configure -maximum $n
	set step 1
    } else {
	set step [expr $n/100.]
    }
    update idletasks

    # process all the files
    set count 0
    set next 0
    set others {}
    foreach f $files {
	if { [incr count] >= $next } {
	    incr ::loading_progress
	    update
	    set next [expr {$next + $step}]
	    if { $::loading_abort } { break }
	}
	if [file isdirectory $f] continue
	set ext [string tolower [file extension $f]]
	if {[info exists ::extfn($ext)]} {
#	    $::extfn($ext) mark $f
	    if { [ catch { $::extfn($ext) mark $f } msg ] } {
		set ans [tk_messageBox -type okcancel -icon error \
			     -message "Error: $msg\nwhile loading $f"]
		if { [string equal $ans cancel] } { break }
	    }
	} else {
	    lappend others $f
	}
    }

    # Delay marking others so that we know what datasets are available
    # We want to try to match the 'other' to the dataset it may have
    # come from, but we can't do that without knowing the datasets
    foreach f $others {
	#markother $f
	if { [catch { markother $f } msg] } {
	    message $msg
	}
    }

    # display the tree
    set ::loading_text "Building tree..."
    set branch 0
    update
    foreach dataset [dataset_list] {
	set dataset_branch "dataset[incr branch]"
	.tree insert end root $dataset_branch -open 0 -data $dataset \
		-text "[clock format $::dataset($dataset) -format "%Y-%m-%d"]  $dataset"
	foreach gid [group_list $dataset] {
	    foreach { setname instrument type } [split $gid ","] {}
	    # Indicate the basis for background offsets in the section header.
	    # Remember which section headers have the indicator so that we
	    # toggle it between A3 and A4.
	    set group_branch "group[incr branch]"
	    set bgbasis {}
	    if {[string equal $type back]} {
		if {[info exists ::background_basis($dataset,$instrument)]} {
		    set bgbasis " Q($::background_basis($dataset,$instrument))"
		    set ::background_basis_nodes($group_branch) $dataset,$instrument
		}
	    }
	    .tree insert end $dataset_branch $group_branch -data $gid\
		-text "$instrument [typelabel $type]$bgbasis" -open 0
	    foreach id $::group($gid) {
		upvar #0 $id rec
		.tree insert end $group_branch $id -text {  } \
		    -image $::image(new) -data record
	    }
	}
    }

    # all done --- remove the progress dialog
    destroy .loading

    if { [llength [.tree nodes root]] == 0 } {
	choose_dataset setdirectory
    } else {
	# unhide the main window
	focus .tree
	set first [lindex [.tree nodes root] 0]
	.tree itemconfigure $first -open 1
	.tree selection set [lindex [.tree nodes $first] 0]
	set sets [.tree nodes $first]
	if { [llength $sets] == 1 } { .tree itemconfigure $sets -open 1 }
    }


}

init_selector

# ---------------------------------------------------------------------------
#  Command Tree::_draw_node
#  *** This is modified from BWidget's Tree::_draw_node ***
#  Modified to call the user-supplied decorate_node after the node is
#  drawn so that the user can add their own canvas decorations beside
#  the node:
#
#  	proc decorate_node { node canvas bbox }
#
#  where bbox is {x0 y0 x1 y1}.  Note that bounding box is just for 
#  the node text and not any associated window or image.  The window 
#  or image, if it exists, starts at x0-padx.
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
    decorate_node $node $path.c [$path.c bbox n:$node]
    return $y1
}


# rec filename
#   finds the record associated with filename and binds it to rec
#
# This is meant to be user callable from the tcl console.  It is never
# called by the rest of the application.  Note that this implementation
# is very inefficient since it searches the whole array every time.  A
# better strategy if it is needed in a loop is to first build an index
# mapping files to records and use that index in the loop.
proc rec { file } {
    foreach r [.graph elem names] {
	if [string match $file [.graph elem cget $r -label]] {
	    upvar #0 $r ::rec
	    return $r
	}
    }
    foreach r [info var ::recR*] {
	if [string match $file [file tail [set ${r}(file)]]] {
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
           tk_messageBox -icon error -message "Error sourcing $f:\n$msg" -type ok
        }
    }
}
app_source [file join [HOME] .reflred.tcl]

# load the initial directory (as set by the command line arguments if any)
setdirectory $pattern

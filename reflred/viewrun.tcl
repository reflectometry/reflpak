init_cmd { help $::VIEWRUN_HOME reflred help }

# XXX FIXME XXX fix blt::busy problem with 8.4
if { [string equal $::tcl_version 8.4] } {
    rename blt::busy {}
    proc blt::busy {args} {}
}

wm protocol . WM_DELETE_WINDOW { exit }
# XXX FIXME XXX getting icons to work properly for unix will require
# changes to the Tk core
catch { wm iconbitmap . -default [file join $::VIEWRUN_HOME red.ico] }

init_cmd {
    load_resources $::VIEWRUN_HOME tkviewrun
    set ::background_default [option get . backgroundBasis BackgroundBasis]
    # FIXME turn these into resources
    set ::logaddrun 0
    set ::erraddrun y
    set ::psdstyle fvector
}

# HELP internal
# Usage: init_tree_select_images
#
# Create icons for new, select and clear record.
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
init_cmd { 
    # On startup, create the images then clear the function.
    init_tree_select_images
    rename init_tree_select_images {} 
}

# HELP internal
# Usage: init_selector
#
# Draw the selector window
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
    .menu.options add separator
    .menu.options add command -label "Monitor..." -command { monitor_dialog }
    .menu.options add separator
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

    # XXX FIXME XXX This should be a property of the fitting program,
    # but our fitting programs don't yet handle it.
    .menu.options add separator
    .menu.options add checkbutton -label "Clip zeros in files" \
	-variable ::clip_data
    .menu.options add checkbutton -label "New PSD" \
	-variable ::psdstyle -onvalue fvector -offvalue octave
    set ::clip_data 0

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
    Tree .tree -selectcommand tree_select_node -padx 1
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
    pack [scroll .text -auto none] -side top -in $filepane -fill both -expand yes

    graph .graph
#    vector create ::x_data ::y_data
#    .graph element create data -xdata ::x_data -ydata ::y_data -pixels 3 -label ""
    .graph marker create text -name rocklab -coords { 0 -Inf }
    .graph marker create line -name rockbar -coords { 0 -Inf 0 Inf }
    .graph marker create text -name date -coords {Inf Inf} -anchor ne -under 1
    .graph axis conf y -title "Counts" -logscale $::logaddrun

    .graph pen create excludePoint

    set ::colorlist [option get .graph lineColors LineColors]

    # add graph controls
    active_graph .graph -motion addrun_point_info
    active_axis .graph y
    active_legend .graph
    
    .graph.menu add separator
    .graph.menu add command -label Exclude \
        -command { exclude_point .graph [active_graph .graph element] [active_graph .graph index] }

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
    label .message -relief ridge -anchor w
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

# HELP developer
# Usage: pol_toggle_init w
#
# Add support for polarization cross-section toggling to the graph.
proc pol_toggle_init {w} {
    frame $w.toggle
    foreach {n t} {a A b B c C d D} {
	button $w.toggle.$n -text $t -padx 2p -pady 1p \
	    -command [list pol_toggle $w $n]
	pack $w.toggle.$n -side left
    }
    bindtags $w [linsert [bindtags $w] 0 pol_toggle]
}
bind pol_toggle <<Elements>> { pol_toggle_enable %W }

# HELP internal
# Usage: pol_toggle_enable w
#
# Add A-B-C-D buttons to graph if any elements are polarization cross-sections.
# Callback from graph element add/delete event.
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

# HELP internal
# Usage: pol_toggle w n
#
# Toggle all elements of the given cross-section.
# Callback for the buttons for each cross-section.
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

# HELP internal
# Usage: addrun_point_info w x y name idx msg
#
# Show the coordinates of the nearest point.  Undo effects of graph scaling.
# Display counts, alpha and beta values if available.
# Callback from graph motion event.
proc addrun_point_info { w x y name idx msg } {
    # To undo the effects of Q4 and Fresnel scaling, need to regenerate
    # entire message from scratch
    set msg "[$w elem cget $name -label]:[expr {$idx+1}]"
    # XXX FIXME XXX eliminate temperature/Q^4 hacks
    set x [set [$w elem cget $name -xdata]($idx)]
    set y [set [$w elem cget $name -ydata]($idx)]
    switch -- $::graph_scaling {
	Q4 { set y [Q4_unscale_point $x $y] }
	Fresnel { set y [Fresnel_unscale_point $x $y] }
    }
    # display Q and normalized counts
    append msg " ([format %.4f $x], [fix $y {} {} 5])"
    # display raw counts
    if { [vector_exists ::counts_$name]} {
	append msg "  counts: [expr int([set ::counts_${name}($idx)])]"
    }
    # display angles to the nearest 0.0001 degree
    if { [vector_exists ::alpha_$name]} {
	append msg "  A: [expr {round([set ::alpha_${name}($idx)]/0.0001)*0.0001}]$::symbol(degree)"
    }
    if { [vector_exists ::beta_$name]} {
	append msg "  B: [expr {round([set ::beta_${name}($idx)]/0.0001)*0.0001}]$::symbol(degree)"
    }
    return $msg
}

# HELP internal
# Usage: exclude_point w id n
#
# Toggle the exclusion of point n in the given record.  Adjust the element
# to display exclusions if a new exclusion vector is created.
#
# FIXME simplify since all records are now assumed to have an associated
# index vector
proc exclude_point { w id index } {
    if { ![string match $::recpattern $id] } { return }
    
    # construct an index vector if needed
    set vec ::idx_$id
    if { ![vector_exists $vec] } {
        vector create $vec
        $vec expr 1+0*::x_$id
        catch { $w element conf $id -weight $vec -styles { {excludePoint -0.5 0.5} } }
    }
    # negate the particular index
    set ${vec}($index) [expr {1.0 - [set ${vec}($index)]}]
}

# HELP internal
# Usage: graph_exclude w x y
# 
# Exclude the point under the cursor.
# Callback for graph exclude event
proc graph_exclude { w x y } {
    # Find the data record and exclude the point
    $w element closest $x $y where -halo 1i
    if { [info exists where(x)] } {
        exclude_point $w $where(name) $where(index)
    } else {
        message -bell "No points under mouse"
    }
}


# HELP internal
# Usage: clearscan id
#
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
	foreach var [info vars ::$::scanpattern] { array unset $var }
	set var [vector names ::$::scanpattern]
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

proc atten_set { runs }  {

    # Ghost scans we have to deal with in addition to runs
    set scans [.graph elem names $::scanpattern]

    # Determine which monitor to use
    # XXX FIXME XXX Have to set the y-axis, etc.  Atten_set is NOT the 
    # place to do it!  Ideally it would be done in addrun_accept, and
    # be based on the scan containing the record which used to be the
    # head so that the monitor scaling doesn't change, but then we need
    # a way of propogating the monitor to atten_set.
    if [llength $runs] {
	foreach {norm monitor seconds} [monitor_value [lindex $runs 0]] break
	decorate_graph [lindex $runs 0]
    } elseif [llength $scans] {
	foreach {norm monitor seconds} [monitor_value [lindex $scans 0]] break
	decorate_graph [lindex $scans 0]
    } else {
	return
    }


    # scale runs by monitor
    foreach id $runs {
	upvar #0 $id rec

	monitor_norm $id
	# use $monitor if $rec(norm) is monitor
	# use $seconds if $rec(norm) is seconds
	set scale [set $rec(norm)]
	::kdy_$id expr "$scale*::dy_$id"
	::ky_$id expr "$scale*::y_$id"
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
	# use $monitor if $scanrec(norm) is monitor
	# use $seconds if $scanrec(norm) is seconds
	set scale [expr {[set $scanrec(norm)]/$scanrec(monitor)}]
	::${id}_ghosty expr "$scale*::${id}_y"
	::${id}_ghostdy expr "$scale*::${id}_dy"
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

    catch { 
	if { [info exists ::${id}(psdplot)] && $::psdstyle eq "fvector" } { 
	    reflplot::plot_window .newpsd
	    reflplot::plot2d add .newpsd.c $id
	} elseif { [set ::${id}(psd)] } { 
	    psd $id 
	}
    }

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
    if { [llength [.graph element names $::scanpattern]] == 0 } {
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
	set idlist [.graph element names $::scanpattern]
    }
    foreach id $idlist {
	catch { .graph element delete $id }
	catch { vector destroy ::${id}_ghosty ::${id}_ghostdy }
    }
}

# remove a record from the graph and free its associated data
init_cmd { set ::addrun {} } ;# start with nothing
proc addrun_remove { id } {
    # check first if the record has been added
    if { [lsearch $::addrun $id] < 0 } { return }

    # remove it from the graph
    catch { .graph element delete $id }

    # remove it from the list
    set ::addrun [ldelete $::addrun $id]

    catch { 
	if { [info exists ::${id}(psdplot)] } { 
	    reflplot::plot2d delete .newpsd.c $id
	}
    }

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
	upvar \#0 $id rec
	# FIXME: need to index by $rec(norm) as well
	lappend runlist($rec(index)) $id
    }

    # build indices as separate lines
    foreach index [lsort [array names runlist]] {
	set scanid [setscan $runlist($index)]
	lappend scanlist $scanid
	# XXX FIXME XXX I hate the automatic saving of intermediates, and
	# this is almost certainly the wrong place to do it.
	savescan $scanid
    }

    # add the scans
    foreach scan $scanlist { addrun_addscan $scan }

    # set the scale on the ghost scans
    atten_set {}

    blt::busy release .
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
	    addrun clear
	    atten_table_reset
	    event generate .graph <<Elements>>
	    event generate .reduce.graph <<Elements>>
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
	    blt::busy hold . 
	    foreach id [lindex $args 0] { addrun_add $id }
	    atten_table_reset
	    event generate .graph <<Elements>>
	    blt::busy release . 
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

proc toggle_background { node } {
    # update indicator in tree
    set newtext [string map {A3 A4 A4 A3} [.tree itemcget $node -text]]
    .tree itemconfigure $node -text $newtext

    # make sure new records use the new indicator
    set dataset $::background_basis_nodes($node)
    set basis [string map { A3 A4 A4 A3 } $::background_basis($dataset)]

    # Update existing records to use the new Q range (including records
    # currently displayed on the graph).
    set_background_basis $dataset $basis

    # Clear the cumulative range from the cache
    set gid [.tree itemcget $node -data]
    array unset ::grouprange $gid
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
	if {$::background_default ne $::background_basis($dataset)} {
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
	    if { $opt(-force) == 0 } {
		message -bell "$message --- use Shift-Click to override"
		return
	    } else {
		message $message
	    }
	}
	addrun add $nodes
    }
    atten_set $::addrun
}

proc decorate_graph { id } {
    upvar #0 $id rec
    .graph axis conf x -title $rec(xlab)
    .graph axis conf y -title $rec(ylab)
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

# HELP developer
# Usage: rec_clear id
#
# Clear the current record from the record viewer.
proc rec_clear {} {
    # clear the text
    .filename conf -text ""
    text_clear .text
}

# HELP developer
# Usage: rec_view id
#
# Show a record in the record viewer.
proc rec_view {id} {
    upvar #0 $id rec

    ## display the filename
    .filename conf -text "$rec(file) ($id)"

    ## display the file contents as text
    if { [info exists rec(view)] } {
	$rec(view) $id .text
    } else {
	text_load .text $rec(file)
    }
}

# HELP internal
# Usage: tree_select_node w node
#
# Callback for tree widget node selection.
proc tree_select_node {w node} {
    # show the data only if it is a leaf node
    if { ![string equal [$w itemcget $node -data] "record"] } {
	# clear the existing record
	rec_clear
    } else {
	# show the selected record and make it available from tkcon
	upvar #0 $node ::rec
	rec_view $node
    }
}


# HELP internal
# Usage: decorate_node node canvas bbox
#
# Show what portion of the total data range is used by a particular node.
# This is called by my hacked version of the BWidget Tree widget (see
# _draw_node function below), which first draws the label for the node, 
# then gives you the canvas widget and the bounding box {x0 y0 x1 y1} 
# of the label on the canvas, and lets you add your own canvas annotations.
# The tags used on the canvas items must be listed in the order given if 
# the user is to click on your annotations to select the node.
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

# HELP user
# Usage: tree_draw
#
# Redraw the tree with all records.  Do this after you mark a number of
# records by hand.
proc tree_draw {} {
    if {![winfo exists .tree]} { return }

    # Clear the tree
    tree_clear

    # display the tree
    .message conf -text "Building tree..."
    update idletasks
    set branch 0
    foreach dataset [dataset_list] {
	set dataset_branch "dataset[incr branch]"
	set date [clock format $::dataset($dataset) -format "%Y-%m-%d"]
	.tree insert end root $dataset_branch -open 0 -data $dataset \
	    -text "$date $dataset"
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
    .message conf -text ""
}

proc tree_clear {} {
    .tree delete [.tree nodes root]
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
    tree_clear
    rec_clear
    dataset_clear
    clear_graph

    # Scan file list
    mark_pattern $pattern_set

    # Display data path in the window header.
    set p [file normalize [file dirname [lindex $::datafiles 0]]]
    wm title . "$::title [tildesub $p]"
    update

    tree_draw

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

init_cmd { init_selector }

# ---------------------------------------------------------------------------
#  Command _draw_node
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
proc _draw_node { path node x0 y0 deltax deltay padx showlines } {
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
	if { [info exists ::BWIDGET::SHARE] } {
	    set bwidget_share $::BWIDGET::SHARE
	} else {
	    set bwidget_share $::BWIDGET::LIBRARY
	}
        if { $exp } {
            set bmp [file join $bwidget_share "images" "minus.xbm"]
        } else {
            set bmp [file join $bwidget_share "images" "plus.xbm"]
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

# FIXME Need to register replacement _draw_node with BWidget tree command, 
# but we can't do that until the tree code is actually loaded.  Find a better
# way to do this.
if { [info command ::Tree::_draw_node] ne "" } {
    # reloading viewrun, register new _draw_node
    rename ::Tree::_draw_node {}
    rename _draw_node ::Tree::_draw_node
}
init_cmd {
    # first pass, initial window already created by previous init_cmd
    rename ::Tree::_draw_node {}
    rename _draw_node ::Tree::_draw_node
}


# load user extensions
proc app_source { f } {
    if { [file exists $f] } {
        if { [catch { uplevel #0 [list source $f] } msg] } {
	    message -error "Error sourcing $f:\n$msg"
        }
    }
}

init_cmd { app_source [file join [HOME] .reflred.tcl] }
# Include peak integration in the main distribution
init_cmd { app_source [file join $::VIEWRUN_HOME peakint.tcl] }
init_cmd { setdirectory [initial_pattern] }

package provide reflplot 0.2

# first time through
if {![namespace exists reflplot]} {
    package require snit
    catch { package require BLT }
    package require ncnrlib
    package require meshplot
    package require keystate

}

namespace eval reflplot {

    variable pi_over_180 [expr {atan(1.)/45.}]
    variable transforms {QxQz TiTf TiTd AB slit pixel LTd}

namespace export plot2d
variable actions {new add delete transform center showall names redraw}
proc plot2d {action path args} {
    variable actions
    set id [lsearch $actions $action]
    if {$id < 0} {
	error "plot2d ?: should be one of $actions"
    }
    if {$id > 0} { findplot $path }
    eval [linsert $args 0 $action $path]
}

# ===== Helper functions which don't depend on plot =====
proc isTOF {} {
    upvar rec rec
    return [info exists rec(TOF)]
}

proc dtheta_edges {pixels pixelwidth distance centerpixel} {
  variable pi_over_180
  set edges {}
  for {set p 0} {$p <= $pixels} {incr p} {
    lappend edges [expr {atan2(($centerpixel-$p)*$pixelwidth, $distance) \
			     / $pi_over_180}]
  }
  return $edges
}

proc set_center_pixel {id {c {}}} {
    upvar \#0 $id rec
    # default to center of the detector
    if {[llength $c] == 0} { set c [expr {($rec(pixels)+1.)/2.}] }
    set rec(centerpixel) $c
    fvector rec(dtheta) \
	[dtheta_edges $rec(pixels) $rec(pixelwidth) $rec(distance) $c]
}

proc parse_data {id data} {
    upvar \#0 $id rec

    # convert data block to psd data
    fvector d $data

    # Get data block dimensions
    set n [expr {$rec(pixels)+$rec(Ncolumns)}]
    # Try to guess the number of points stored in the file.
    # This won't match the #Npoints value if the scan was aborted.
    set m [expr {[flength d]/$n}]
    if {$m != $rec(points)} {
	# XXX FIXME XXX better error reporting
	message "Expected $rec(points) scan points but found $m (columns=$rec(Ncolumns) pixels=$rec(pixels) values=[flength d])"
	set rec(points) $m
    }

    # Grab the columns
    set idx 0
    foreach c $rec(columns) {
	set rec(column,$c) [fextract $m $n d $idx]
	incr idx
    }
    set rec(psddata) [fextract $m $n d $rec(Ncolumns) $rec(pixels)]
    ferr rec(psddata) rec(psderr)
    set rec(psdraw) $rec(psddata)
}

proc normalize {id monitor} {
    upvar \#0 $id rec

    # normalize by monitor counts
    fdivide $rec(points) $rec(pixels) rec(psddata) rec(column,$monitor)
    fdivide $rec(points) $rec(pixels) rec(psderr) rec(column,$monitor)
}

proc set_axes {id theta twotheta slit1} {
    upvar \#0 $id rec

    # XXX FIXME XXX edges doesn't work for single pixel scans
    # need to set theta/twotheta range based on resolution
    if {[flength rec(column,$theta)] == 1} {
	set a [fvector rec(column,$theta)]
	set b [fvector rec(column,$twotheta)]
	set s [fvector rec(column,$slit1)]
	fvector rec(alpha) [list [expr {$a-0.01}] [expr {$a+0.01}]]
	fvector rec(beta) [list $b $b]
	fvector rec(slit1) [list [expr {$s-0.01}] [expr {$s+0.01}]]
    } else {
	fvector rec(alpha) [edges [fvector rec(column,$theta)] 0.01]
	fvector rec(beta) [edges [fvector rec(column,$twotheta)] 0.01]
	fvector rec(slit1) [edges [fvector rec(column,$slit1)] 0.001]
    }
}

# XXX FIXME XXX don't store mesh with the record otherwise we can't
# plot the same record in multiple plots with different axes.
proc mesh_QxQz {id} {
    upvar \#0 $id rec
    if {[isTOF]} {
	foreach {rec(x) rec(y)} [buildmesh -L rec(lambda) \
				     $rec(points) $rec(pixels) \
				     $rec(A) $rec(B) rec(dtheta)] {}
    } else {
	foreach {rec(x) rec(y)} [buildmesh -Q $rec(L) \
				     $rec(points) $rec(pixels) \
				     rec(alpha) rec(beta) rec(dtheta)] {}
    }
    set rec(xlabel) "Qx (inv Angstroms)"
    set rec(ylabel) "Qz (inv Angstroms)"
    set rec(xcoord) "Qx"
    set rec(ycoord) "Qz"
}

proc find_QxQz {id x y} {
    upvar \#0 $id rec
    if {[isTOF]} {
	return [findmesh -L rec(lambda) \
		    $rec(points) $rec(pixels) \
		    $rec(A) $rec(B) rec(dtheta) $x $y]
    } else {
	return [findmesh -Q $rec(L) \
		    $rec(points) $rec(pixels) \
		    rec(alpha) rec(beta) rec(dtheta) $x $y]
    }
}

proc mesh_TiTd {id} {
    upvar \#0 $id rec
    foreach {rec(x) rec(y)} [buildmesh -d \
				 $rec(points) $rec(pixels) \
				 rec(alpha) rec(beta) rec(dtheta)] {}
    set rec(xlabel) "theta_f - theta_i (degrees)"
    set rec(ylabel) "theta_i (degrees)"
    set rec(ycoord) "Ti"
    set rec(xcoord) "Td"
}

proc find_TiTd {id x y} {
    upvar \#0 $id rec
    return [findmesh -d \
		$rec(points) $rec(pixels) \
		rec(alpha) rec(beta) rec(dtheta) $x $y]
}

proc mesh_TiTf {id} {
    upvar \#0 $id rec
    foreach {rec(x) rec(y)} [buildmesh -f \
				 $rec(points) $rec(pixels) \
				 rec(alpha) rec(beta) rec(dtheta)] {}
    set rec(xlabel) "theta_f (degrees)"
    set rec(ylabel) "theta_i (degrees)"
    set rec(ycoord) "Ti"
    set rec(xcoord) "Tf"
}

proc find_TiTf {id x y} {
    upvar \#0 $id rec
    return [findmesh -f \
		$rec(points) $rec(pixels) \
		rec(alpha) rec(beta) rec(dtheta) $x $y]
}

proc mesh_AB {id} {
    upvar \#0 $id rec
    foreach {rec(x) rec(y)} [buildmesh -b \
				 $rec(points) $rec(pixels) \
				 rec(alpha) rec(beta) rec(dtheta)] {}
    set rec(xlabel) "theta_i+theta_f (degrees)"
    set rec(ylabel) "theta_i (degrees)"
    set rec(ycoord) "A"
    set rec(xcoord) "B"
}

proc find_AB {id x y} {
    upvar \#0 $id rec
    return [findmesh -b \
		$rec(points) $rec(pixels) \
		rec(alpha) rec(beta) rec(dtheta) $x $y]
}

proc mesh_slit {id} {
    upvar \#0 $id rec
    foreach {rec(x) rec(y)} [buildmesh \
				 $rec(points) $rec(pixels) \
				 rec(slit1) rec(dtheta)] {}
    set rec(xlabel) "theta_f - theta_i (degrees)"
    set rec(ylabel) "slit 1 (mm)"
    set rec(ycoord) "S1"
    set rec(xcoord) "Td"
}

proc find_slit {id x y} {
    upvar \#0 $id rec
    return [findmesh \
		$rec(points) $rec(pixels) \
		rec(slit1) rec(dtheta) $x $y]
}

proc mesh_LTd {id} {
    upvar \#0 $id rec
    foreach {rec(x) rec(y)} [buildmesh \
				$rec(points) $rec(pixels) \
				rec(lambda) rec(dtheta)] {}
    set rec(xlabel) "theta_f - theta_i (degrees)"
    set rec(ylabel) "wavelength ($::symbol(angstrom))"
    set rec(xcoord) "Td"
    set rec(ycoord) "L"    
}

proc find_LTd {id x y} {
    upvar \#0 $id rec
    return [findmesh \
		$rec(points) $rec(pixels) \
		rec(lambda) rec(dtheta) $x $y]
}

proc mesh_pixel {id {base 0}} {
    upvar \#0 $id rec
    fvector rec(xv) [integer_edges $rec(pixels)]
    fvector rec(yv) [integer_edges $rec(points) $base]
    foreach {rec(x) rec(y)} [buildmesh \
				 $rec(points) $rec(pixels) \
				 rec(yv) rec(xv)] {}
    set rec(xlabel) "detector pixels"
    set rec(ylabel) "scan points"
    set rec(xcoord) "pixel"
    set rec(ycoord) "point"
}

proc find_pixel {id x y} {
    upvar \#0 $id rec
    return [findmesh \
		$rec(points) $rec(pixels) \
		rec(yv) rec(xv) $x $y]
}

proc limits {records} {
    set xlim {}
    set ylim {}
    foreach id $records {
	upvar \#0 $id rec
	set xlim [flimits rec(x) $xlim]
	set ylim [flimits rec(y) $ylim]
    }
    return [concat $xlim $ylim]	
}

proc vlimits {records} {
    set vlim {}
    foreach id $records {
	upvar \#0 $id rec
	set vlim [flimits rec(psddata) $vlim]
    }
    return $vlim
}

# ==== Plotting helpers ====
proc findplot {path} {
    
    set plotid "P$path"
    if {![info exists [namespace current]::$plotid]} {
	error "Plot widget $path does not exist"
    }
    uplevel [subst {
	variable $plotid
	upvar 0 [namespace current]::P$path plot
    }]
    return [namespace current]::P$path
}

proc auto_vrange {path} {
    upvar plot plot
    if {[llength $plot(records)] == 0} { return }
    foreach {vlo vhi} [vlimits $plot(records)] {}
    # XXX FIXME XXX should we automatically select decades?
    if {$vlo < $vhi*1e-5} { set vlo [expr {$vhi*1e-5}]}
    set plot(vlim) [list $vlo $vhi]
    $path configure -vrange $plot(vlim)
}

proc auto_axes {path} {
    upvar plot plot
    if {[llength $plot(records)] == 0} { return }
    set plot(limits) [limits $plot(records)]
    $path configure -limits $plot(limits)
}

# ==== Plotting operations ====
proc calc_transform {path type} {
    upvar plot plot
    set plot(mesh) $type
    set plot(mesh_entry) $type
    set plot(points) 0
    foreach id $plot(records) {
	upvar \#0 $id rec
	if { $type == "pixel" } {
	    mesh_$type $id $plot(points)
	    incr plot(points) $rec(points)
	    incr plot(points)
	} else {
	    mesh_$type $id
	}
	$path delete $plot($id)
	set plot($id) \
	    [$path mesh $rec(points) $rec(pixels) $rec(x) $rec(y) $rec(psddata)]
	set plot(title) "$rec(ylabel) vs. $rec(xlabel)"
    }
}

proc setdiff {a b} {
    set result {}
    foreach el $a { if {[lsearch $b $el] < 0} { lappend result $el } }
    return $result
}

variable rebin_lo
variable rebin_hi
variable rebin_resolution
proc rebin {id} {
    upvar #0 $id rec
    if {![info exist rec(TOF)]} { return }
    set fid $rec(fid)
    variable rebin_lo
    variable rebin_hi
    variable rebin_resolution
    # puts "rebin $id from $rebin_lo to $rebin_hi with $rebin_resolution"
    $fid proportional_binning $rebin_lo $rebin_hi $rebin_resolution

    set rec(points) [$fid Nt]
    set rec(lambda) [$fid lambda_edges]
    set rec(column,lambda) [$fid lambda]
    set rec(column,monitor) [$fid monitor]
    set rec(psdraw) [$fid counts]
    set rec(psddata) [$fid I]
    set rec(psderr) [$fid dI]

    plot2d redraw .plot.c
}

proc FrameCoordinates {w x y} {
    variable frame
    set wmsg [winfo toplevel $frame(plot)].message
    upvar #0 $frame(id) rec
    foreach {X Y} [$frame(plot) coords $x $y] break
    set idx -1
    catch { set idx [findmesh $frame(nx) $frame(ny) frame(xv) frame(yv) $X $Y]}
    if { $idx >= 0 } {
        set val [findex frame(data) $idx]
        $wmsg conf -text \
	    "[file tail $rec(file)]([expr {int($X)}],[expr {int($Y)}]): $val"
    } else {
        $wmsg conf -text ""
    }
}

proc SetFrame {v} {
    variable frame
    upvar #0 $frame(id) rec
    set Nt [$rec(fid) Nt]
    if {$v > $Nt} { set v $Nt }
    $frame(w) conf -to $Nt
    set frame(nx) [$rec(fid) Nx]
    set frame(ny) [$rec(fid) Ny]
    fvector frame(xv) [integer_edges $frame(nx)]
    fvector frame(yv) [integer_edges $frame(ny)]
    foreach {frame(x) frame(y)} [buildmesh $frame(nx) $frame(ny) frame(xv) frame(yv)] {}
    set frame(data) [$rec(fid) frame $v]
    foreach {lo hi} [flimits frame(data)] {}
    if {$v != 0 } { set lo 1. }
    $frame(plot) configure -vrange [list $lo $hi]
    $frame(plot) delete
    $frame(plot) mesh $frame(nx) $frame(ny) $frame(x) $frame(y) $frame(data)
    $frame(plot) draw
    set sum [fintegrate $frame(nx) $frame(ny) frame(data) 1]
    ::frame_x seq 1 $frame(ny)
    ::frame_y set [fvector sum]
    if { $v == 0 } { 
	set frame(lambda) {} 
    } else {
	set lambda [fvector rec(column,lambda)]
	set frame(lambda) [fix [lindex $lambda [expr {$v-1}]] {} {} 5]
    }
}

proc setframe {{v 1}} {
    variable frame
    $frame(w) set $v
    SetFrame $v
}

proc frameplot {id} {
    variable frame
    set w .frame
    if {[winfo exists $w]} {
        raise $w
    } else {
        toplevel $w
	set frame(plot) $w.c
	set frame(slice) $w.slice

	vector create ::frame_x ::frame_y
	graph $frame(slice) -height 100 -leftmargin 2c -rightmargin 0 \
	    -border 0 -plotpadx 0 -plotpady 0 -plotborderwidth 0
	$frame(slice) elem create data -xdata ::frame_x -ydata ::frame_y
	$frame(slice) legend configure -hide 1
	$frame(slice) axis configure x -hide 1
	meshcolorbar $w.cb
	$w.cb configure -pady 1cm
        meshplot $frame(plot) -borderwidth 4 -colorbar $w.cb
        $frame(plot) delete
        $frame(plot) colormap [colormap_bright 64]
        $frame(plot) configure -logdata off -grid on
	$frame(plot) bind <Motion> [namespace code {FrameCoordinates %W %x %y}]
	set f [frame $w.f]
        set frame(sum) 0
	radiobutton $f.sum -text "Sum frames" \
	    -variable [namespace current]::frame(sum) -value 1 \
	    -command [namespace code {
	        SetFrame 0
		.frame.f.framenum configure -state disable
		.frame.f.wavelength_label configure -state disable
	        .frame.f.wavelength configure -state disable
	}]
	radiobutton $f.single -text "Frame #" \
	    -variable [namespace current]::frame(sum) -value 0 \
            -command [namespace code {
	        SetFrame [.frame.f.framenum get]
	        .frame.f.framenum configure -state normal
		.frame.f.wavelength_label configure -state normal
	        .frame.f.wavelength configure -state readonly
	}]
	set frame(w) $f.framenum
	spinbox $f.framenum -command [namespace code {SetFrame %s}] \
	    -from 1 -to 2 -width 5
	label $f.wavelength_label -text "Wavelength"
	entry $f.wavelength -textvariable [namespace current]::frame(lambda) \
	    -state readonly -width 10
	grid $f.sum $f.single $f.framenum $f.wavelength_label $f.wavelength
	label $w.message -relief ridge -anchor w
        # scrollbar $w.select -takefocus 1 -orient horiz
	grid $frame(slice) $w.cb -sticky news
	grid $frame(plot)   ^ -sticky news
        grid $f - -sticky w
        grid $w.message - -sticky ew
	grid rowconfigure $w 0 -weight 1
	grid rowconfigure $w 1 -weight 5
	grid columnconfigure $w 0 -weight 1
    }
    variable frame
    set frame(id) $id
    upvar #0 $id rec
    $frame(w) configure -to $rec(points)
    set xmax [expr {[$rec(fid) Ny]+1}]
    set ymax [expr {[$rec(fid) Nx]+1}]
    $frame(plot) configure -limits [list 0 $xmax 0 $ymax]
    $frame(slice) axis configure x -min 0 -max $xmax
    SetFrame 1
}

proc monitor {id} {
    set w .monitor
    if {[winfo exists $w]} {
        raise $w
    } else {
        toplevel $w
        graph $w.graph -title "Monitor graph"
	$w.graph axis conf x -title "Wavelength ($::symbol(angstrom))"
	$w.graph axis conf y -title "Counts"
	active_graph $w.graph
	active_axis $w.graph x
	active_axis $w.graph y
	active_legend $w.graph
	set f [frame $w.rebin]
	entry $f.start -textvariable [namespace current]::rebin_lo
	entry $f.stop -textvariable [namespace current]::rebin_hi
	entry $f.resolution -textvariable [namespace current]::rebin_resolution
	button $f.getrange -text "From graph..." -command [subst {
            graph_select $w.graph [namespace current]::rebin_lo \
		[namespace current]::rebin_hi}]
	button $f.rebin -text "Rebin"
	bind $f.resolution <Return> "$f.rebin invoke"
	label $f.start_label -text "From"
        label $f.start_units -text "$::symbol(angstrom)"
	label $f.stop_label -text "to"
	label $f.stop_units -text "$::symbol(angstrom)" 
	label $f.resolution_label -text "Resolution"
	label $f.resolution_units -text "%"
	grid $f.rebin \
             $f.resolution_label $f.resolution $f.resolution_units \
	     $f.start_label $f.start $f.start_units \
             $f.stop_label $f.stop $f.stop_units \
             $f.getrange
        label $w.message -relief ridge -anchor w
	grid $w.graph -sticky news
	grid $w.rebin -sticky w
	grid $w.message -sticky we
        grid rowconfigure $w 0 -weight 1
	grid columnconfigure $w 0 -weight 1
    }
    upvar #0 $id rec
    eval $w.graph element delete [$w.graph element names]
    eval $w.graph marker delete [$w.graph marker names]
    $w.graph conf  -title "Monitors for $rec(legend)"
    $w.rebin.rebin conf -command "[namespace current]::rebin $id"
    $w.graph element create Raw -label "" \
            -xdata [fvector rec(column,monitor_raw_lambda)] \
            -ydata [fvector rec(column,monitor_raw)]
#    $w.graph element create Monitor -label "" \
#            -xdata [fvector rec(column,lambda)] \
#            -ydata [fvector rec(column,monitor)]
}

proc redraw {path} {
    upvar plot plot
    calc_transform $path $plot(mesh)
    $path draw
}

proc showall {path} {
    upvar plot plot
    auto_axes $path
    auto_vrange $path
    $path draw
}

proc names {path} {
    upvar plot plot
    return $plot(records)
}

proc center {path center} {
    upvar plot plot
    if {[string is double $center]} {
	set plot(center) $center
	foreach id $plot(records) {
	    set_center_pixel $id $center
	}
	calc_transform $path $plot(mesh)
    }
    # XXX FIXME XXX center shouldn't know about center_entry
    set plot(center_entry) $center
    $path draw
}

proc transform {path type} {
    upvar plot plot
    set newtype [expr {$plot(mesh) != $type}]
    variable transforms
    if { [lsearch $transforms $type] < 0 } {
	error "transform $path $type: expected $transforms"
    }
    calc_transform $path $type
    if {$newtype} { auto_axes $path }
    $path draw
}

proc add {path records} {
    upvar plot plot

    foreach id $records {
	upvar \#0 $id rec

	# check if record is plotted
	set n [lsearch $plot(records) $id]
	if { $n >= 0 } { continue }
	lappend plot(records) $id

	# adjust the center pixel if necessary
	if {![info exists plot(center)]} { 
	    set plot(center) [expr {$rec(pixels)/2.}] 
	}
	set_center_pixel $id $plot(center)

	if { $plot(mesh) == "pixel" } {
	    mesh_$plot(mesh) $id $plot(points)
	    incr plot(points) $rec(points)
	    incr plot(points)
	} else {
	    mesh_$plot(mesh) $id
	}
	set plot($id) \
	    [$path mesh $rec(points) $rec(pixels) $rec(x) $rec(y) $rec(psddata)]
    }
    auto_axes $path
    auto_vrange $path
    $path draw
}

proc delete {path records} {
    upvar plot plot

    foreach id $records {
	upvar \#0 $id rec
	
	# check if record is plotted
	set n [lsearch $plot(records) $id]
	if { $n < 0 } { continue }
	set plot(records) [lreplace $plot(records) $n $n]

	# remove record from the plot
	$path delete $plot($id)
	array unset plot $id
    }

    # reset point number
    if { $plot(mesh) == "pixel" } { calc_transform $path $plot(mesh)}

    # reset axes
    auto_axes $path
    auto_vrange $path
    $path draw
}

proc new {w} {
    meshplot $w -borderwidth 4
    $w delete
    $w colormap [colormap_bright 64]
    $w configure -logdata on -grid on -vrange {0.0002 2}
    variable P$w
    array set P$w {mesh TiTd records {} center 100 title {}}
    bind <Destroy> $w [namespace code [list unset P$w]]
}

# ===== plot window functions =====
proc UpdateCenter {w} {
    findplot $w
    if { $plot(center_entry) != $plot(center) } {
	plot2d center $w $plot(center_entry)
    }
}

proc UpdateMesh {w} {
    findplot $w
    if { $plot(mesh_entry) != $plot(mesh) } {
	plot2d transform $w $plot(mesh_entry)
    }
}


proc uncertainty { val err } {
    return "${val}($err)"
}

proc ShowCoordinates { w x y } {
    findplot $w
    set wmsg [winfo toplevel $w].message

    foreach {X Y} [$w coords $x $y] break
    # puts "Coordinates for $x $y -> $X $Y"
    
    # FIXME: traverse the plots in stack order, stopping at
    # the first one which matches
    foreach id $plot(records) {
	upvar \#0 $id rec

	set idx -1
	catch { set idx [find_$plot(mesh) $id $X $Y] }
	if { $idx >= 0 } { 
	    set counts [findex rec(psdraw) $idx]
	    set val [findex rec(psddata) $idx]
	    if { [info exists rec(psderr)] } {
		set err [findex rec(psderr) $idx]
	    } else {
		set err {}
	    }
	    set j [expr {$idx/$rec(pixels)}]
	    set k [expr {$idx%$rec(pixels)}]
	    $wmsg conf -text \
		"[file tail $rec(file)]($j,$k)   counts: [expr {int($counts)}]   normalized: [fix $val]   $rec(ycoord): [fix $Y]    $rec(xcoord): [fix $X]"
	    return
	}
    }

    $wmsg conf -text ""
}

proc plot_window {{w .plot}} {
    if {![winfo exists $w]} {
	toplevel $w -width 400 -height 500
	wm protocol $w WM_DELETE_WINDOW [list wm withdraw $w]
    } else {
	wm deiconify $w
	raise $w
	return
    }

    # Create a plot window
    plot2d new $w.c
    meshcolorbar $w.cb
    $w.cb configure -pady 1cm
    $w.c configure -colorbar $w.cb -logdata on
    findplot $w.c
    set pid [namespace current]::P$w.c
    $w.c bind <Motion> [namespace code {ShowCoordinates %W %x %y}]

    # Create a control panel
    set f $w.controls
    frame $f

    set plot(center_entry) $plot(center)
    label $f.lcenter -text "Qz=0 pixel"
    entry $f.center -textvariable ${pid}(center_entry) -width 4
    bind $f.center <Return> [namespace code [list UpdateCenter $w.c]] 
    bind $f.center <Leave> [namespace code [list UpdateCenter $w.c]]

    set plot(meshentry) $plot(mesh)
    label $f.ltransform -text "Transform"
    variable transforms
    if 1 {
	menubutton $f.transform -textvariable ${pid}(mesh) \
	    -menu $f.transform.menu -indicatoron true -relief raised \
	    -padx 1 -pady 1 -width 5
	set m [menu $f.transform.menu -tearoff 1]
	foreach v $transforms {
	    $m add radio -label $v -variable ${pid}(mesh_entry) -value $v \
		-command [namespace code [list UpdateMesh $w.c]]
	}	
    } else {
	spinbox $f.transform  -values $transforms -width 5 \
	    -textvariable ${pid}(mesh_entry) \
	    -command [namespace code [list UpdateMesh $w.c]]
	bind $f.transform <Return> [namespace code [list UpdateMesh $w.c]]
	bind $f.transform <Leave> [namespace code [list UpdateMesh $w.c]]
    }
    grid $f.lcenter $f.center $f.ltransform $f.transform

    label $w.message -relief ridge -anchor w
 
    grid $w.c $w.cb -sticky news
    grid $w.controls - -sticky w
    grid $w.message - -sticky ew
    grid rowconfigure $w 0 -w 1
    grid columnconfigure $w 0 -w 1
    return $w.c
}

}

catch { namespace import reflplot::* }

namespace eval ice {

proc demo {{mesh_style QxQz}} {
    set w [plot_window]

    read_data [file join $::REFLPLOT_HOME joh00909.cg1] rec1
    read_data [file join $::REFLPLOT_HOME joh00916.cg1] rec2

    plot2d center $w 467
    plot2d add $w { rec1 rec2 }
}

proc read_header {fid chunk} {
    set header {}
    while {1} {
	if {[regexp -lineanchor -indices "\n\[^\\#]" $chunk idx]} {
	    append header [string range $chunk 0 [lindex $idx 0]]
	    break
	} elseif {[eof $fid]} {
	    append header $chunk
	    break
	} else {
	    append header $chunk
	    set chunk [read $fid 2048]
	}
    }
    return $header
}

proc read_data {file id} {
    upvar \#0 $id rec
    if {[array exists rec]} { unset rec }
    
    # read file
    set rec(file) $file
    set fid [open $file r]
    set rec(header) [read_header $fid ""]
    seek $fid [string length $rec(header)]
    set data [read $fid]
    close $fid

    # Data dimensions
    if {![regexp {ICE +1.0 *\n} $rec(header)]} {
	error "$file: not an ICE 1.0 file"
    }
    if {![regexp {Npoints +([0-9]+) *\n} $rec(header) in rec(points)]} {
	error "$file: missing \#Npoints xxx"
    }
    if {![regexp {DetectorDims +([0-9]+) *\n} $rec(header) in rec(pixels)]} {
	error "$file: missing \#DetectorDims xxx"
    }
#    if {![regexp {Ncolumns +([0-9]+) *\n} $rec(header) in rec(Ncolumns)]} {
#	error "$file: missing \#Ncolumns xxx"
#    }
    if {![regexp {Columns +(.+) *\n} $rec(header) in rec(columns)]} {
	error "$file: missing \#Columns xxx xxx xxx..."
    }
    set rec(Ncolumns) [llength $rec(columns)]

    # instrument parameters
    set rec(L) 5.
    set rec(pixelwidth) 0.34727 
    set rec(distance)  1600.

    reflplot::parse_data $id $data
    reflplot::normalize $id Monitor
    reflplot::set_axes $id Theta TwoTheta S1
    reflplot::set_center_pixel $id
}

}; # ice namespace


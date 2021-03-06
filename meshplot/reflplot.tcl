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
    variable pi_times_2 [expr {8.*atan(1.)}]
    variable transforms {QxQz TiTf TiTd AB slit pixel LTd}
    variable colorlist {}


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

proc dtheta_edges {pixeledges distance center} {
    variable pi_over_180
    set edges {}
    # puts "new pixeledges [lrange $pixeledges 0 10]"
    foreach p $pixeledges {
	# puts "pixel offset ($p-$center) = [expr $p-$center]"
	lappend edges [expr {atan2(-($p-$center),$distance) / $pi_over_180}]
    }
    return $edges
}

proc dtheta_centers {pixeledges distance center} {
    variable pi_over_180
    set c {}
    set l [lindex $pixeledges 0]
    foreach p [lrange $pixeledges 1 end] {
	lappend c [expr {($l+$p)/2}]
	set l $p
    }
    return [dtheta_edges $c $distance $center]
}

proc set_center_pixel {id {c {}}} {
    upvar \#0 $id rec
    # default to center of the detector
    if {[llength $c] == 0} { set c [expr {($rec(pixels)+1.)/2.}] }
    set rec(centerpixel) $c
    # puts "id $id center $c [lrange $rec(pixeledges) 0 10]"
    fvector rec(dtheta) \
	[dtheta_edges $rec(pixeledges) $rec(distance) $c]
    fvector rec(column,dtheta) \
	[dtheta_centers $rec(pixeledges) $rec(distance) $c]
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

proc normalize {id} {
    upvar \#0 $id rec

    # Start from scratch
    set rec(psddata) $rec(psdraw)
    ferr rec(psddata) rec(psderr)

    #puts "n=[flength rec(column,monitor)] $rec(pixels) $rec(points)"
    # frame scale (monitor * attenuator * footprint * incident medium)
    fdivide columns $rec(points) $rec(pixels) rec(psddata) rec(column,monitor)
    fdivide columns $rec(points) $rec(pixels) rec(psderr) rec(column,monitor)

    # pixel scale
    fdivide rows $rec(points) $rec(pixels) rec(psddata) rec(column,pixelnorm)
    fdivide rows $rec(points) $rec(pixels) rec(psderr) rec(column,pixelnorm)

    # mapping density correction
    if {[info exists rec(mapscale)]} {
	#puts "scaling"
	fdivide elements $rec(pixels) $rec(points) rec(psddata) rec(mapscale)
	fdivide elements $rec(pixels) $rec(points) rec(psderr) rec(mapscale)
	# set rec(psddata) $rec(mapscale)
    } else {
	#puts "not scaling"
    }

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
    set rec(column,alpha) $rec(column,$theta)
    set rec(column,beta) $rec(column,$twotheta)
    set rec(column,slit1) $rec(column,$slit1)
}

proc ABL {id row A B L} {
    upvar \#0 $id rec
    upvar $A alpha
    upvar $B beta
    upvar $L lambda
    if {[isTOF]} {
	set alpha $rec(A)
	set beta $rec(B)
	set lambda [findex rec(column,lambda) $row]
    } else {
	set alpha [findex rec(column,alpha) $row]
	set beta [findex rec(column,beta) $row]
        set lambda $rec(L)
    }
}
    
# ----------------------------------------------

# FIXME don't store mesh with the record otherwise we can't
# plot the same record in multiple plots with different axes.
proc mesh_QxQz {id} {
    upvar \#0 $id rec
    if {[isTOF]} {
	foreach {rec(x) rec(y)} [buildmesh -L rec(lambda) \
				     $rec(points) $rec(pixels) \
				     $rec(A) $rec(B) rec(dtheta)] {}
	set rec(mapscale) [scalemesh -L rec(column,lambda) \
			       $rec(points) $rec(pixels) \
			       $rec(A) $rec(B) rec(column,dtheta)]
    } else {
	foreach {rec(x) rec(y)} [buildmesh -Q $rec(L) \
				     $rec(points) $rec(pixels) \
				     rec(alpha) rec(beta) rec(dtheta)] {}
	#puts "defining scale"
	set rec(mapscale) [scalemesh -Q $rec(L) \
			       $rec(points) $rec(pixels) \
			       rec(column,alpha) rec(column,beta) \
			       rec(column,dtheta)]
    }
    set rec(xlabel) "Qx"
    set rec(xunits) "inv Angstroms"
    set rec(ylabel) "Qz"
    set rec(yunits) "inv Angstroms"
    set rec(xcoord) "Qx"
    set rec(ycoord) "Qz"
}

proc integration_QxQz {id} {
    upvar \#0 $id rec
    variable pi_over_180
    variable pi_times_2

    # Generate integration region boundaries
    foreach region_edge [array names rec edge,*] {
	set Qx {}
	set Qz {}
	foreach el $rec($region_edge) \
	    A [fvector rec(column,alpha)] B [fvector rec(column,beta)] \
	    {
	    set Ti [expr {$A*$pi_over_180}]
	    set Td [expr {atan2($rec(pixelwidth)*$el,$rec(distance))}]
	    lappend Qz [expr {$pi_times_2/$rec(L)*(sin($Ti+$Td)+sin($Ti))}]
	    lappend Qx [expr {$pi_times_2/$rec(L)*(cos($Ti+$Td)-cos($Ti))}]
	}
	fvector rec(curve,$region_edge) $Qx
	fvector rec(x,curve,$region_edge) $Qz
	       
    }
}

proc row_QxQz {id row} {
    upvar \#0 $id rec
    variable pi_over_180
    ABL $id $row A B L
    set x {}
    foreach d [fvector rec(column,dtheta)] {
 	lappend x [expr {$::pitimes2/$L*(cos($pi_over_180*($d+$B-$A)) \
	    - cos($pi_over_180*$A))}]
    }
    return $x
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

# ----------------------------------------------

proc mesh_TiTd {id} {
    upvar \#0 $id rec
    foreach {rec(x) rec(y)} [buildmesh -d \
				 $rec(points) $rec(pixels) \
				 rec(alpha) rec(beta) rec(dtheta)] {}
    set rec(xlabel) "theta_f - theta_i"
    set rec(xunits) "degrees"
    set rec(ylabel) "theta_i"
    set rec(yunits) "degrees"
    set rec(ycoord) "Ti"
    set rec(xcoord) "Td"
}

proc integration_TiTd {id} {
    upvar \#0 $id rec
    variable pi_over_180

    # Generate integration region boundaries
    set rec(curvex) $rec(column,alpha)
    foreach region_edge [array names rec edge,*] {
	set result {}
	foreach el $rec($region_edge) {
	    lappend result [expr {
		atan2(-$rec(pixelwidth)*$el,$rec(distance))/$pi_over_180
            }]
	}
	fvector rec(curve,$region_edge) $result
    }
}

proc row_TiTd {id row} {
    upvar \#0 $id rec
    ABL $id $row A B L
    set x {}
    foreach d [fvector rec(column,dtheta)] {
 	lappend x [expr {$d+$B-2*$A}]
    }
    return $x
}

proc find_TiTd {id x y} {
    upvar \#0 $id rec
    return [findmesh -d \
		$rec(points) $rec(pixels) \
		rec(alpha) rec(beta) rec(dtheta) $x $y]
}

# ----------------------------------------------

proc mesh_TiTf {id} {
    upvar \#0 $id rec
    foreach {rec(x) rec(y)} [buildmesh -f \
				 $rec(points) $rec(pixels) \
				 rec(alpha) rec(beta) rec(dtheta)] {}
    set rec(xlabel) "theta_f"
    set rec(xunits) "degrees"
    set rec(ylabel) "theta_i"
    set rec(yunits) "degrees"
    set rec(ycoord) "Ti"
    set rec(xcoord) "Tf"
}

proc integration_TiTf {id} {
    upvar \#0 $id rec
    variable pi_over_180

    # Generate integration region boundaries
    set rec(curvex) $rec(column,alpha)
    foreach region_edge [array names rec edge,*] {
	set result {}
	foreach el $rec($region_edge) \
	    A [fvector rec(column,alpha)] B [fvector rec(column,beta)] \
	    {
	    lappend result [expr {
		atan2(-$rec(pixelwidth)*$el,$rec(distance))/$pi_over_180+$B-$A
            }]
	}
	fvector rec(curve,$region_edge) $result
    }
}

proc row_TiTf {id row} {
    upvar \#0 $id rec
    ABL $id $row A B L
    set x {}
    foreach d [fvector rec(column,dtheta)] {
 	lappend x [expr {$d+$B-$A}]
    }
    return $x
}

proc find_TiTf {id x y} {
    upvar \#0 $id rec
    return [findmesh -f \
		$rec(points) $rec(pixels) \
		rec(alpha) rec(beta) rec(dtheta) $x $y]
}

# ----------------------------------------------

proc mesh_AB {id} {
    upvar \#0 $id rec
    foreach {rec(x) rec(y)} [buildmesh -b \
				 $rec(points) $rec(pixels) \
				 rec(alpha) rec(beta) rec(dtheta)] {}
    set rec(xlabel) "theta_i+theta_f"
    set rec(xunits) "degrees"
    set rec(ylabel) "theta_i"
    set rec(yunits) "degrees"
    set rec(ycoord) "A"
    set rec(xcoord) "B"
}

proc integration_AB {id} {
    upvar \#0 $id rec
    variable pi_over_180

    # Generate integration region boundaries
    set rec(curvex) $rec(column,alpha)
    foreach region_edge [array names rec edge,*] {
	set result {}
	foreach el $rec($region_edge) B [fvector rec(column,beta)] {
	    lappend result [expr {
		atan2(-$rec(pixelwidth)*$el,$rec(distance))/$pi_over_180 + $B
            }]
	}
	fvector rec(curve,$region_edge) $result
    }
}

proc row_AB {id row} {
    upvar \#0 $id rec
    ABL $id $row A B L
    set x {}
    foreach d [fvector rec(column,dtheta)] {
 	lappend x [expr {$d+$B}]
    }
    return $x
}

proc find_AB {id x y} {
    upvar \#0 $id rec
    return [findmesh -b \
		$rec(points) $rec(pixels) \
		rec(alpha) rec(beta) rec(dtheta) $x $y]
}

# ----------------------------------------------

proc mesh_slit {id} {
    upvar \#0 $id rec

    # Generate mesh
    foreach {rec(x) rec(y)} [buildmesh \
				 $rec(points) $rec(pixels) \
				 rec(slit1) rec(dtheta)] {}
    set rec(xlabel) "theta_f - theta_i"
    set rec(xunits) "degrees"
    set rec(ylabel) "slit 1"
    set rec(yunits) "mm"
    set rec(ycoord) "S1"
    set rec(xcoord) "Td"
}


proc integration_slit {id} {
    upvar \#0 $id rec
    variable pi_over_180

    # Generate integration region boundaries
    set rec(curvex) $rec(column,slit1)
    foreach region_edge [array names rec edge,*] {
	set result {}
	foreach el $rec($region_edge) {
	    lappend result [expr {
		atan2(-$rec(pixelwidth)*$el,$rec(distance))/$pi_over_180
            }]
	}
	fvector rec(curve,$region_edge) $result
    }
}

proc row_slit {id row} {
    upvar \#0 $id rec
    ABL $id $row A B L
    set x {}
    foreach d [fvector rec(column,dtheta)] {
 	lappend x [expr {$d+$B-2*$A}]
    }
    return $x
}

proc find_slit {id x y} {
    upvar \#0 $id rec
    return [findmesh \
		$rec(points) $rec(pixels) \
		rec(slit1) rec(dtheta) $x $y]
}

# ----------------------------------------------

proc mesh_LTd {id} {
    upvar \#0 $id rec
    foreach {rec(x) rec(y)} [buildmesh \
				$rec(points) $rec(pixels) \
				rec(lambda) rec(dtheta)] {}
    set rec(xlabel) "theta_f - theta_i"
    set rec(xunits) "degrees"
    set rec(ylabel) "wavelength"
    set rec(yunits) "$::symbol(angstrom)"
    set rec(xcoord) "Td"
    set rec(ycoord) "L"    
}

proc integration_LTd {id} {
    upvar \#0 $id rec
    variable pi_over_180

    # Generate integration region boundaries
    set rec(curvex) $rec(lambda)
    foreach region_edge [array names rec edge,*] {
	set result {}
	foreach el $rec($region_edge) {
	    lappend result [expr {
		atan2(-$rec(pixelwidth)*$el,$rec(distance))/$pi_over_180
            }]
	}
	fvector rec(curve,$region_edge) $result
    }
}

proc row_LTd {id row} {
    upvar \#0 $id rec
    ABL $id $row A B L
    set x {}
    foreach d [fvector rec(column,dtheta)] {
 	lappend x [expr {$d+$B-2*$A}]
    }
    return $x
}

proc find_LTd {id x y} {
    upvar \#0 $id rec
    return [findmesh \
		$rec(points) $rec(pixels) \
		rec(lambda) rec(dtheta) $x $y]
}

# ----------------------------------------------

proc mesh_detector {id {base 0}} {
    upvar \#0 $id rec

    # Generate mesh
    fvector rec(xv) $rec(pixeledges)
    fvector rec(yv) [integer_edges $rec(points) $base]
    foreach {rec(x) rec(y)} [buildmesh \
				 $rec(points) $rec(pixels) \
				 rec(yv) rec(xv)] {}
    set rec(xlabel) "detector position"
    set rec(xunits) "mm"
    set rec(ylabel) "frame"
    set rec(yunits) ""
    set rec(xcoord) "position"
    set rec(ycoord) "point"
}

proc integration_detector {id {base 0}} {
    upvar \#0 $id rec

    # Generate integration region boundaries
    fvector rec(curvex) [integer_centers $rec(points) $base]
    foreach region_edge [array names rec edge,*] {
	set result {}
	foreach el $rec($region_edge) {
	    lappend result [expr {$el + $rec(centerpixel)}]
	}
	fvector rec(curve,$region_edge) $result
    }
}

proc row_detector {id row} {
    upvar \#0 $id rec
    ABL $id $row A B L
    set x {}
    for {set p 1} {$p <= $rec(pixels)} {incr p} {
 	lappend x $p
    }
    return $x
}

proc find_detector {id x y} {
    upvar \#0 $id rec
    return [findmesh \
		$rec(points) $rec(pixels) \
		rec(yv) rec(xv) $x $y]
}

# ----------------------------------------------

proc mesh_pixel {id {base 0}} {
    upvar \#0 $id rec

    # Generate mesh
    fvector rec(xv) [integer_edges $rec(pixels) 0]
    fvector rec(yv) [integer_edges $rec(points) $base]
    foreach {rec(x) rec(y)} [buildmesh \
				 $rec(points) $rec(pixels) \
				 rec(yv) rec(xv)] {}
    set rec(xlabel) "detector pixel"
    set rec(xunits) ""
    set rec(ylabel) "frame"
    set rec(yunits) ""
    set rec(xcoord) "pixel"
    set rec(ycoord) "point"
}

proc integration_pixel {id {base 0}} {
    upvar \#0 $id rec

    # Generate integration region boundaries
    fvector rec(curvex) [integer_centers $rec(points) $base]
    foreach region_edge [array names rec edge,*] {
	set result {}
	foreach el $rec($region_edge) {
	    lappend result [expr {$el + $rec(centerpixel)}]
	}
	fvector rec(curve,$region_edge) $result
    }
}

proc row_pixel {id row} {
    upvar \#0 $id rec
    ABL $id $row A B L
    set x {}
    for {set p 1} {$p <= $rec(pixels)} {incr p} {
 	lappend x $p
    }
    return $x
}

proc find_pixel {id x y} {
    upvar \#0 $id rec
    return [findmesh \
		$rec(points) $rec(pixels) \
		rec(yv) rec(xv) $x $y]
}

# ----------------------------------------------

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
    # FIXME should we automatically select decades?
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

# calc_transform sets up plot but does not draw
proc calc_transform {path type} {
    upvar plot plot
    set plot(mesh) $type
    set plot(mesh_entry) $type
    set plot(points) 0
    array unset plot from,*

    # Clear all items from the graph
    $path delete
    $path colormap [::colormap::$plot(colormap)]

    foreach id $plot(records) {
	upvar \#0 $id rec

	# Clear old integration lines
	array unset rec curvex 
	array unset rec curve,*
	array unset rec x,curve,*
        # foreach curve [array names plot $id,*] { $path delete $plot($curve) }

	# Update mesh
	array unset rec mapscale
	if { $type == "pixel" } {
	    mesh_$type $id $plot(points)
	    integration_$type $id $plot(points)
	    incr plot(points) $rec(points)
	    incr plot(points)
	} else {
	    mesh_$type $id
	    integration_$type $id
	}
	normalize $id
	# $path delete $plot($id)
	set plot($id) \
	    [$path mesh $rec(points) $rec(pixels) $rec(x) $rec(y) $rec(psddata)]

	# Update integration regions
	foreach curve [array names rec curve,*] {
	    if {[info exists rec(x,$curve)]} {
		set plot($id,$curve) \
		    [$path.c curve $rec(points) rec($curve) rec(x,$curve)]
	    } else {
		set plot($id,$curve) \
		    [$path.c curve $rec(points) rec($curve) rec(curvex)]
	    }
	}

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
    ptrace
    upvar #0 $id rec
    if {![info exist rec(TOF)]} { return }
    variable rebin_lo
    variable rebin_hi
    variable rebin_resolution
    tofnref::rebin $id $rebin_lo $rebin_hi $rebin_resolution

    # FIXME: rebin needs a handle to the plot in order to redraw
    # the image after rebinning.  This is not the correct way to
    # deal with this problem.  Need to instead move to MVC with
    # notifications to the viewer that the model has changed.
    plot2d redraw .newpsd.c
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
    set frame(data) [$rec(fid) image $v]
    if {"[$rec(fid) primary]" == "x"} {
	set frame(nx) [$rec(fid) Nx]
	set frame(ny) [$rec(fid) Ny]
    } else {
	set frame(nx) [$rec(fid) Ny]
	set frame(ny) [$rec(fid) Nx]
	ftranspose $frame(ny) $frame(nx) frame(data)
    }
    fvector frame(xv) [integer_edges $frame(nx)]
    fvector frame(yv) [integer_edges $frame(ny)]
    foreach {frame(x) frame(y)} [buildmesh $frame(nx) $frame(ny) frame(xv) frame(yv)] {}


    foreach {lo hi} [flimits frame(data)] {}
    if {$v != 0 } { set lo 1. }
    $frame(plot) configure -vrange [list $lo $hi]
    $frame(plot) delete
    $frame(plot) colormap [::colormap::$frame(colormap)]
    $frame(plot) mesh $frame(nx) $frame(ny) $frame(x) $frame(y) $frame(data)
    $frame(plot) draw
    set sum [fintegrate $frame(nx) $frame(ny) frame(data) 1]
    ::frame_x seq 1 $frame(ny)
    ::frame_y set [fvector sum]

    if [isTOF] {
	if { $v == 0 } { 
	    set frame(lambda) {} 
	} else {
	    set lambda [fvector rec(column,lambda)]
	    set frame(lambda) [fix [lindex $lambda [expr {$v-1}]] {} {} 5]
	}
    }
}

proc drawframe {} {
    variable frame
    if { $frame(sum) } {
	SetFrame 0
    } else {
	SetFrame [$frame(w) get]
    }
}

proc setframe {{v 1}} {
    variable frame
    $frame(w) set $v
    drawframe
}

proc logframe {w} {
    $w logdata toggle
    drawframe
}

proc fullframe {w} {
    variable frame
    upvar #0 $frame(id) rec
    set xmax [expr {[$rec(fid) Ny]+1}]
    set ymax [expr {[$rec(fid) Nx]+1}]
    $frame(plot) configure -limits [list 0 $xmax 0 $ymax]
    drawframe
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
	set frame(colormap) [lindex $::colormap::maps 0]

	vector create ::frame_x ::frame_y
	graph $frame(slice) -height 100 -leftmargin 2c -rightmargin 0 \
	    -border 0 -plotpadx 0 -plotpady 0 -plotborderwidth 0
	active_graph $frame(slice)
	active_axis $frame(slice) y
	$frame(slice) elem create data -xdata ::frame_x -ydata ::frame_y
	$frame(slice) legend configure -hide 1
	$frame(slice) axis configure x -hide 1
	meshcolorbar $w.cb
	#$w.cb configure -pady 1cm
        meshplot $frame(plot) -borderwidth 4 -colorbar $w.cb
        $frame(plot) delete
        $frame(plot) configure -logdata off -grid on
	$frame(plot) bind <Motion> [namespace code {FrameCoordinates %W %x %y}]
	$frame(plot) menu "Log scale" [namespace code {logframe %W}]
	$frame(plot) menu "Reset axes" [namespace code {fullframe %W}]
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
	button $f.roi -text "Reset ROI"
	set frame(roi) $f.roi
	grid $f.sum $f.single $f.framenum $f.wavelength_label $f.wavelength $f.roi
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
    if {"[$rec(fid) primary]" == "x"} {
	set frame(nx) [$rec(fid) Nx]
	set frame(ny) [$rec(fid) Ny]
    } else {
	set frame(nx) [$rec(fid) Ny]
	set frame(ny) [$rec(fid) Nx]
    }
    set xmax [expr {$frame(ny)+1}]
    set ymax [expr {$frame(nx)+1}]
    $frame(plot) configure -limits [list 0 $xmax 0 $ymax]
    $frame(slice) axis configure x -min 0 -max $xmax
    $frame(roi) conf -command "[namespace current]::setroi $id"
    setframe 1
}

proc setroi {id} {
    variable frame
    upvar #0 $frame(id) rec
    set xmax [$rec(fid) Ny]
    set ymax [$rec(fid) Nx]
    set xlo [clip [expr {int(floor([$frame(plot) cget -ymin]))}] 0 $xmax]
    set xhi [clip [expr {int(ceil([$frame(plot) cget -ymax]))}] 0 $xmax]
    set ylo [clip [expr {int(floor([$frame(plot) cget -xmin]))}] 0 $ymax]
    set yhi [clip [expr {int(ceil([$frame(plot) cget -xmax]))}] 0 $ymax]
    $rec(fid) roi $xlo $xhi $ylo $yhi
    rebin $id
    drawframe
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

proc colorlist {} {
    variable colorlist
    if { [llength $colorlist] == 0 } {
	set colorlist [option get .graph lineColors LineColors]
    }
    return $colorlist
}

proc color {i} {
    set c [colorlist]
    return [lindex $c [expr {$i%[llength $c]}]]
}

proc nextcolor {} {
    upvar plot plot
    set c [colorlist]
    incr plot(linecolor)
    return [lindex $c [expr {$plot(linecolor)%[llength $c]}]]
}

proc redraw {path} {
    upvar plot plot
    calc_transform $path $plot(mesh)
    $path draw
}

proc showall {path} {
    findplot $path
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
    # FIXME center shouldn't know about center_entry
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

    # FIXME calc_transform and add need to be merged
    $path colormap [::colormap::$plot(colormap)]
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

	foreach curve {spec backm backp} index { {} - + } {
	    vector create ::${curve}_y_${id} ::${curve}_dy_${id}
	    $plot(compose) element create ${id}_${curve} \
		-ydata ::x_${id} -xdata ::${curve}_y_${id} \
		-xerror ::${curve}_dy_${id} -showerrorbars x \
		-label "$rec(legend)$index" -color [nextcolor]
	}

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

	# remove objects from the mesh plot
	foreach p [array names plot $id*] { 
           $path delete $plot($p)
	   array unset plot $p
        }

	foreach curve {spec backm backp} {
	    catch { vector destroy ::${curve}_y_${id} ::${curve}_dy_${id} }
	    catch { $plot(compose) element delete ${id}_${curve} }
	}

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
    $w configure -logdata on -grid on -vrange {0.0002 2}
    variable P$w
    array set P$w {mesh QxQz records {} center 0 title {}}
    bind <Destroy> $w [namespace code [list unset P$w]]
}

# ===== plot window functions =====


# Helper function which returns tuples {depth record_id index row pixel}
# underneath the cursor position x,y.  This is used for things such as
# ShowCoordinates, SelectCenter and Cycle
proc FindUnder {w x y} {
    findplot $w
    foreach {X Y} [$w coords $x $y] break

    # Find mesh order
    set order [$w order]

    # Find pixels which lie under the cursor; prefix each with it's
    # position in the mesh stack
    set under {}
    foreach id $plot(records) {
        upvar \#0 $id rec
	set idx [find_$plot(mesh) $id $X $Y]
	if { $idx >= 0 } { 
	    set row [expr {$idx/$rec(pixels)}]
	    set pixel [expr {$idx%$rec(pixels)}]
	    lappend under [list [lsearch $order $plot($id)] \
			       $id $idx $row $pixel]
	}
    }

    # Sort pixels
    return [lsort -index 0 -decreasing $under]
}

proc UpdateCenter {w} {
    findplot $w
    if { $plot(center_entry) != $plot(center) } {
	plot2d center $w $plot(center_entry)
    }
}

proc SelectCenter {w x y} {
    set under [lindex [FindUnder $w $x $y] 0]
    if {[llength $under] > 0} {	plot2d center $w [lindex $under 4] }
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

proc SetOrigin {w x y} {
    findplot $w
    foreach {plot(from,x) plot(from,y)} [$w coords $x $y] break
}

proc ShowCoordinates { w x y } {
    findplot $w
    foreach {X Y} [$w coords $x $y] break
    set wmsg [winfo toplevel $w].message
    set mesh [lindex [FindUnder $w $x $y] 0]
    if { [llength $mesh] > 0 } {
	foreach {k id idx r c} $mesh break
	upvar \#0 $id rec
	set counts [findex rec(psdraw) $idx]
	set val [findex rec(psddata) $idx]
	if { [info exists rec(psderr)] } {
	    set err [findex rec(psderr) $idx]
	} else {
	    set err {}
	}
	set msg "[file tail $rec(file)]($r,$c)   counts: [expr {int($counts)}]   normalized: [fix $val]   $rec(ycoord): [fix $Y]    $rec(xcoord): [fix $X]"
    } else {
	set msg ""
    }
    if { [info exists plot(from,x)] } {
        append msg "  distance: [fix [expr {$X-$plot(from,x)}]] [fix [expr {$Y-$plot(from,y)}]]"
    }
    $wmsg conf -text $msg
}


proc ToggleLog {w} {
    findplot $w
    $w logdata toggle
    redraw $w
}

proc Cycle {w x y} {
    findplot $w
    set mesh [lindex [FindUnder $w $x $y] 0]
    if { [llength $mesh] > 0 } {
	foreach {k id idx i j} $mesh break
	upvar \#0 $id rec
	$w lower $plot($id)
    }
}

proc Colormenu {w color} {
    variable frame
    findplot $w
    set plot(colormap) $color
    set frame(colormap) $color
    redraw $w
}

proc logfloor {x dx} {
    if 0 {
	# Set the floor based on the uncertainty
	$x expr "$x*($x>$dx)+$dx*($x<=$dx)/2"
    } else {
	# Set the floor to half the minimum value
	set floor [vector expr "min($x*($x>0)+max($x)*($x<=0))"]
	$x expr "$x*($x>0)+$floor*($x<=0)/2"
    }
}

proc drawslice {w x y} {
    findplot $w

    # Clear old slices off the graph
    foreach id [$plot(slice) el names] {
	$plot(slice) el delete $id
        catch { vector destroy ::x${w}_${id} ::y${w}_${id} ::dy${w}_${id} }
    }
    foreach id [$plot(slice) marker names] { 
	$plot(slice) marker delete $id 
    }

    # Handle case of no slice
    if { $x eq {} || $y eq {} } { return }

    set color 0
    foreach id $plot(records) {
        upvar \#0 $id rec

	# Grab constant y slice returning n x 4 matrix of x,y,z,dz
	set slice [fslice $rec(points) $rec(pixels) rec(x) rec(y) \
		       rec(psddata) rec(psderr) 0 $y 1 $y]

	# If returned list isn't empty plot the line
	set npts [expr {[flength slice]/4}]
	if { $npts > 0 } {
	    vector create ::x${w}_${id} ::y${w}_${id} ::dy${w}_${id}
	    foreach d {x y dy} i {0 2 3} {
		set v [fextract $npts 4 slice $i]
		::${d}${w}_${id} set [fvector v]
	    }
	    logfloor ::y${w}_${id} ::dy${w}_${id}
	    $plot(slice) el create $id \
		-xdata ::x${w}_${id} -ydata ::y${w}_${id} \
		-yerror ::dy${w}_${id} -color [color [incr color]] \
		-label $rec(legend)
	}
    }

    # Update axis labels and range
    if {[llength $plot(records)]} {
	$plot(slice) axis configure x \
	    -title "$rec(xlabel) ($rec(xunits)) at $rec(ylabel)=[fix $y] $rec(yunits)" \
	    -min [$w cget -xmin] -max [$w cget -xmax]
    }
}

proc MoveSlice {w x y} {
    findplot $w
    foreach {plot(slice,x) plot(slice,y)} [$w coords $x $y] break
    drawslice $w $plot(slice,x) $plot(slice,y)
}

proc IncrSlice {w delta} {
    findplot $w
    set ystep [expr {([$w cget -ymax]-[$w cget -ymin])/[winfo height $w]}]
    set y [expr {$plot(slice,y)+$ystep*$delta}]
    drawslice $w $plot(slice,x) $y
}


proc transpose {lists} {

    set m [llength $lists]
    set n [llength [lindex $lists 0]]

    # Initialize transpose
    for {set i 0} {$i < $n} {incr i} {
	set T($i) {}
    }

    # Distribute lists into transpose
    foreach L $lists {
        set i 0
	foreach el $L {
	    lappend T($i) $el
	    incr i
	}
    }

    # Join results
    set result {}
    for {set i 0} {$i < $n} {incr i} {
	if { [llength $T($i)] != $m } { error "not square" }
	lappend result $T($i)
    }

    return $result
}

# Convert from theta offset from specular and detector angle to detector
# pixel, keeping the pixel on the detector
proc Td_to_pixel {Td_list beta} {
    upvar rec rec
    variable pi_over_180
    set result {}
    foreach el $L {
	if { $el ne {} } {
	    # Convert angle to distance from detector center
	    set delta [expr {$rec(distance)*tan($el-$beta*$pi_over_180)}]
	    # Convert distance from center to pixel
	    set el [expr {$delta/$rec(pixelwidth) + $rec(centerpixel)}]
	    # Make the pixel lies on the detector
	    if {$el < 0} { 
		set el 0
	    } elseif {$el >= $rec(pixels)} { 
		set el $rec(pixels) 
	    }
	}
	lappend result $el
    }
    return $result
}

proc get_regions {id fn} {
    upvar \#0 $id rec
    set center $rec(centerpixel)
    if {1} { # was: if ![isTOF]
	set L {}
	for {set i 0} { $i < $rec(points) } { incr i } {
	    # Look up slits and angles for the measurement
	    set A [findex rec(column,alpha) $i]
	    set B [findex rec(column,beta) $i]
	    set S1 [findex rec(column,slit1) $i]
	    # Ask user for the corresponding angles between the regions
	    # on the detector and convert those angles to pixels
	    # Grr... must evaluate each element as an expression first
	    set pt {}
	    foreach el [$fn $id $i $A $B $S1 $rec(distance) $rec(pixelwidth)] {
		if {$el eq ""} { lappend pt $el } { lappend pt [expr $el] }
	    }
	    lappend L $pt
	    
	}
	# Rather than returning a list of {lo hi lo hi lo hi} tuples
	# return a tuple of lists
	set ret [transpose $L]
    }
    # Center pixel may have changed
    if { $center != $rec(centerpixel) } { 
	set_center_pixel $id $rec(centerpixel)
    }
    # Index may have changed
    set rec(legend) "$rec(run)$rec(index)"
    return $ret
}
	
proc integrate_region {id left right} {
    upvar \#0 $id rec

    set v {}
    set i 0
    foreach lo $left hi $right {
	set sum 0.
	if { $lo ne {} && $hi ne {} } {
	    if {$lo > $hi} { foreach {hi lo} [list $lo $hi] break }
	    set k [expr {round($lo+$rec(centerpixel))-1}]
	    set kend [expr {round($hi+$rec(centerpixel))-1}]
	    if {$k < 0} { set k 0 }
	    if {$kend > $rec(pixels)} { set kend $rec(pixels) }
	    # puts "integrating $rec(legend)($i,$k:$kend-1)"
	    set k [expr {$k+$i*$rec(pixels)}]
	    set kend [expr {$kend+$i*$rec(pixels)}]
	    while {$k < $kend } {
		set sum [expr {$sum + [findex rec(psdraw) $k]}]
		incr k
	    }
	}
	lappend v $sum
	if { $hi eq "" } { lappend w 0 } { lappend w [expr {$hi-$lo}] }
        incr i
    }
    return [list $v $w]
}

proc empty_to_zero {L} {
    set result {}
    foreach el $L { if {$el eq {}} {lappend result 0.} {lappend result $el} }
    return $result
}

proc integrate_measurement {id} {
    upvar \#0 $id rec
    set uid 0
    array unset rec edge,*
    set regions [get_regions $id region_fn]
    foreach {lo hi} $regions curve {spec backm backp} {
	set rec(edge,$curve,lo) [empty_to_zero $lo]
	set rec(edge,$curve,hi) [empty_to_zero $hi]
    }
    foreach {lo hi} $regions curve {spec backm backp} {
	foreach {v w} [integrate_region $id $lo $hi] break
        ::${curve}_y_${id} set $v
	set vec($curve,n) [vector create ::v[incr uid]]
	$vec($curve,n) set $w
    }

    # Background is back+ and back- added together and scaled to be an
    # equivalent number of pixels to the specular.
    foreach v {back scale} { set vec($v) [vector create ::v[incr uid]] }
    $vec(back) expr "::backp_y_$id+::backm_y_$id"
    $vec(scale) expr "$vec(spec,n)/($vec(backp,n) + $vec(backm,n) + !($vec(backp,n) + $vec(backm,n)))"

    # Counts is specular minus scaled background
    # FIXME what to do with dropped frames?
    ::counts_${id} expr "::spec_y_$id-$vec(back)*$vec(scale)"
    ::dcounts_${id} expr "sqrt(::spec_y_$id+$vec(back)*$vec(scale)^2)"
    ::idx_${id} expr "::counts_${id}!=0"

    # Uncertainty in specular
    ::spec_dy_$id expr "sqrt(::spec_y_$id)"

    # Scale background and compute uncertainty
    foreach curve {backm backp} {
	set vec($curve,scale) [vector create ::v[incr uid]]
	$vec($curve,scale) expr "$vec(spec,n)/($vec($curve,n)+!$vec($curve,n))"
	::${curve}_y_${id} expr "::${curve}_y_${id}*$vec($curve,scale)"
	::${curve}_dy_${id} expr "sqrt(::${curve}_y_${id})*$vec($curve,scale)"
    }

    # FIXME may want to normalize by monitor/time and attenuator.

    # FIXME hack to get around broken log scales in BLT; need to fix BLT
    foreach curve {spec backm backp} {
	::${curve}_y_${id} expr "::${curve}_y_${id}+0.9*!::${curve}_y_${id}"
    }


    # Clean up temporary vectors
    foreach name [array names vec] { vector destroy $vec($name) }
}

proc integrate {w} {
    findplot $w
    set text [$plot(integration_region) get 0.0 end]
    proc region_fn {id point A B S1 dd w} [subst {
	upvar #0 \$id rec 
	$text
    }]

    foreach id $plot(records) {	integrate_measurement $id }
    # Show new integration regions
    redraw $w
    drawslice $w $plot(slice,x) $plot(slice,y)
    # Show new integrated curves
    atten_set $::addrun
}

proc plot_window {{w .plot}} {
    if {![winfo exists $w]} {
	toplevel $w -width 400 -height 500
	wm protocol $w WM_DELETE_WINDOW [list wm withdraw $w]
    } else {
	wm deiconify $w
	raise $w
	return $w.c
    }


    # Create a plot window
    plot2d new $w.c
    meshcolorbar $w.cb
    $w.cb configure -pady 0m
    $w.c configure -colorbar $w.cb -logdata on

    # Build a colormap menu
    menu $w.c.colormenu -title "Colormaps" -tearoff 0
    foreach c $::colormap::maps {
	$w.c.colormenu add command -label [string totitle $c] \
	    -command [namespace code [list Colormenu $w.c $c]]
    }

    # Standard menu choices which should 
    $w.c menu "Cycle" [namespace code {Cycle %W %x %y}]
    $w.c menu "Log scale" [namespace code {ToggleLog %W}]
    $w.c menu "Reset axes" [namespace code {showall %W}]
    $w.c menu "Distance" [namespace code {SetOrigin %W %x %y}]
    $w.c submenu "Colormap" $w.c.colormenu

    # Specialized menu
    $w.c menu "Center pixel" [namespace code {SelectCenter %W %x %y}]

    findplot $w.c
    set pid [namespace current]::P$w.c
    $w.c bind <Motion> [namespace code {ShowCoordinates %W %x %y}]
    $w.c bind <<ZoomClick>> [namespace code {MoveSlice %W %x %y}]
    $w.c bind <Control-ButtonPress-1> [namespace code {MoveSlice %W %x %y}]
    $w.c bind <Control-B1-Motion> [namespace code {MoveSlice %W %x %y}]
    $w.c bind <Double-1> [namespace code {Cycle %W %x %y}]
    $w.c bind <Up> [namespace code {IncrSlice %W 1}]
    $w.c bind <Down> [namespace code {IncrSlice %W -1}]

    # Set colormaps
    set plot(colormap) [lindex $::colormap::maps 0]

    # Create a control panel
    set f $w.controls
    frame $f

    set plot(center_entry) $plot(center)
    label $f.lcenter -text "Qz=0 pixel"
    entry $f.center -textvariable ${pid}(center_entry) -width 4
#    button $f.select -text "From graph..." \
#        -command [namespace code {SelectCenter %W}]
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

    button $f.integrate -text "Integrate" \
	-command [namespace code [list integrate $w.c]]
    button $f.accept -text "Accept" -command addrun_accept
    
    grid $f.lcenter $f.center $f.ltransform $f.transform $f.integrate $f.accept

    label $w.message -relief ridge -anchor w


    # Slice plot
    set g $w.slice
    opt $g leftMargin 75 rightMargin 100 height 4c
    graph $g
    active_legend $g
    active_graph $g
    active_axis $g y
    set plot(slice) $g
    set plot(slice,x) {}
    set plot(slice,y) {}

    # Compose plot
    set plot(linecolor) 0
    set g $w.compose
    opt $g width 8c Legend.hide 1 \
	y.title "Qz (inv Anstroms)" y.rotate 90 \
	x.title "Integrated counts"
    graph $g
    # active_legend $g
    active_graph $g
    active_axis $g x
    set plot(compose) $g

    # Compose controls
    set text {
set a [expr abs(1.5*$S1/$w)+5]
set lo -$a
set hi $a
if { $rec(type)=="slit" } { return [list $lo $hi {} {} {} {}] }
return [list $lo $hi 2*$lo $lo $hi 2*$hi]
}
    opt $w.integration_region width 30 height 8
    text $w.integration_region -wrap no
    text_replace $w.integration_region $text
    set plot(integration_region) $w.integration_region
    bind $w.integration_region <Control-Return> \
	[namespace code "integrate $w.c ; break"]


    # Bind everything together
    grid $w.c $w.cb $w.compose -sticky news
    grid $w.slice - $w.integration_region -sticky news
    grid $w.controls - - -sticky w
    grid $w.message - - -sticky ew
    grid rowconfigure $w {0 1} -weight 1
    grid columnconfigure $w {0 3} -weight 1
    return $w.c
}

}

catch { namespace import reflplot::* }

namespace eval ice {

proc demo {{mesh_style QxQz}} {
    set w [reflplot::plot_window]

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
    set rec(column,monitor) $rec(column,Monitor)

    # instrument parameters
    set rec(L) 5.
    set rec(pixelwidth) 0.34727 
    set rec(distance)  1600.

    reflplot::parse_data $id $data
    reflplot::normalize $id
    reflplot::set_axes $id Theta TwoTheta S1
    reflplot::set_center_pixel $id
}

}; # ice namespace



proc plotslice {xval} {
    upvar \#0 rec rec
    if {$rec(psdplot) && $rec(loaded)} {
	set slice [fslice $rec(points) $rec(pixels) rec(x) rec(y) \
		       rec(psddata) rec(psderr) $xval 0 $xval 1]
	set npts [expr {[flength slice]/4}]
	set x [fextract $npts 4 slice 1]
	set y [fextract $npts 4 slice 2]
	set dy [fextract $npts 4 slice 3]
	
	plot [fvector x] [fvector y] ":$xval"
    }
}


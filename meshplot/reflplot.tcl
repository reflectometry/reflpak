package provide reflplot 0.2

# first time through
if {![namespace exists reflplot]} {
    package require snit
    catch {
	package require tkcon
	tkcon show
    }
    catch { package require BLT }
    package require ncnrlib
    package require meshplot
    package require keystate

}

namespace eval reflplot {

namespace export plot2d
variable actions {add delete transform center showall}
proc plot2d {action path args} {
    variable actions
    if {[lsearch $actions $action] < 0} {
	error "plot ?: should be one of $actions"
    } else {
	# XXX FIXME XXX may need an uplevel in here eventually
	findplot $path
	eval [linsert $args 0 $action $path]
    }
}

# ===== Helper functions which don't depend on plot =====
proc dtheta_edges {pixels pixelwidth distance centerpixel} {
  set edges {}
  for {set p 0} {$p <= $pixels} {incr p} {
    lappend edges [expr {atan2(($centerpixel-$p)*$pixelwidth, $distance)}]
  }
  return $edges
}

proc set_center_pixel {id c} {
    upvar \#0 $id rec
    set rec(centerpixel) $c
    fvector rec(dtheta) \
	[dtheta_edges $rec(pixels) $rec(pixelwidth) $rec(distance) $c]
}

# XXX FIXME XXX don't store mesh with the record otherwise we can't
# plot the same record in multiple plots with different axes.
proc mesh_QxQz {id} {
    upvar \#0 $id rec
    foreach {rec(x) rec(y)} [buildmesh -Q $rec(wavelength) \
				 $rec(points) $rec(pixels) \
				 rec(alpha) rec(beta) rec(dtheta)] {}
    set rec(xlabel) "Qx (inv Angstroms)"
    set rec(ylabel) "Qy (inv Angstroms)"
}

proc mesh_TiTd {id} {
    upvar \#0 $id rec
    foreach {rec(x) rec(y)} [buildmesh -d \
				 $rec(points) $rec(pixels) \
				 rec(alpha) rec(beta) rec(dtheta)] {}
    set rec(xlabel) "theta_f - theta_i (degrees)"
    set rec(ylabel) "theta_i (degrees)"
}

proc mesh_TiTf {id} {
    upvar \#0 $id rec
    foreach {rec(x) rec(y)} [buildmesh -f \
				 $rec(points) $rec(pixels) \
				 rec(alpha) rec(beta) rec(dtheta)] {}
    set rec(xlabel) "theta_f (degrees)"
    set rec(ylabel) "theta_i (degrees)"
}

proc mesh_pixel {id {base 0}} {
    upvar \#0 $id rec
    fvector xv [integer_edges $rec(pixels)]
    fvector yv [integer_edges $rec(points) $base]
    foreach {rec(x) rec(y)} [buildmesh \
				 $rec(pixels) $rec(points) \
				 xv yv] {}
    set rec(xlabel) "detector pixels"
    set rec(ylabel) "scan points"
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
	set vlim [flimits rec(psd) $vlim]
    }
    return $vlim
}

# ==== Plotting helpers ====
proc findplot {path} {
    
    set plotid "P$path"
    if {![info exists [namespace current]::$plotid]} {
	error "Plot $path does not exist"
    }
    uplevel [subst {
	variable $plotid
	upvar 0 [namespace current]::P$path plot
    }]
}

proc auto_vrange {path} {
    upvar plot plot
    foreach {vlo vhi} [vlimits $plot(records)] {}
    # XXX FIXME XXX should we automatically select decades?
    if {$vlo < $vhi*1e-5} { set vlo [expr {$vhi*1e-5}]}
    set plot(vlim) [list $vlo $vhi]
    $path configure -vrange $plot(vlim)
}

proc auto_axes {path} {
    upvar plot plot
    set plot(limits) [limits $plot(records)]
    $path configure -limits $plot(limits)
}

# ==== Plotting operations ====
proc showall {path} {
    upvar plot plot
    auto_axes $path
    $path draw
}

proc redraw {path} {
    upvar plot plot
    transform $path $plot(mesh)
}

proc center {path center} {
    upvar plot plot
    foreach id $plot(records) {
	set_center_pixel $id $center
    }
    redraw $path
}

proc transform {path type} {
    upvar plot plot
    set redraw [expr {$plot(mesh) == $type}]
    if { [lsearch {QxQz TiTf TiTd pixel} $type] < 0 } {
	error "transform $path $type: expected QxQz TiTf TiTd or pixel"
    }
    set plot(mesh) $type
    set plot(points) 0
    foreach id $plot(records) {
	upvar \#0 $id rec
	if { $type == "pixel" } {
	    mesh_$type $id $plot(points)
	    incr plot(points) $rec(points)
	} else {
	    mesh_$type $id
	}
	$path delete $plot($id)
	set plot($id) \
	    [$path mesh $rec(points) $rec(pixels) $rec(x) $rec(y) $rec(psd)]
    }
    if {!$redraw} { auto_axes $path }
    $path draw
}

proc add {path records} {
    upvar plot plot

    foreach id $records {
	upvar \#0 $id rec
	lappend plot(records) $id

	if { $plot(mesh) == "pixel" } {
	    mesh_$plot(mesh) $id $plot(points)
	    incr points $rec(points)
	} else {
	    mesh_$plot(mesh) $id
	}
	set plot($id) \
	    [$path mesh $rec(points) $rec(pixels) $rec(x) $rec(y) $rec(psd)]
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
	if { $n < 0 } { return }
	set $plot(records) [lreplace $plot(records) $n $n]
	
	# remove record from the plot
	$path delete $plot($id)
	array unset plot $id
    }

    # reset axes
    auto_axes $path
    auto_vrange $path
    $path draw
}

proc new {w} {
    meshplot $w
    $w delete
    $w colormap [colormap_bright 64]
    $w configure -logdata on -grid on -vrange {0.00002 2}
    variable P$w
    array set P$w {mesh mesh_QxQz records {}}
    bind <Destroy> $w [namespace code [list unset P$w]]
}

# ===== demo functions =====
proc demo_window {{w .plot}} {
    if {![winfo exists $w]} {
	toplevel $w -width 400 -height 500
	wm protocol $w WM_DELETE_WINDOW [list wm withdraw $w]

    } else {
	wm deiconify $w
	raise $w
    }
    new $w.c
    grid $w.c -sticky news
    grid rowconfigure $w 0 -w 1
    grid columnconfigure $w 0 -w 1
    return $w.c
}

proc demo {{mesh_style QxQz}} {
    set w [demo_window]
    findplot $w
    set plot(mesh) $mesh_style

    ice::read_data [file join $::REFLPLOT_HOME joh00909.cg1] rec1
    set_center_pixel rec1 467

    ice::read_data [file join $::REFLPLOT_HOME joh00916.cg1] rec2
    set_center_pixel rec2 467

    add $w { rec1 rec2 }
}

}

catch { namespace import reflplot::* }

namespace eval ice {

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
    if {![regexp {Ncolumns +([0-9]+) *\n} $rec(header) in rec(Ncolumns)]} {
	error "$file: missing \#Ncolumns xxx"
    }
    if {![regexp {Columns +(.+) *\n} $rec(header) in rec(columns)]} {
	error "$file: missing \#Columns xxx xxx xxx..."
    }

    # instrument constants
    set rec(wavelength) 5.
    set rec(pixelwidth) [expr {10.*25.4/608}] 
    set rec(distance) [expr {48*25.4}]
    reflplot::set_center_pixel $id 304
    
    # convert data block to psd data
    fvector d $data

    # Get data block dimensions
    set n [expr {$rec(pixels)+$rec(Ncolumns)}]
    # Try to guess the number of points stored in the file.
    # This won't match the #Npoints value if the scan was aborted.
    set m [expr {[flength d]/$n}]
    if {$m != $rec(points)} {
	# XXX FIXME XXX better error reporting
	puts "Expected $rec(points) scan points but found $m (columns=$rec(Ncolumns) pixels=$rec(pixels) values=[flength d])"
	set rec(points) $m
    }

    # Grab the columns
    set idx 0
    foreach c $rec(columns) {
	set rec(column,$c) [fextract $m $n d $idx]
	incr idx
    }
    set rec(psd) [fextract $m $n d $rec(Ncolumns) $rec(pixels)]

    # normalize by monitor counts
    fdivide $rec(points) $rec(pixels) rec(psd) rec(column,Monitor)

    # XXX FIXME XXX edges doesn't work for single pixel scans
    # need to set theta/twotheta range based on resolution
    fvector rec(alpha) [edges [fvector rec(column,Theta)]]
    fvector rec(beta) [edges [fvector rec(column,TwoTheta)]]
}

}; # ice namespace

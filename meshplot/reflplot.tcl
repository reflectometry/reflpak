#!/bin/sh
# \
exec wish "$0" "$@"

# first time through
if {![namespace exists reflplot]} {
    lappend auto_path .
    package require snit
    catch {
	package require tkcon
	tkcon show
    }
    source ../lib/pan.tcl
    package require meshplot

    meshplot .c
    grid .c -sticky news
    grid rowconfigure . 0 -w 1
    grid columnconfigure . 0 -w 1
    wm geometry . 500x400    
}

source base.tcl

namespace eval reflplot {

namespace export Qmesh dmesh fmesh mesh plot sample limits vlimits center demo

proc dtheta_edges {pixels pixelwidth distance centerpixel} {
  set edges {}
  for {set p 0} {$p <= $pixels} {incr p} {
    lappend edges [expr {atan2(($centerpixel-$p)*$pixelwidth, $distance)}]
  }
  return $edges
}

proc set_center_pixel {c} {
    upvar rec rec
    set rec(centerpixel) $c
    fvector rec(dtheta) \
	[dtheta_edges $rec(pixels) $rec(pixelwidth) $rec(distance) $c]
}

proc Qmesh {} {
    upvar rec rec
    foreach {rec(x) rec(y)} [buildmesh -Q $rec(wavelength) \
				 $rec(points) $rec(pixels) \
				 rec(alpha) rec(beta) rec(dtheta)] {}
    set rec(xlabel) "Qx (inv Angstroms)"
    set rec(ylabel) "Qy (inv Angstroms)"
}

proc dmesh {} {
    upvar rec rec
    foreach {rec(x) rec(y)} [buildmesh -d \
				 $rec(points) $rec(pixels) \
				 rec(alpha) rec(beta) rec(dtheta)] {}
    set rec(xlabel) "theta_f - theta_i (degrees)"
    set rec(ylabel) "theta_i (degrees)"
}

proc fmesh {} {
    upvar rec rec
    foreach {rec(x) rec(y)} [buildmesh -f \
				 $rec(points) $rec(pixels) \
				 rec(alpha) rec(beta) rec(dtheta)] {}
    set rec(xlabel) "theta_f (degrees)"
    set rec(ylabel) "theta_i (degrees)"
}

proc mesh {} {
    upvar rec rec
    fvector xv [integer_edges $rec(pixels)]
    fvector yv [integer_edges $rec(points)]
    foreach {rec(x) rec(y)} [buildmesh \
				 $rec(pixels) $rec(points) \
				 xv yv] {}
    set rec(xlabel) "detector pixels"
    set rec(ylabel) "scan points"
}

proc plot {path {center {}}} {
    upvar rec rec
    if {[llength $center]} { 
	set_center_pixel $center 
	dmesh
    }
    if {[info exists rec(plothandle)]} { 
	$path delete $rec(plothandle) 
	array unset rec plothandle
    }
    $path configure -limits [limits]
    set rec(plothandle) \
	[$path mesh $rec(points) $rec(pixels) $rec(x) $rec(y) $rec(psd)]
    $path draw
}

proc limits {{path {}}} {
    upvar rec rec
    set lim [concat [flimits rec(x)] [flimits rec(y)]]
    if {[llength $path]} {
	$path configure -limits $lim
	$path draw
    } else {
	return $lim
    }
}

proc vlimits {{path {}}} {
    upvar rec rec
    foreach {vmin vmax} [flimits rec(psd)] {}
    # XXX FIXME XXX log should automatically select decades?
    #set vmin [expr {$vmax*1e-7}]
    set lim [list $vmin $vmax]
    if {[llength $path]} {
	$path configure -vrange $lim
	$path draw
    } else {
	return $lim
    }
}

proc sample {{f /home/pkienzle/data/joh/joh00916.cg1}} { 
    upvar rec rec
    ice::read_data $f
    Qmesh
    set path .c
    $path colormap [colormap_bright 64]
    $path configure -logdata on -grid on
    $path configure -vrange [vlimits]
    plot $path
}

proc demo {} {
    upvar rec rec
    set path .c
    $path delete
    $path colormap [colormap_bright 64]
    $path configure -logdata on -grid on -vrange {0.00002 2}

    ice::read_data joh00909.cg1
    Qmesh
    dmesh
    plot $path
    foreach {xmin xmax ymin ymax} [limits] {}

    ice::read_data joh00916.cg1
    Qmesh
    dmesh
    plot $path
    foreach {xmin2 xmax2 ymin2 ymax2} [limits] {}

    if {$xmin2 < $xmin} { set xmin $xmin2 }
    if {$ymin2 < $ymin} { set ymin $xmin2 }
    if {$xmax2 > $xmax} { set xmax $xmax2 }
    if {$ymax2 > $ymax} { set ymax $ymax2 }
    $path configure -limits [list $xmin $xmax $ymin $ymax]
    $path draw
}

}

if {![llength [info command Qmesh]]} { namespace import reflplot::* }

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

proc read_data {file} {
    upvar rec rec
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
    reflplot::set_center_pixel 302
    
    # convert data block to psd data
    fvector d $data

    # Get data block dimensions
    set n [expr {$rec(pixels)+$rec(Ncolumns)}]
    # Try to guess the number of points stored in the file.
    # This won't match the #Npoints value if the scan was aborted.
    # XXX FIXME XXX This could be wrong if the byte sequences happens
    # to code to UTF multi-byte patterns.  Need something better
    # than [string length x] to handle this properly.
    set m [expr {([string length $d]/4+$n-1)/$n}]
    if {$m != $rec(points)} {
	# XXX FIXME XXX better error reporting
	puts "Expected $rec(points) scan points but found $m (columns=$rec(Ncolumns) pixels=$rec(pixels) values=[expr {[string length $d]/4.}])"
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

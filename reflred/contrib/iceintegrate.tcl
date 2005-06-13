# Usage:  iceintegrate XXX.cg1
#
# Use this to reintegrate the frames from a set of
# XXX.cg1 and XXX_Area_##.cg1.gz files.  This is
# required for certain bad versions of ICE which
# did the internal integration incorrectly.
#
# Note: accepts an optional parameter -vertical which
# integrates across rather than along the Qy direction
# for each frame.
#
# Note: if the aspect of the frames (row-major vs. column
# major, fortran vs. C layout) is incorrect, then you will
# need to swap $width and $height in the calls to
# vintegrate_frame and hintegrate_frame.
#
# Note: this is much slower than it could be, but it is
# only required for a few datasets so no need to optimize.

namespace eval iceintegrate {
namespace export iceintegrate

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

proc parse_header {header id} {
    upvar \#0 $id rec
    set pattern "#\\s*(\\w+)(?:\\s*\[:=]\\s*|\\s+)\"?(.*?)\"?\\s*$"
    foreach line [split $header \n] {
	if {[regexp $pattern $line {} label value]} {
	    set rec(field=$label) $value
	} else {
	    ## error "Could not interpret <$line>"
	}
    }    
}

proc read_data {file id} {
    upvar \#0 $id rec
    if {[array exists rec]} { unset rec }
    
    # read file
    set rec(file) $file
    set fid [open $file r]
    set rec(header) [read_header $fid ""]
    seek $fid [string length $rec(header)]
    set rec(data) [read $fid]
    close $fid
}

proc read_frame {file} {
    set fid [open "|gunzip -c \"$file\"" r]
    set data [read $fid]
    close $fid
    return $data
}

proc vintegrate_frame {data w h} {
    set total [lrange $data 0 [expr {$w-1}]]
    for {set i 1} {$i < $h} {incr i} {
	set next [lrange $data [expr {$i*$w}] [expr {$i*$w+$w-1}]]
	set result {}
	foreach T $total N $next { lappend result [expr {$T+$N}] }
	set total $result
    }
    return $total
}

proc hintegrate_frame {data w h} {
    set total {}
    for {set i 0} {$i < $w} {incr i} {
	set next [lrange $data [expr {$i*$h}] [expr {$i*$h+$h-1}]]
	set t 0.
	foreach v $next { set t [expr {$t+$v}] }
	lappend total $t
    }
    return $total
}

proc iceintegrate {file {direction -horizontal}} {
    set id R1

    # Grab original data into rec(data) and rec(header)
    read_data $file $id

    # Interpret the header
    upvar \#0 $id rec
    parse_header $rec(header) $id
    set motors [llength $rec(field=Columns)]
    #set width $rec(field=DetectorDims)
    set width 608
    set values [llength $rec(data)]
    set points [expr {$values/($motors+$width)}]
    if { $points*($motors+$width) != $values } {
	error "Inconsistent values: motors=$motors, width=$width, points=$points, values=$values"
    }

    # Reintegrate frames
    set frame_pattern "[file rootname $file]_Area_%d[file ext $file]"
    set result {}
    puts -nonewline "Processing point..."
    for {set i 0} {$i < $points} {incr i} {
	puts -nonewline " $i"
	set M [lrange $rec(data) [expr {($motors+$width)*$i}] [expr {($motors+$width)*$i+$motors-1}]]

	set frame_file [format $frame_pattern $i]
	set frame [read_frame $frame_file]
	set values [llength $frame]
	set height [expr {$values/$width}]
	if { $height != 512 } {
	    error "Inconsistent frame: $frame_file"
	}
	if {[string match -h* $direction]} {
	    set V [hintegrate_frame $frame $width $height]
	} else {
	    set V [vintegrate_frame $frame $height $width]
	}

	lappend result $M $V
    }
    puts "\nDone."

    # Write result
    set fid [open "I$file" "w"]
    puts $fid $rec(header)
    foreach {M V} $result { puts $fid "$M\n $V" }
    close $fid
}

}; # ice namespace

catch {namespace import iceintegrate::iceintegrate}

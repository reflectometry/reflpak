namespace eval tofnref {

proc register {} {
    # puts "registering .RAW"
    set ::extfn(.raw) [namespace which summary_isis]
    set ::extfn(.nxs) [namespace which summary_nexus]
}

proc summary_isis {action {name {}}} {
    switch $action {
	dataset { return [lindex [splitname $name] 0] }
	instrument { return "ISIS" }
	info { return {date {} comment {}} }
	pattern { return "$name*.[rR][aA][wW]" }
	mark { mark_data isis $name }
    }
}

proc summary_nexus {action {name {}}} {
    switch $action {
	dataset { return [lindex [splitname $name] 0] }
	instrument { return "NeXus" }
	info { return {date {} comment {}} }
	pattern { return "$name*.[nN][xX][sS]" }
	mark { mark_data nexus $name }
    }
}

proc mark_data {instrument file} {
    puts "marking $file"
    # Create a new record
    upvar \#0 [new_rec $file] rec
    set rec(load) [namespace which load_data]
    foreach {rec(dataset) rec(run)} [splitname [file tail $file]] { break }
    set rec(date) [file mtime $file]
    set rec(TOF) 1
    set rec(monitor) 1
    set rec(base) "NEUT"
    set rec(comment) "comment should come from nexus file"
    set rec(T) 0
    set rec(H) 0
    set rec(instrument) $instrument
    set rec(view) [namespace which view]
    set rec(psdplot) 1
    marktype spec 0.55 5.8 {}
    build_header
    puts "marking done"
    return $rec(id)
}

# Construct the text to display in the comment box for the file
proc build_header {} {
    upvar rec rec
    if {[info exist rec(fid)]} {
	set fid $rec(fid)
	set info [subst {File: $rec(file) $rec(date)
Data dimensions: [$fid Nx] x [$fid Ny] x [$fid Nt_raw]
Sample angle: $rec(A) degrees
Detector angle: $rec(B) degrees
Front slits: [expr {1000*$rec(S1)}] [expr {1000*$rec(S2)}] mm
Back slits:  [expr {1000*$rec(S3)}] [expr {1000*$rec(S4)}] mm
Average pixel width: [expr {1000*$rec(pixelwidth)}] mm
Sample to detector: $rec(distance) m
Moderator to detector: [$fid moderatortodetector] m
	}]

    } else {
	set info "File: $rec(file)"
    }

    set rec(header) $info
}

proc view {id w} {
    upvar \#0 $id rec
    text_replace $w $rec(header)
}

# FIXME: dead code; plotting is handled by viewrun.tcl
# monitor and frame are triggered by load_data
proc plot_data {id {mesh_style pixel}} {
    puts "plot_data"
    set w [reflplot::plot_window]
    plot2d transform $w $mesh_style
    plot2d center $w 25
    plot2d add $w $id
    $w configure -vmin 0.002 -vmax 2.
    reflplot::monitor $id
    reflplot::frameplot $id
    reflplot::setframe
}

proc load_data { id} {
    upvar \#0 $id rec

    if {[info exists rec(fid)]} { return 1 }

    # read file
    puts "load_data"
    flush stdout
    if {$rec(instrument) == "nexus"} {
	puts "opening_nexus"
	set fid [NXtofnref $rec(file)]
	puts "gathering info from $fid"
	set rec(A) [$fid sample_angle]
	set rec(B) [$fid detector_angle]
        set rec(S1) [$fid preslit1]
        set rec(S2) [$fid preslit2]
        set rec(S3) [$fid postslit1]
        set rec(S4) [$fid postslit2]
    } else {
	set fid [isis $rec(file)]
        set rec(A) 1.5
        set rec(B) 1.5
        set rec(S1) 1.0
        set rec(S2) 1.0
        set rec(S3) 4.0
        set rec(S4) 4.0
    }
    set rec(fid) $fid
    set rec(date) 0
    set rec(distance) [$fid sampletodetector]
    set rec(pixelwidth) [$fid pixelwidth]
    set rec(column,monitor_raw) [$fid monitor_raw]
    set rec(column,monitor_raw_lambda) [$fid monitor_raw_lambda]
    set rec(pixels) [$fid Npixels]
    build_header

    # rebin lambda from 3 to max with 2% resolution
    puts "calling rebin from loaddata"
    $fid roi 170 190 70 190
    set reflplot::rebin_lo 3
    set reflplot::rebin_hi [$fid maxwavelength]
    set reflplot::rebin_resolution 2.
    rebin $id $reflplot::rebin_lo $reflplot::rebin_hi $reflplot::rebin_resolution

    # FIXME load_data should not trigger monitor and frame plot
    reflplot::monitor $id
    reflplot::frameplot $id
    reflplot::setframe

    return 1
}

variable progress_text
variable progress_value
variable progress_alive
proc progress {w action args} {
    # ptrace

    variable progress_text
    variable progress_value
    variable progress_alive

    switch -- $action {
	abort {
	    set progress_alive 0
	    set progress_text "Stop..."
	    update
	}
	raise {
	    set progress_alive 1
	    set text [namespace current]::progress_text
	    set value [namespace current]::progress_value
	    set progress_text [lindex $args 0]
	    # FIXME width should be based on text extent
	    ProgressDlg $w -textvariable $text -width 100 \
		-stop Stop -variable $value -maximum 100 \
		-command [namespace code "progress $w abort"]
	    #  grab release $w ;# allow user interaction while processing  
	    update
	}
	lower {
	    destroy $w
	    update
	}
	update {
	    set from [lindex $args 0]
	    set to [lindex $args 1]
	    set progress_value [expr {int(100*$to)}]
	    update
	    return $progress_alive
	}
    }
}

proc rebin {id lo hi resolution} {
    upvar #0 $id rec
    if {![info exist rec(TOF)]} { return }
    set fid $rec(fid)
    
    puts "rebinning using $lo $hi $resolution"
    $fid proportional_binning $lo $hi $resolution
    $fid rebin [namespace code {progress .tofnload %a}]
    
    set rec(points) [$fid Nt]
    set rec(lambda) [$fid lambda_edges]
    set rec(column,lambda) [$fid lambda]
    set rec(column,monitor) [$fid monitor]
    set rec(psdraw) [$fid counts]
    set rec(psddata) [$fid I]
    set rec(psderr) [$fid dI]

    # Things which are fixed for a TOF measurement
    fvector rec(column,alpha) [linspace $rec(A) $rec(A) $rec(points)]
    fvector rec(column,beta) [linspace $rec(B) $rec(B) $rec(points)]
    fvector rec(column,slit1) [linspace $rec(S1) $rec(S1) $rec(points)]

    # Set the Q vector
    set pi_times_4 [expr {16.*atan(1.)}]
    set Qz {}
    foreach L [fvector rec(column,lambda)] {
      lappend Qz [expr $pi_times_4/$L*sin($rec(A))]
    }
    vector create ::Qz_$id
    ::Qz_$id set $Qz
    ::Qz_$id dup ::x_$id
    
    # Need counts and seconds vectors
    vector create ::counts_$id ::dcounts_$id ::idx_$id ::seconds_$id
    ::counts_$id set [linspace 1 1 $rec(points)]
    ::dcounts_$id set [linspace 0 0 $rec(points)]

    # FIXME run duration needs to come from nexus file
    ::seconds_$id set [linspace 1 1 $rec(points)]
}
}

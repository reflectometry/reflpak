namespace eval tofnref {

proc register {} {
    puts "registering .RAW"
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
    return $rec(id)
}

proc view {id w} {
    upvar \#0 $id rec
    text_replace $w $rec(file)
}

proc plot_data {id {mesh_style pixel}} {
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
 
    # read file
    if {$rec(instrument) == "nexus"} {
	set fid [NXtofnref $rec(file)]
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
    set rec(pixels) [$fid Ny]
    set rec(column,monitor_raw) [$fid monitor_raw]
    set rec(column,monitor_raw_lambda) [$fid monitor_raw_lambda]

    # rebin lambda from 0.55 to 5.8 with 1% resolution
    rebin $id 0.55 5.8 1.
    return 1
}

proc rebin {id lo hi resolution} {
    upvar #0 $id rec
    if {![info exist rec(TOF)]} { return }
    set fid $rec(fid)
    
    $fid proportional_binning $lo $hi $resolution
    
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

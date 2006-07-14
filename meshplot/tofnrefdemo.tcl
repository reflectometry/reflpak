namespace eval tofnref {
variable DATADIR [file nativename [file join ~ data test]]

proc demo {{datatype nexus} {data SRF65478}} {
    variable DATADIR
    if { $datatype == "nexus" } {
	set file [file join $DATADIR nexus $data.nxs]
    } else {
	set file [file join $DATADIR isis $data.RAW]
    }
    set id [mark_data $file]
    set ::${id}(instrument) datatype
    load_data $file $id
    plot_data $id
    tkcon show
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

proc mark_data {file} {
    upvar \#0 [new_rec $file] rec
    foreach {rec(dataset) rec(run)} [splitname [file tail $file]] { break }
    set rec(TOF) 1
    return $rec(id)
}

proc load_data { file id} {
    upvar \#0 $id rec
 
    # read file
    if {$rec(instrument) == "nexus"} {
	set fid [NXtofnref $file]
	set rec(A) [$fid sample_angle]
	set rec(B) [$fid detector_angle]
    } else {
	set fid [isis $file]
    }
    set rec(fid) $fid
    set rec(date) 0
    set rec(legend) [file root [file tail $file]]
    set rec(distance) [$fid sampletodetector]
    set rec(pixelwidth) [$fid pixelwidth]
    set rec(pixels) [$fid Ny]
    set rec(column,monitor_raw) [$fid monitor_raw]
    set rec(column,monitor_raw_lambda) [$fid monitor_raw_lambda]

    $fid proportional_binning 0.55 5.8 1.
    marktype spec 0.55 5.8 {}

    set rec(points) [$fid Nt]
    set rec(lambda) [$fid lambda_edges]
    set rec(column,lambda) [$fid lambda]
    set rec(column,monitor) [$fid monitor]
    set rec(psdraw) [$fid counts]
    set rec(psddata) [$fid I]
    set rec(psderr) [$fid dI]
    fvector rec(slit1) [linspace 1.2 1.2 [$fid Nt]]
}
}

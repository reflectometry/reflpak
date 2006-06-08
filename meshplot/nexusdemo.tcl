namespace eval NXtofnref {
variable DATADIR [file nativename [file join ~ data test]]

proc demo {{mesh_style QxQz}} {
    puts "starting demo"
    set w [reflplot::plot_window]
    variable DATADIR
    #isis::read_data [file join $DATADIR nexus SRF25115.nxs] rec2000
    NXtofnref::read_data [file join $DATADIR nexus SRF25149.nxs] rec2000

    plot2d transform $w $mesh_style
    plot2d center $w 25
    plot2d add $w { rec2000 }
    $w configure -vmin 0.002 -vmax 2.
    reflplot::monitor rec2000
    reflplot::frameplot rec2000
    reflplot::setframe
    tkcon show
}

proc read_data { file id } {
    upvar \#0 $id rec
    if {[array exists rec]} { unset rec }

    # read file
    set fid [NXtofnref $file]
    set rec(fid) $fid
    set rec(file) [file root $file]
    set rec(legend) [file root [file tail $file]]
    set rec(TOF) 1
    set rec(A) 1.5
    set rec(B) 3.0
    set rec(distance) [$fid sampletodetector]
    set rec(pixelwidth) [$fid pixelwidth]
    set rec(pixels) [$fid Ny]
    set rec(column,monitor_raw) [$fid monitor_raw]
    set rec(column,monitor_raw_lambda) [$fid monitor_raw_lambda]

    $fid proportional_binning 0.55 5.8 1.

    set rec(points) [$fid Nt]
    set rec(lambda) [$fid lambda_edges]
    set rec(column,lambda) [$fid lambda]
    set rec(column,monitor) [$fid monitor]
    set rec(psdraw) [$fid counts]
    set rec(psddata) [$fid I]
    set rec(psderr) [$fid dI]
}
}

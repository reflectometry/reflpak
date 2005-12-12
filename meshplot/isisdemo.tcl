namespace eval isis {
variable DATADIR /home/pkienzle/data/test

proc demo {{mesh_style QxQz}} {
    puts "starting demo"
    set w [reflplot::plot_window]
    variable DATADIR
    # isis::read_data [file join $DATADIR isis SRF25115.RAW] rec1000
    isis::read_data [file join $DATADIR isis SRF25149.RAW] rec2000

    plot2d transform $w $mesh_style
    plot2d center $w 15
    plot2d add $w { rec2000 }
    reflplot::monitor rec2000
}

proc read_data { file id } {
    upvar \#0 $id rec
    if {[array exists rec]} { unset rec }

    # read file
    set fid [isis $file]
    set rec(fid) $fid
    set rec(file) [file root $file]
    set rec(legend) [file root [file tail $file]]
    set rec(TOF) 1
    set rec(A) 1.
    set rec(B) 2.
    set rec(distance) [$fid distance]
    set rec(pixelwidth) [$fid pixelwidth]
    set rec(points) [$fid Nt]
    set rec(pixels) [$fid Ny]
    set rec(lambda) [$fid lambda_edges]
    set rec(column,lambda) [$fid lambda]
    set rec(column,monitor) [$fid monitor]
    set rec(column,monitor_raw) [$fid monitor_raw]
    set rec(column,monitor_raw_lambda) [$fid monitor_raw_lambda]
    set rec(psdraw) [$fid counts]
    set rec(psddata) [$fid I]
    set rec(psderr) [$fid dI]
}
}

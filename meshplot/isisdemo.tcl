namespace eval isis {
variable DATADIR /home/pkienzle/data/test

proc demo {{mesh_style QxQz}} {
    puts "starting demo"
    set w [reflplot::plot_window]
    variable DATADIR
    isis::read_data [file join $DATADIR isis SRF25115.RAW] rec1
    isis::read_data [file join $DATADIR isis SRF25149.RAW] rec2

    plot2d center $w 15
    plot2d add $w { rec1 rec2 }
}

proc read_data { file id } {
    upvar \#0 $id rec
    if {[array exists rec]} { unset rec }

    # read file
    set fid [isis $file]
    set rec(fid) $fid
    set rec(isTOF) 1
    set rec(A) 1.
    set rec(B) 2.
    set rec(distance) [$fid distance]
    set rec(pixelwidth) [$fid pixelwidth]
    set rec(points) [$fid Nt]
    set rec(pixels) [$fid Ny]
    set rec(lambda) [$fid lambda]
    set rec(psddata) [$fid I]
    set rec(psderr) [$fid dI]
}
}

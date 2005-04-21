package ifneeded meshplot 0.1 [subst {
    load [list [file join $dir plot[info sharedlibextension]]]
    tclPkgSetup [list $dir] meshplot 0.1 {
	{axis.tcl source axis}
    }
    source [list [file join $dir meshplot.tcl]]
}]

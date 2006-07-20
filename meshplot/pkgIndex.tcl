package ifneeded reflplot 0.2 [subst {
    source [list [file join $dir base.tcl]]
    source [list [file join $dir reflplot.tcl]]
    source [list [file join $dir tofnref.tcl]]
    set REFLPLOT_HOME [list $dir]
}]
package ifneeded meshplot 0.1 [subst {
    load [list [file join $dir plot[info sharedlibextension]]]
    tclPkgSetup [list $dir] meshplot 0.1 {
	{axis.tcl source axis}
    }
    source [list [file join $dir meshplot.tcl]]
}]

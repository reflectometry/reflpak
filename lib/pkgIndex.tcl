package ifneeded ncnrlib 0.1 [subst {
    # immediate loading of some packages
    source [list [file join $dir options.tcl]]
    source [list [file join $dir generic.tcl]]
    # delayed loading of other packages
    tclPkgSetup [list $dir] ncnrlib 0.1 {
	{pan.tcl source pan}
	{ctext.tcl source ctext}
	{balloonhelp.tcl source balloonhelp}
	{tableentry.tcl souce tableentry}
	{htext.tcl source {htext hpage}}
	{print.tcl source PrintDialog}
        {sizer.tcl source sizer}
    }
}]
package ifneeded octave 0.1 [list source [file join $dir octave.tcl]]

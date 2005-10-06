package ifneeded reflred 0.1 [subst {
    set VIEWRUN_HOME [list $dir]
    set OCTAVE_HOST localhost:1515
    # on-demand loading of some functions
    tclPkgSetup [list $dir] reflred 0.1 {
	{choose.tcl source choose_dataset}
	{psd.tcl source psd}
	{reduce.tcl source {reduce_clearscan reduce_newscan reduce_show}}
	{abfoot.tcl source ::abfoot::dialog}
	{loadicp.tcl source register_icp}
	{loadice.tcl source ::icedata::mark}
	{loaduxd.tcl source register_uxd}
	{loadreduced.tcl source register_reduced}
    }
    source [list [file join $dir monitor.tcl]]
    source [list [file join $dir atten.tcl]]
    source [list [file join $dir viewrun.tcl]]
}]

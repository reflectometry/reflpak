package ifneeded reflpak 0.1 [subst {
    namespace eval reflpak { variable directory [list $dir] }
    tclPkgSetup [list $dir] reflpak 0.1 {
	{wininstall.tcl source reflpak::wininstall}
    }
    source [list [file join $dir reflpak.tcl]]
}]

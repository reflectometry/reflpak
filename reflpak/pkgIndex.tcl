package ifneeded reflpak 0.1 [subst {
    tclPkgSetup [list $dir] reflpak 0.1 {
	{wininstall.tcl source wininstall}
    }
    source [list [file join $dir reflpak.tcl]]
}]

package ifneeded reflfit 0.1 [subst {
    set ::MLAYER_HOME [list $dir]
    set ::MAGNETIC 0
    load [list [file join $dir gmlayer[info sharedlibextension]]]
    source [list [file join $dir mlayer.tcl]]
}]
package ifneeded reflpol 0.1 [subst {
    set ::MLAYER_HOME [list $dir]
    set ::MAGNETIC 1
    load [list [file join $dir gj2[info sharedlibextension]]]
    source [list [file join $dir mlayer.tcl]]
}]

package provide reflpak 0.1

if { [info var ::app_version] == "" } { set ::app_version "CVS" }

namespace eval reflpak {

    variable app
    variable choose_app
    
    # GUI app selector
    proc choose_app {} {
        package require Tk
        wm withdraw .
        set root .app
        toplevel $root -padx 7 -pady 6
        wm protocol $root WM_DELETE_WINDOW exit
        wm title $root Reflpak
        option add *app.Button.padX 10 widgetDefault
        option add *app.Button.padY 2 widgetDefault
        button $root.fit -text "Fit..." \
            -command [list set [namespace current]::choose_app Reflfit]
        button $root.pol -pady 2 -text "Polarized fit..." \
            -command [list set [namespace current]::choose_app Reflpol]
        button $root.red -text "Reduce..." \
            -command [list set [namespace current]::choose_app Reflred]
        button $root.wish -text "Tcl Console..." \
            -command [list set [namespace current]::choose_app tkcon]
        pack $root.fit $root.pol $root.red $root.wish -fill x -side top

	switch $::tcl_platform(platform) {
	    windows {
		button $root.install -text "Install shortcuts..." \
		    -command [namespace code wininstall]
		pack $root.install -fill x -side top
	    }
	}

        button $root.quit -text "Quit" -command exit
        pack $root.quit -fill x -side top

        vwait [namespace current]::choose_app
        destroy $root
        return [set [namespace current]::choose_app]
    }

    proc shift_arg {{n 1}} {
        set ::argv [lrange $::argv $n end]
        incr ::argc -$n
        if { $::argc < 0 } { set ::argc 0 }
    }

    
    switch -glob -- [lindex $argv 0] {
        -h { puts "usage: reflkit [fit|pol|red]"; exit }
        -v { puts "Reflpak $::app_version"; exit }
        fit { set app Reflfit; shift_arg }
        pol { set app Reflpol; shift_arg }
        red { set app Reflred; shift_arg }
        wish { set app wish; shift_arg }
        *.staj { set app Reflfit }
        *.sta { set app Reflpol }
        default { set app [choose_app] }
    }
    set ::app_version "app $::app_version"
}



switch -- $reflpak::app {
    Reflfit { package require reflfit }
    Reflpol { package require reflpol }
    Reflred { package require reflred }
    tkcon { 
	package require tkcon
	set ::tkcon::PRIV(protocol) exit
	tkcon show 
    }
}

# so the user has chosen to install --- that means we need to:
#   Decide where to put the application
#   Support file extensions
#      map .staj -> ReflfitFile -> relfpak fit %1
#      map .sta -> ReflpolFile -> reflpak pol %1
#      map .ng1, ... -> ReflredFile -> reflpak red %1
#   Add Reflpak to start menu with:
#      Reflfit, Reflpol, Reflred, Tcl console
#   Add desktop shortcuts
#      Reflfit, Reflpol, Reflred

package require BWidget
package require ncnrlib
package require winreg

namespace eval reflpak {

    catch { namespace import ::winreg::* }
    variable exepath [info nameofexecutable]
    variable create_assoc 1 create_menu 1 create_desktop 1

    variable fit_assoc {
	ReflfitModel staj
	ReflfitData refl
    }
    variable pol_assoc {
	ReflpolModel sta
	ReflpolData { reflA reflB reflC reflD }
    }
    variable red_assoc {
	ReflredData { ng1 na1 nb1 nc1 nd1 cg1 ca1 cb1 cc1 \
			    cd1 ng7 uxd xr0 spec back slit }
    }

    proc form_assoc {assoc} {
	foreach {type exts} $assoc {
	    foreach ext $exts {	extension $ext $type }
	}
    }
    proc form_fit_assoc {} {
	variable exepath
	variable fit_assoc
	form_assoc $fit_assoc
	filetype ReflfitModel "Reflfit parameter file" $exepath fit {"%1"}
	if { [filetype ReflfitData "Reflfit data file" $exepath fit {"%1"}] } {
	    fileop ReflfitData Edit $exepath red {"%1"}
	}
    }
    proc form_pol_assoc {} {
	variable exepath
	variable pol_assoc
	form_assoc $pol_assoc
	filetype ReflpolModel "Reflpol parameter file" $exepath pol {"%1"}
	if { [filetype ReflpolData "Reflpol data file" $exepath pol {"%1"}] } {
	    fileop ReflpolData Edit $exepath red {"%1"}
	}
    }
    proc form_red_assoc {} {
	variable exepath
	variable red_assoc
	form_assoc $red_assoc
	filetype ReflredData "Reflred data file" $exepath red {"%*"}
    }
    proc form_prog_links {linkpath} {
	variable exepath
	set docpath [link path documents]
        log "Adding link to \"$exepath\" red \"%1\" in $linkpath\\reflred.lnk"
	link set [file join $linkpath reflred.lnk] \
	    -path $exepath -args red -icon $exepath -index 3 \
	    -cwd $docpath -desc "Reduction"
        log "Adding link to \"$exepath\" fit \"%1\" in $linkpath\\reflfit.lnk"
	link set [file join $linkpath reflfit.lnk] \
	    -path $exepath -args fit -icon $exepath -index 1 \
	    -cwd $docpath -desc "Fit"
        log "Adding link to \"$exepath\" pol \"%1\" in $linkpath\\reflpol.lnk"
	link set [file join $linkpath reflpol.lnk] \
	    -path $exepath -args pol -icon $exepath -index 2 \
	    -cwd $docpath -desc "Polarized Fit"
    }
    proc form_startmenu_links {} {
	variable exepath
	set linkpath [group Reflpak]
	form_prog_links $linkpath
        log "Adding link to \"$exepath\" tkcon in $linkpath\\tkcon.lnk"
	link set [file join $linkpath tkcon.lnk] \
	    -path $exepath -args tkcon -icon $exepath -index 4 \
	    -cwd [file dirname $exepath] -desc "Tcl Console"
    }
    proc form_desktop_links {} { form_prog_links [desktop] }
    proc do_install {} {
	variable create_assoc
	variable create_menu
	variable create_desktop
        if { $create_assoc } { 
            if { [catch {form_fit_assoc} msg] } { 
                warn "fit associations: $msg" 
            } 
            if { [catch {form_pol_assoc} msg] } { 
                warn "polarized fit associations: $msg" 
            }
            if { [catch {form_red_assoc} msg] } { 
                warn "reduction associations: $msg" 
            }
        }
        if { $create_menu } { 
            if { [catch {form_startmenu_links} msg] } { 
                warn "startmenu links: $msg" 
            }
        }
        if { $create_desktop } { 
            if { [catch {form_desktop_links} msg] } { 
                warn "desktop links: $msg" 
            }
        }
    }
    
    proc show_install_results {} {
        set root .installresults
        if { [winfo exists $root] } { destroy $root }
        toplevel $root -padx 6 -pady 7
        wm title $root "Reflpak results"
        sizer $root
        
        set warnings [warn] ; warn -clear
        set lines [regexp "\n" $warnings]
        set logrow 1
        if { $lines > 0 } {
            set logrow 3
            label $root.warnlabel -text Errors
            text $root.warn -height $lines
            if { $lines > 5 } { text conf -height 5 }
            grid $root.warnlabel -sticky w
            grid [scroll $root.warn] -sticky news
            $root.warn insert end $warnings
            $root.warn tag configure dict \
                -wrap word -lmargin2 0.25i -tabs "0.25i left"
            $root.warn tag add dict 0.0 end
            $root.warn conf -state disabled
        }
        
        label $root.loglabel -text "Operation log"
        text $root.log
        $root.log insert end [log] ; log -clear
        $root.log conf -state disabled
        $root.log tag configure dict \
            -wrap word -lmargin2 0.25i -tabs "0.25i left"
        $root.log tag add dict 0.0 end
	button $root.accept -text Ok -pady 2 -padx 16 \
            -command [namespace code [list destroy $root]]
        grid $root.loglabel -sticky w
        grid [scroll $root.log] -sticky news
        grid $root.accept -sticky e -pady {5 0}
        grid rowconf $root $logrow -weight 1
        grid columnconf $root 0 -weight 1
    }

    proc wininstall {} {
	set root .install
	if { [winfo exists $root] } {
	    wm deiconify $root
	    return
	}

	toplevel $root -padx 6 -pady 7
	wm title $root "Reflpak install"
        sizer $root

	# Install options
	checkbutton $root.menu -text "Add shortcuts to start menu" \
	    -variable [namespace current]::create_menu
	checkbutton $root.desktop -text "Add shortcuts to desktop" \
	    -variable [namespace current]::create_desktop
	checkbutton $root.assoc -text "Create file associations" \
	    -variable [namespace current]::create_assoc
	text $root.assocs -height 5

	# Ok/Cancel buttons
	frame $root.but
        # XXX FIXME XXX button sizes probably want minwidth and smaller padding
	button $root.but.accept -text Ok -pady 2 -padx 16 \
            -command [namespace code [subst {
                do_install
                destroy [list $root]
                show_install_results 
            }]]
	button $root.but.cancel -text Cancel -pady 2 -padx 16 \
            -command [list destroy $root] 
	grid $root.but.accept $root.but.cancel -sticky sew
	grid columnconf $root.but {0 1} -uniform a
        grid conf $root.but.accept -padx {0 5} -pady {5 0}

	# Put everything on the screen
	grid $root.menu -sticky w
	grid $root.desktop -sticky w
	grid $root.assoc -sticky w
	grid $root.assocs -sticky news -padx {25 0}
	grid $root.but -sticky e
	grid columnconfigure $root 0 -weight 1
	grid rowconfigure $root 3 -weight 1

	# Display text associations
	variable fit_assoc
	variable red_assoc
	variable pol_assoc
	foreach {name exts} [concat $red_assoc $fit_assoc $pol_assoc] {
	    $root.assocs insert end "$name\t[join $exts { }]\n"
	}
        $root.assocs tag configure dict \
            -wrap word -lmargin2 1i -tabs "1i left"
        $root.assocs tag add dict 0.0 end
	$root.assocs conf -state disabled 
    }
}

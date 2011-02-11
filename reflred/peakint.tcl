# Only allow one copy
if {[namespace exists integrate_peak]} return

hpage {Integrate Peaks} .peaks {
    Ctrl-C Ctrl-X Ctrl-V                   Standard copy/cut/paste (Mac).
    Ctrl-Insert Shift-Delete Shift-Insert  Standard copy/cut/paste (Windows)
    Ctrl-Z        undo
    Shift-Ctrl-Z  redo
    Save As...    saves the contents of the text widget.
    Clear         resets the text widget.

Simply sums the points in a region, and subtracts the same number
of points from either side of that region. If there are not enough
points on either side, then the region is bad, and the data will
say 'truncated'. This assumes the data has been normalized by a
constant monitor and there are no attenuators in the beam.  Because
of the normalization, peaks taken with different monitor counts
should be directly comparable, assuming the overall intensity determined
by the slits is comparable.

This algorithm won't work on ng7 and similar instruments with
normalized data because uncertainty won't be calculated correctly.
Instead of poisson assumptions, we need to use gaussian uncertainty
calculation.  We could detect this by noting whether $rec(monitor) is 1.0.

Much more sophisticated handling of the data (e.g., fitting to
a gaussian peak and calculating the area underneath) is certainly
possible.  See Kevin O'Donovan for code.
}

namespace eval integrate_peak {
    # Attach peak integrator to the user interface
    proc init {} {
	# Add select button to the selector window
	selector_button integrate -text "Peak Integrate..." \
	    -command [namespace code select_and_integrate]
	# function to call when selection is complete
	variable right
	trace add variable right write [namespace code trigger_integrate]
    }

    # Put a new button on the selector screen
    # XXX FIXME XXX this belongs in viewrun.tcl in some form
    proc selector_button {name args} {
	eval [linsert $args 0 button .b.$name]
	pack .b.$name -side left -anchor w
    }

    # Callback to process the "Peak Integrate..." button.
    proc select_and_integrate {} {
	# ptrace
	# XXX FIXME XXX graph select should return a list of
	# points rather than relying on a trace of ::right to
	# determine when the selection is complete.
	graph_select .graph [list [namespace current]::left \
				 [namespace current]::- \
				 [namespace current]::line] \
	    [namespace current]::right
    }

    # Callback to respond after both sides of the peak have been
    # selected.
    proc trigger_integrate {- - -} {
	variable left
	variable right
	variable line
	if { [catch { integrate $left $right $line } msg] } { message $msg }
    }


    # Save list of peaks to a file.
    proc save {w} {
	set filename [ tk_getSaveFile -title "Save peaks data" ]
	if { $filename ne "" } {
	    if { [catch {
		set fid [open $filename w]
		puts $fid [$w get 0.0 end]
		close $fid
	    } msg] } {
		app_error $msg
	    }
	}

    }

    # Add peak to the list of peaks
    proc show_results {peak theta Qz A dA range_error} {
	set w .peaks
	if { [winfo exists $w] } {
	    wm state $w normal
	} else {
	    toplevel $w
	    text $w.text -wrap no -undo 1 -width 70
	    set header [format {%-15s %9s %9s %16s %16s} "Peak" \
			    "Center($::symbol(degree))" \
			    "Qz ($::symbol(invangstrom))" \
			    "Area(normalized)" \
			    "uncertainty"]
	    text_append $w.text "$header\n"
	    wm protocol $w WM_DELETE_WINDOW [list wm state $w withdrawn]
	    frame $w.b
	    button $w.b.save -text "Save As..." \
		-command [namespace code [list save $w.text]]
	    button $w.b.clear -text Clear -command [subst {
		text_clear $w.text
		text_append $w.text "$header\n"}]
	    pack $w.b.save $w.b.clear -side left

	    grid [scroll $w.text] -sticky news
	    grid $w.b -sticky e
	    grid rowconf $w 0 -weight 1
	    grid columnconf $w 0 -weight 1
	}


	set TH [fix $theta 0 10 3]; # 2 digits after the decimal
	set msg "$peak: center $TH$::symbol(degree), area ${A}([fix $dA])"
	set row [format {%-15s %9.2f %9.4f %16g %16g} $peak $theta $Qz $A $dA]
	if { $range_error } {
	    message "$msg, truncated"
	    $w.text insert end "$row (truncated)\n"
	} else {
	    message $msg
	    $w.text insert end "$row\n"
	}

	$w.text see end

	#clipboard clear
	#clipboard append [list $A3 $peak $dpeak]
    }

    # Find the index corresponding to the point selected in the graph
    proc find {x v} {
	set res [$x search [expr {$v*0.9999999999}] [expr {$v*1.0000000001}]]
	# puts "$x search $v = $res"
	return $res
    }

    # Sum a range of indices in a vector
    proc sum {x lo hi} {
	set sum 0.
	for {set i $lo} {$i <= $hi} {incr i} {
	    set sum [expr {$sum + [set ${x}($i)]}]
	}
	return $sum
    }

    # Integrate peak from left to right in line
    proc integrate {left right line} {
	# ptrace

	# Peak range
	set lo [find ::x_$line $left]
	set hi [find ::x_$line $right]
	set end [expr {[::x_$line length]-1}]
	set range_error 0
	if { $lo eq {} } { set lo 0; set range_error 1 }
	if { $hi eq {} } { set hi $end; set range_error 1 }
	if {$lo>$hi} { foreach {lo hi} [list $hi $lo] break } ;# swap

	# peak plus background range
	set width [expr {$hi-$lo+1}]
	set bglo [expr {$lo-$width/2}]
	if { $bglo < 0 } { set bglo 0; set range_error 1 }
	set bghi [expr {$bglo+2*$width-1}]
	if { $bghi > $end } { set bghi $end; set range_error 1 }

	# compute integrated peak minus background
	# puts "$bglo $lo $hi $bghi"
	upvar #0 $line rec
	set fg [sum ::y_$line $lo $hi]
	set bg [sum ::y_$line $bglo $bghi]
	set A [expr {(2*$fg-$bg)}]
	## Use gaussian error propagation for peak uncertainty
	#set dA [vector expr {sqrt(sum(::dy_${line}($bglo:$bghi)^2))}]
	set dA [expr {sqrt($bg/$rec(monitor))}]

	# compute midpoint of x-range, as degrees
	set mid [expr {($hi+$lo)/2}]
	if { $width%2 } {
	    set center [set ::x_${line}($mid)]
	} else {
	    set midlo [set ::x_${line}($mid)]
	    set midhi [set ::x_${line}($mid+1)]
	    set center [expr {($midlo+$midhi)/2}]
	}
	set theta [expr {asin($rec(L)*$center/$::pitimes4)/$::piover180}]

	# send results to the peak list
	show_results "$rec(run)([expr $lo+1]:[expr $hi+1])" \
		$theta $center $A $dA $range_error
    }

    # Initialize the peak integrator if not reloading
    variable initialized
    if { ![info exists initialized] } {
	init
	set initialized 1
    }
}

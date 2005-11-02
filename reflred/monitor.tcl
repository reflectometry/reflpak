# Global variables:
#
# Counting basis is "time" "monitor" or "auto"
# monitor(norm) is the counting basis for the displayed counts
# monitor(use_fixed) is true if a fixed monitor count should be used
# monitor(fixed_counts) is the number of counts to use for fixed monitor
# monitor(fixed_seconds) is the number of seconds to use for fixed time
# monitor(rate_counts) is the counts from a measurement of monitor rate
# monitor(rate_seconds) is the time from a measurement of monitor rate

# Initialize the information needed to control monitor normalization
proc monitor_init {} {
    if {![info exists ::monitor(norm)]} {
	set ::monitor(norm) "auto"
	set ::monitor(use_fixed) 0
	set ::monitor(fixed_counts) 10000
	set ::monitor(fixed_seconds) 1
	set ::monitor(rate_counts) 1
	set ::monitor(rate_seconds) 1
    }
}

proc monitor_reset {} { atten_set $::addrun }

# Monitor settings dialog
proc monitor_dialog {} {
    set w .monitor
    if { [winfo exists $w] } { raise $w; return }

    toplevel $w
    wm title $w "Monitor"
    event add <<MonitorEntryUpdate>> <FocusOut> <Return>

    if 0 {
    # Normalization
    label $w.norm_label -text "Normalize counts by:"
    balloonhelp $w.norm_label \
	"Normalization style for the saved counts. Use with caution."
    set f [frame $w.norm_choice]
    radiobutton $f.auto -text "auto" \
	-variable ::monitor(norm) -value "auto" \
	-command monitor_reset
    radiobutton $f.monitor -text "monitor" \
	-variable ::monitor(norm) -value "monitor" \
	-command monitor_reset
    balloonhelp $f.monitor "Convert to monitor normalization using nominal rate"
    radiobutton $f.time -text "seconds" \
	-variable ::monitor(norm) -value "seconds" \
	-command monitor_reset
    balloonhelp $f.time "Convert to time normalization using nominal rate"
    pack $f.auto $f.monitor $f.time -side left
    }

    # Fixed scale
    checkbutton $w.display_fixed -text "Use fixed scale:" \
	-variable ::monitor(use_fixed) -command monitor_reset
    balloonhelp $w.display_fixed "Display data using a fixed scale."

    # monitor
    set f [frame $w.display_monitor]
    entry $f.value -textvariable ::monitor(fixed_counts) -width 10
    bind $f.value <<MonitorEntryUpdate>> monitor_reset
    label $f.label -text "Fixed monitor of"
    label $f.units -text "counts"
    pack $f.label $f.value $f.units -side left

    # time
    set f [frame $w.display_time]
    entry $f.value -textvariable ::monitor(fixed_seconds) -width 10
    bind $f.value <<MonitorEntryUpdate>> monitor_reset
    label $f.label -text "Fixed time of"
    label $f.units -text "seconds"
    pack $f.label $f.value $f.units -side left

    if 0 {
    # nominal rate
    label $w.rate_label -text "Nominal monitor rate:"
    balloonhelp $w.rate_label \
	"Monitor rate to use when mixing data normalized by time and data normalized by monitor.  Use with caution."
    set f [frame $w.rate_values]
    entry $f.monitor -textvariable ::monitor(rate_counts) -width 10
    entry $f.time -textvariable ::monitor(rate_seconds) -width 10
    bind $f.monitor <<MonitorEntryUpdate>> monitor_reset
    bind $f.time <<MonitorEntryUpdate>> monitor_reset
    label $f.monitor_unit -text "counts in"
    label $f.time_unit -text "seconds"
    pack $f.monitor $f.monitor_unit $f.time $f.time_unit -side left
    }

    # button box
    set f [frame $w.buttons]
    #button $f.apply -text Apply -command monitor_reset
    button $f.ok -text Ok -command "monitor_reset; destroy $w"
    pack $f.ok -side left



    # Put it all together
    grid $w.display_fixed -sticky w
    grid $w.display_monitor -sticky w -padx 3m
    grid $w.display_time -sticky w -padx 3m
    if 0 {
	grid $w.norm_label -sticky w
	grid $w.norm_choice -sticky w -padx 3m
	grid $w.rate_label -sticky w
	grid $w.rate_values -sticky w -padx 3m
    }
    grid $w.buttons -padx 3m -pady 2
}

# Generate a counts label for the given display type and monitor
proc monitor_label { base monitor } {
# CALC    
    
    # set ylabel according to count type
    if { [string equal -nocase $base "seconds"] } {
	set unit "second"
    } elseif { [string equal -nocase $base "monitor"] } {
	set unit "monitor count"
    } else {
	set unit $base
    }
    if { $monitor == 1 } {
	return "Counts per $unit"
    } else {
	if {$monitor == int($monitor)} { set monitor [expr {int($monitor)}] }
	return "Counts per $monitor ${unit}s"
    }
}



# Estimate rate from geometric mean of second third and fourth point.
# If that fails, use all points.
# If that fails, use rate 1.
proc monitor_rate {id} {
    set M ::monitor_$id
    set T ::seconds_$id
    if {![vector_exists $M] || ![vector_exists $T]} {
	return 1.
    } elseif { [$M length] < 4 } {
	return [vector expr (prod($M)/prod($T))^(1./[$M length])]
    } else {
	return [vector expr (prod(${M}(1:3))/prod(${T}(1:3)))^(1./3.)]
    }
}    

proc monitor_value { id } {
    upvar \#0 $id rec

    # What is the normalization base for the record?
    if { $::monitor(norm) == "seconds" } {
	set norm "seconds"
    } elseif { $::monitor(norm) == "monitor" } {
	set norm "monitor"
    } else {
	# if auto, use whatever the first record chosen uses
	set norm $rec(norm)
    }

    # What is the normalization rate for the record?
    set seconds $::monitor(fixed_seconds)
    set monitor $::monitor(fixed_counts)
    if { !$::monitor(use_fixed) } {
	if {$rec(base) eq "TIME"  && $norm eq "monitor"} {
	    set mon [expr {$rec(monitor)*[monitor_rate $rec(id)]}]
	    set $norm [fix $mon  {} {} 3]
	} elseif {$rec(base) eq "NEUT" && $norm eq "seconds"} {
	    set mon [expr {$rec(monitor)/[monitor_rate $rec(id)]}]
	    set $norm [fix $mon {} {} 3]
	} else {
	    set $norm $rec(monitor)
	}
    }

    # Convert this into the appropriate y-label for the record
    set rec(ylab) [monitor_label $norm [set $norm]]
    return [list $norm $monitor $seconds]
}

# Normalize the data set by counting time or monitor (or anything else)
# If normalizing by time, use rate to convert monitors to seconds
# If normalizing by monitor, use rate to convert seconds to monitor
# The data is also scaled by the attenuator factor
proc monitor_norm {id} {
# CALC

    # Note: you can combine runs counted against monitor and time in 
    # the same scan,  but you need to enter the monitor rate for the 
    # particular slit settings as the attenuator for the runs counted
    # against time.  For continuously opening slits, this is not a
    # constant factor for the run since the monitor for NG1 is between
    # slit 1 an slit 2, and receives more counts as slit 1 opens, which
    # corresponds to shorter counting times as slit 1 opens.  The
    # correct way to handle this is to divide by the slit
    # scan counted the same way as the data for each run, then combine
    # the runs.
    upvar \#0 $id rec

    set Io "::counts_$id"
    set dIo "::dcounts_$id"
    set mon "::$rec(norm)_$id"
    set dmon "::d$rec(norm)_$id"
    set I "::y_$id"
    set dI "::dy_$id"
    set k $rec(k)
    set dk $rec(dk)

    # Count normalization; eliminate 0 values in monitor
    if {[vector_exists $dmon]} {
	$dI expr "sqrt(($dIo/($mon+!$mon))^2 + ($Io*$dmon/($mon+!$mon)^2)^2)"
	$I expr "$Io/($mon+!$mon)"
    } else {
	$dI expr "$dIo/($mon+!$mon)"
	$I expr "$Io/($mon+!$mon)"
    }

    # Attenuator correction
    $dI expr "sqrt($k^2*$dI^2 + $I^2*$dk^2)"
    $I expr "$I*$k"
}

# Can't mix monitors and seconds, but we can force the generation of a 
# monitor column from a seconds column or vice versa if we know the monitor 
# rate and it stays the same throughout the measurement.  The case where it
# does not is when the monitor is between slits or after the second slit
# and the slits are opening.
#
# Note that this is instrument dependent and can easily yield bad data.
#
# FIXME: add support for monitor after slit1 or slit2
# FIXME: this code is unused
proc monitor_gen {idlist norm counts seconds} {
    foreach id idlist {
	upvar \#0 $id rec
    
	# Counting unit correction
	set M "::monitor_$id"
	set dM "::dmonitor_$id"
	set T "::seconds_$id"
	set dT "::dseconds_$id"
	set rate [expr {$counts/$seconds}]
	set drate [expr {$counts>1?sqrt($counts)/$seconds:0.}]
	if { $norm == "seconds"} {
	    vector create $T $dT
	    $dT expr "sqrt(($dM/$rate)^2 + ($M*$drate/$rate^2)^2)"
	    $T expr "$M/$rate"
	    note_rec $id "estimate time from monitor counts / ($counts counts/$seconds seconds)"
	} elseif { $norm == "monitor"} {
	    vector create $M $dM
	    if { [vector_exists $dT] } {
		$dM expr "sqrt($rate^2*$dT^2 + $T^2*$drate^2)"
		$M expr "$T*$rate"
	    } else {
		$dM expr "$T*$drate"
		$M expr "$T*$rate"
	    }
	    note_rec $id "estimate monitor from seconds * ($counts counts/$seconds seconds)"
	} else {
	    error "monitor_gen id \"monitor|seconds\" counts seconds"
	}
    }

    monitor_set $idlist $norm
}


proc monitor_set { idlist norm } {
# UI
    foreach id $idlist {
	upvar #0 $id rec
	
	switch -- $norm {
	    auto {
		if { [vector_exists ::monitor_$id] } {
		    set rec(norm) monitor
		} else {
		    set rec(norm) seconds
		}
	    }
	    monitor - seconds {
		if {![vector_exists ::${norm}_${id}]} {
		    error "Can't normalize $id by $norm"
		}
		set rec(norm) $norm
	    }
	    default {
		error "monitor_set_norm id auto|monitor|seconds"
	    }
	}
    }

    monitor_reset
}

if {$argv0 eq [info script] && ![info exists running]} {
    set running 1

    # Get needed library context
    lappend auto_path [file dirname $argv0]/..
    package require Tk
    package require ncnrlib
    package require tkcon
    tkcon show

    # Fake what we need externally
    proc monitor_reset { } { puts "Resetting display" }

    monitor_init
    monitor_dialog
}

# See README.load

# note the new extension
proc register_rigaku {} {
    set ::extfn(.ras) RASinfo
    set ::typelabel(height) "Height scan"
    set ::typelabel(tilt) "Tilt scan"
    set ::typelabel(khi) "Sample rock"
}

proc RASinfo { action {name {}} } {
    switch -- $action {
	instrument { return Rigaku }
	dataset { return [lindex [_RASsplitname $name] 0] }
	info {
	    set date [clock format [file mtime $name] -format %Y-%m-%d]
	    set comment [file tail [file rootname $name]]
	    return [list date $date comment $comment]
	}
	pattern { return [file join [file dirname $name] {*.[rR][aA][sS]}] }
	mark { RASmark $name }
    }
}

proc _RASsplitname {name} {
    set name [file rootname $name]
    # Dataset is everything up to the last three digits, or
    # everything if there are no digits at the end.
    if {[regexp {^(.*?)_?([0-9]{1,3})$} $name {} dataset run]} {
	return [list $dataset $run]
    } else {
	return [list {} $name]
    }
}

proc RASmark {file} {
    # suck in the file
    if {[ catch { open $file r } fid ] } {
	message "Error: $fid"
	return
    }
    set data [read $fid]
    close $fid

    upvar #0 [new_rec $file] rec
    set rec(data) $data
    set id $rec(id)

    # Data definition
    set state 0
    foreach col [list x counts dcounts] {
        vector create ::${col}_$id
        ::${col}_$id length 0
    }
    foreach line [split $data "\n"] {
	if { [string compare $line "*RAS_HEADER_START"]==0 } {
	    set state 1
	} elseif { [string compare $line "*RAS_HEADER_END"]==0 } {
	    set state 0
	} elseif { [string compare $line "*RAS_INT_START"]==0 } {
	    set state 2
	} elseif { [string compare $line "*RAS_INT_END"]==0 } {
	    set state 0
	} else {
	    if { $state == 1 } {
		# process *FIELD "japanese value|value"
		if { [regexp {^[*]([^ ]*) +"([^|]*[|])?([^"]*)" *} $line _ field japanese value] } {
		    set rec(header,$field) $value
		}
	    } elseif { $state == 2 } {
		set parts [split $line]
		::x_$id append [lindex $parts 0]
		::counts_$id append [expr {round([lindex $parts 1]*[lindex $parts 2])}]
		::dcounts_$id append [expr {sqrt([lindex $parts 1])*[lindex $parts 2]}]
	    }
	}
    }
    foreach field [array names rec -regexp {header,MEAS_COND_AXIS_NAME-[0-9]*}] {
	set idx [lindex [split $field "-"] 1]
        set name $rec(header,MEAS_COND_AXIS_NAME_INTERNAL-$idx)

	# fix values, removing units and evaluating attenuator 1/10000
	set value $rec(header,MEAS_COND_AXIS_POSITION-$idx)
	if {[string equal [string range $value end-1 end] "mm"]} {
	    set rec(header,MEAS_COND_AXIS_UNIT-$idx) "mm"
	    set value [string range $value 0 end-2]
	} elseif {[string equal $name "Attenuator"]} {
	    set parts [split $value "/"]
	    set value [expr {double([lindex $parts 0])/double([lindex $parts 1])}]
	}
	set rec(motor,$name) $value
	set rec(motor,$name,label) $rec(header,MEAS_COND_AXIS_NAME-$idx)
	set rec(motor,$name,unit) $rec(header,MEAS_COND_AXIS_UNIT-$idx)
	set rec(motor,$name,offset) $rec(header,MEAS_COND_AXIS_OFFSET-$idx)
    }

    # Default date to filename if start time not available
    if { [catch {clock_scan $rec(header,MEAS_SCAN_START_TIME} date] } {
	set date [file mtime $file]
    }

    set rec(load) RASload
    set rec(view) RASview
    set rec(instrument) "Rigaku"

    set rec(L) [expr {2*$rec(header,HW_XG_WAVE_LENGTH_ALPHA1) + $rec(header,HW_XG_WAVE_LENGTH_ALPHA2)/3}]
    set rec(base) "TIME"
    set rec(T) 0
    set rec(H) 0
    foreach {rec(dataset) rec(run)} [_RASsplitname [file tail $file]] { break }
    set rec(date) $date
    set rec(comment) [string trim "$rec(header,FILE_SAMPLE) $rec(header,FILE_COMMENT)"]
    set rec(data) $data

    set scan $rec(header,MEAS_SCAN_AXIS_X_INTERNAL)
    set min $rec(header,MEAS_SCAN_START)
    set max $rec(header,MEAS_SCAN_STOP)
    if { ![string equal $rec(motor,$scan,label) {}] } {
        set rec(xlab) $scan
    } else {
        set rec(xlab) $rec(motor,$scan,label)
    }
    if { ![string equal $rec(motor,$scan,unit) {}] } {
        set rec(xlab) "$rec(xlab) ($rec(motor,$scan,unit))"
    }

    # ==== Axes ====
    # TwoTheta
    # Omega
    # Chi, Phi    sample rotation?
    # Z, Rx, Ry   sample translation?
    # TwoThetaTheta, TwoThetaOmega, TwoThetaChi, TwoThetaChiPhi
    # Alpha, Beta
    # ThetaS, ThetaD
    # Ts, Zs
    # CBO, CBO-M
    # Incident{SollerSlit,SlitBox,SlitBox-_Axis,Monochromator,AxdSlit}
    # CenterSlit, Filter, Attenuator
    # Receiving{SlitBox[12],Optics,SollerSlit,AxdSlit,SlitBox[12]-_Axis,SlitBox2-Zd}
    # Counter{Monochromator,Slit}
    # TwoThetaB, AlphaR, BetaR
    # IncidentPrimary, HV, PHA

    switch $scan {
        TwoThetaTheta { marktype spec $min $max }
        TwoThetaOmega { marktype spec $min $max }
        Omega { marktype rock3 $min $max }
        TwoTheta { marktype rock $min $max }

        # Don't know if background is set by omega/twotheta relative initial position or offset
        COUPLED {
            if { 2*$rec(THETA) < $rec(2THETA) } {
                marktype back $min $max -
            } elseif { 2*$rec(THETA) > $rec(2THETA) } {
                marktype back $min $max +
            } else {
                switch -regexp -- $run {
                    bk?g?[bm-]$ {
                        marktype back $min $max -
                    }
                    bk?g?[ap+]?$ {
                        marktype back $min $max +
                    }
                    default {
                        marktype spec $min $max
                    }
                }
            }
        }
        default { marktype $scan $min $max }
    }
}

# Update the text widget $w with the contents of the data file for record $id
proc RASview {id w} {
    text_replace $w [set ::${id}(data)]
}

proc RASload {id} {
    upvar #0 $id rec
    set rec(monitor) 1

    set scan $rec(header,MEAS_SCAN_AXIS_X_INTERNAL)
    vector create ::seconds_$id ::slit1_$id ::alpha_$id ::beta_$id
    ::seconds_$id expr "::counts_$id*0 + $rec(monitor)"
    ::slit1_$id expr "::x_$id*0 + $rec(motor,IncidentSlitBox)"
    switch $scan {
        TwoThetaOmega -
        TwoThetaTheta {
            ::alpha_$id expr "0.5*::x_$id"
            ::beta_$id expr "::x_$id"
        }
        Omega {
            ::alpha_$id expr "::x_$id"
            ::beta_$id expr "0*::x_$id+$rec(motor,TwoTheta)"
        }
        TwoTheta {
            ::alpha_$id expr "0*::x_$id+$rec(motor,Omega)"
            ::beta_$id expr "::x_$id"
        }
        default {
            puts "scan is $scan"
        }
    }

    if { ![info exists rec(monitor)] || $rec(monitor)==0.0 } {
	# ignore bad or missing monitor
	set rec(monitor) 1.0
    }

    set rec(k) [expr {1./$rec(motor,Attenuator)}]
    set rec(dk) 0.0
    set rec(norm) 'second'
    set rec(monitor) 1.0

    # Create the 'seconds' column from the constant monitor

    set rec(ylab) [monitor_label $rec(base) $rec(monitor)]

    return 1
}

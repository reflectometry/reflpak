# See README.load

# note the new extension
proc register_uxd {} {
    set ::extfn(.uxd) UXDinfo
    set ::typelabel(height) "Height scan"
    set ::typelabel(tilt) "Tilt scan"
    set ::typelabel(khi) "Sample rock"
}

proc UXDinfo { action {name {}} } {
    switch -- $action {
	instrument { return XRAY }
	dataset { return [file join [file dirname $name] UXD] }
	info {
	    set date [clock format [file mtime $name] -format %Y-%m-%d]
	    set comment [file tail [file rootname $name]]
	    return [list date $date comment $comment]
	}
	pattern { return [file join [file dirname $name] {*.[uU][xX][dD]}] }
	mark { UXDmark $name }
    }
}

# Search for "_FIELD = value" in header section, storing the result in
# variable name. Spaces are optional around the equals sign.  If the
# value is enclosed in single or double quotes, the quotes will be stripped,
# but spaces within the quotes preserved.
proc _UXDfield {field data name} {
    upvar $name value
    # set value {}
    if { [regexp "_$field *= *(\[^\n]*) *\n" $data junk value] } {
	if { [string match {['"]*['"]} $value] } {
	    set value [string range $value 1 end-1]
	}
    }
}

proc UXDmark {file} {
    # ptrace
    # suck in the file
    if {[ catch { open $file r } fid ] } { 
	message "Error: $fid"
	return 
    }
    set data [read $fid]
    close $fid

    # UXD files can have multiple data sections in the same
    # file.  We explode these on mark.

    # Data common to each section
    set sample {} ;# default to no sample
    _UXDfield SAMPLE $data sample
    _UXDfield DATEMEASURED $data datemeasured
    set run [file rootname [file tail $file]]
    if { [catch {clock_scan $datemeasured} date] } { 
	set date [file mtime $file]
    }

    # Split the remainder into data sections
    # Note: split [string map { "Data for" \001 } $data] \001
    # is more compact, but the following is much faster :-(
    # Speed counts during mark
    set idx [string first "Data for" $data]
    if { $idx < 0 } {
	message "skipping empty file $file"
	return
    }
    # set common [string range $data 0 [expr {$idx-1}]]
    set common "_SAMPLE='$sample'\n_DATEMEASURED='[clock format $date]'\n"
    set section {}
    while (1) {
	# Sections are separated either by "; (Data for Range #)"
	# or by "; Data for range #"
	set end [string first "Data for" $data [expr {$idx+1}]]
	if { $end > 0 } {
	    lappend section [string range $data [expr {$idx-3}] [expr {$end-4}]]
	    set idx $end
	} else {
	    lappend section [string range $data [expr {$idx-3}] end]
	    break
	}
    }

    set n 0
    if {[llength $section] == 1} { set n -1 }
    foreach s $section {
	# Create separate data records for each section
	if { $n >= 0 } {
	    upvar "#0" [new_rec $file-[incr n]] rec
	    set rec(run) $run-$n
	    set rec(comment) "$sample $n"
	} else {
	    upvar "#0" [new_rec $file] rec
	    set rec(run) $run
	    set rec(comment) $sample
	}
	# UXD fields
	set rec(load) UXDload
	set rec(view) UXDview
	set rec(instrument) "XRAY"
	set rec(L) 1.5417
	set rec(base) "TIME"
	set rec(T) 0
	set rec(H) 0
	# Common fields
	set rec(dataset) UXD
	set rec(date) $date 

	# Datasets have a couple of different formats.  One has the keyword
	# _2THETACOUNTS followed by two columns, 2*theta and counts.  
	# Another has the form ; Cnt#_D1 followed by a column of counts
	# A third has _2THETACPS followed by two columns, 2*theta and CPS.
	set end -1
	if { $end < 0 } {
	    set end [string first "_2THETACOUNTS" $s]
	    if { $end >= 0 } {
		set rec(header) $common[string range $s 0 [expr {$end+13}]]
		set rec(data) [string range $s [expr {$end+14}] end]
		# range is first value to last value of the two column data set
		set min [lindex $rec(data) 0]
		set max [lindex $rec(data) end-1]
	    }
	}
	if { $end < 0 } {
	    set end [string first "_2THETACPS" $s]
	    if { $end >= 0 } {
		set rec(header) $common[string range $s 0 [expr {$end+10}]]
		set rec(data) [string range $s [expr {$end+11}] end]
		# range is first value to last value of the two column data set
		set min [lindex $rec(data) 0]
		set max [lindex $rec(data) end-1]
		set rec(CPS) 1
	    }
	}
	if { $end < 0 } {
	    set end [string first "; Cnt2_D1" $s]
	    if { $end < 0 } { set end [string first "; Cnt1_D1" $s] }
	    if { $end >= 0 } {
		set rec(header) $common[string range $s 0 [expr {$end+8}]]
		set rec(data) [string range $s [expr {$end+9}] end]
		# range calculated from start, step and n
		_UXDfield START $rec(header) rec(START)
		_UXDfield STEPSIZE $rec(header) rec(STEP)
		set min $rec(START)
		set max [expr {$min+$rec(STEP)*([llength $rec(data)]-1)}]
		set rec(STOP) $max
	    }
	}
	if { $end < 0 } {
	    error "Unknown UXD format"
	}

	# Section specific fields
	# XXX FIXME XXX need to know KHI to distinguish spec from +-back
	# and to convert from KHI or THETA to Qx and to know where the
	# rockbar is centered.
	# XXX FIXME XXX data range may use 'oscillations' which allow
	# multiple motors to be scanned simultaneously (I think)
	_UXDfield DRIVE $rec(header) rec(DRIVE)
	_UXDfield THETA $rec(header) rec(THETA)
	_UXDfield 2THETA $rec(header) rec(2THETA)
	_UXDfield PHI $rec(header) rec(PHI)
	_UXDfield KHI $rec(header) rec(KHI)
	switch $rec(DRIVE) {
	    Z { marktype height $min $max }
	    KHI { marktype khi $min $max }
	    PHI { marktype tilt $min $max }
	    THETA { marktype rock $min $max }
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
	}
    }
}

proc UXDview {id w} { 
    text_replace $w [set ::${id}(header)][set ::${id}(data)] 
}

proc UXDload {id} {
    upvar #0 $id rec

    # Finish interpretting header.  We need to keep the header around anyway
    # so that we can display it in the text window, so we might as well
    # process it in load so that mark is as fast as possible.
    _UXDfield STEPTIME $rec(header) rec(monitor)
    if { ![info exists rec(monitor)] || $rec(monitor)==0.0 } {
	# ignore bad or missing monitor
	set rec(monitor) 1.0
    }

    # See if the attenuator is in place.  Set the default attenuator
    # appropriately.
    _UXDfield DETECTORSLIT $rec(header) atten
    switch -- $atten {
	IN - In - in { set rec(k) 100.0 }
	default { set rec(k) 1.0 }
    }

    # convert the data columns to vectors
    switch $rec(DRIVE) {
	Z { 
	    set motor height
	    set rec(xlab) "Height" 
	}
	KHI { 
	    set motor sample_angle
	    set rec(xlab) "Sample angle (KHI degrees)" 
	}
	PHI {
	    set motor tilt
	    set rec(xlab) "Phi Tilt (degrees)" 
	}
	THETA { 
	    set motor alpha
	    set rec(xlab) "Incident angle (THETA degrees)" }
	COUPLED { 
	    set motor beta
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	}
    }
    if { [info exists rec(STEP)] } {
	# 1-column data is assumed to be counts, with 2theta generated
	# based on start and step
	vector create ::${motor}_$id ::counts_$id
	# XXX FIXME XXX should be using x = start+step*[0:length-1]
	# rather than x = [ start:step:stop ] since it is more robust
	# ::x_$id seq 1 [llength $rec(data)]
	# ::x_$id expr "$rec(START) + (::x_$id-1)*$rec(STEP)"
	::${motor}_$id seq $rec(START) $rec(STOP) $rec(STEP)
	::counts_$id set $rec(data)
    } else {
	# 2-column data is assumed to be 2theta and counts
	if {![get_columns $id [list $motor counts] $rec(data)]} { return 0 }
    }
    ::${motor}_$id dup ::x_$id
    if { $rec(DRIVE) eq "COUPLED" } {
	vector create ::alpha_$id
	::alpha_$id expr "::beta_$id/2"
	AB_to_QxQz $id
    }

    # If measurements recorded as counts per second, translate to counts.
    vector create ::dcounts_$id
    if { [info exists rec(CPS)] } {
	::counts_$id expr "::counts_$id * $rec(monitor)"
    }
    ::dcounts_$id expr "sqrt(::counts_$id + !::counts_$id)"

    # Create the 'seconds' column from the constant monitor
    vector create ::seconds_$id
    ::seconds_$id expr "::counts_$id*0 + $rec(monitor)"

    # XXX FIXME XXX convert x to Qz or whatever units are appropriate
    set rec(ylab) [monitor_label $rec(base) $rec(monitor)]

    return 1
}

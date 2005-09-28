# See README.load
# XXX FIXME XXX dump this into a namespace

set ::xraywavelength 1.5416
set ::cg1wavelength 5.0
set ::ng1wavelength 4.75
set ::ng7wavelength 4.768
# exclude points whose count rate exceeds this
set ::cg1saturation 15000
set ::ng1saturation 15000

proc atoQx {a3 a4 lambda} {
    return "(cos($::piover180*($a4-$a3)) - cos($::piover180*$a3))*$::pitimes2/$lambda"
}

proc atoQz {a3 a4 lambda} {
    return "(sin($::piover180*($a4-$a3)) + sin($::piover180*$a3))*$::pitimes2/$lambda"
}

proc register_icp {} {
    # add addition scan types not in the basic set
    array set ::typelabel { 
	height "Height scan" 
	temp "Temperature scan" 
	rock3 "A3 Rock" 
	absorption "Absorption scan"
    }
    array set ::extfn { 
	.na1 NG1Pinfo .nb1 NG1Pinfo .nc1 NG1Pinfo .nd1 NG1Pinfo
	.ca1 CG1Pinfo .cb1 CG1Pinfo .cc1 CG1Pinfo .cd1 CG1Pinfo
	.ng1 NG1info .cg1 CG1info .ng7 NG7info .xr0 XR0info 
    }
}

proc splitname {name} {
    set name [file rootname $name]
    # Dataset is everything up to the last three digits, or
    # everything if there are no digits at the end.
    if {[regexp {^(.*?)([0-9]{1,3})$} $name {} dataset run]} {
	return [list $dataset $run]
    } else {
	return [list {} $name]
    }
}

proc NG1info { action {name {}} } {
    switch $action {
	dataset { return [lindex [splitname $name] 0] }
	instrument { return "NG-1" }
	info { return [icp_date_comment $name] }
	pattern { return "$name*.\[nN]\[gG]1" }
	mark { NG1mark $name }
    }
}

proc CG1info { action {name {}} } {
    switch $action {
	dataset { return [lindex [splitname $name] 0] }
	instrument { return "CG-1" }
	info { return [icp_date_comment $name] }
	pattern { return "$name*.\[cC]\[gG]1" }
	mark { NG1mark $name }
    }
}

proc NG7info { action {name {}} } {
    switch $action {
	dataset { return [lindex [splitname $name] 0] }
	instrument { return "NG-7" }
	info { return [icp_date_comment $name] }
	pattern { return "$name*.\[nN]\[gG]7" }
	mark { NG7mark $name }
    }
}

proc XR0info { action {name {}} } {
    switch $action {
	dataset { return [lindex [splitname $name] 0] }
	instrument { return "XRAY" }
	info { return [icp_date_comment $name] }
	pattern { return "$name*.\[xR]\[rR]7" }
	mark { XRAYmark $name }
    }
}

proc NG1Pinfo { action {name {}} } {
    switch $action {
	dataset { return [lindex [splitname $name] 0] }
	instrument { return "NG-1p" }
	info { return [icp_date_comment $name] }
	pattern { return "$name*.\[nN]\[aAbBcCdD]1" }
	mark { NG1mark $name }
    }
}

proc CG1Pinfo { action {name {}} } {
    switch $action {
	dataset { return [lindex [splitname $name] 0] }
	instrument { return "CG-1p" }
	info { return [icp_date_comment $name] }
	pattern { return "$name*.\[cC]\[aAbBcCdD]1" }
	mark { NG1mark $name }
    }
}

proc icp_date_comment { file } {
    set date ????
    set comment ????
    catch {
	set fid [open $file]
	catch {
	    set line [gets $fid]
	    set datestr [lindex [split $line '] 3]
	    set datenum [clock_scan $datestr]
	    set date [clock format $datenum -format %Y-%m-%d]
	}
	catch {
	    if {[string match \#ICE* $line]} {
		::icedata::date_comment $fid date comment
	    } else {
		# skip line 2 which contains the field names from line 1
		gets $fid
		# comment is the first 50 characters of line 3
		set comment [string trim [string range [gets $fid] 0 49]]
	    }
	}
	close $fid
    }
    return [list date $date comment $comment]
}

proc icp_parse_psd_octave {id data} {
    upvar #0 $id rec
    
    # Data contains position sensitive detector info.
    #   c1 c2 ... c_k\np1, p2, ..., p_i,\n..., p_n\n
    #   ...
    #   c1 c2 ... c_k\np1, p2, ..., p_j,\n..., p_n\n
    # Count the number of lines as the number times we see
    #   c_k \n p1,
    # Note that we cannot count the number of lines without
    # commas since p_n might be on a line by itself.
    set lines [regexp -all {[0-9] *\n *[0-9]+,} $data]
    
    # Strip the commas so that sscanf can handle it
    set data [ string map {"," " " "\n" " "} $data ]
    octave eval "x=sscanf('$data', '%f ',Inf)"
    
    # Reshape into a matrix of the appropriate number of lines
    octave eval "x=reshape(x,length(x)/$lines,$lines)'"
    
    # Return the first k columns into $rec_$col, and put the
    # rest into psd. I'll leave it to the data interpreter to
    # decide what to do with the psd table.
    # XXX FIXME XXX it seems a little silly to send the string
    # from tcl to octave, send the columns back to tcl as vectors,
    # then send the vectors back to octave --- I'm doing this because
    # in the non-psd case, I do not use octave to interpret the
    # columns, but maybe I should be.
    set i 0
    foreach c $rec(columns) { 
	vector create ::${c}_$id 
	octave recv ${c}_$id x(:,[incr i])
    }
    octave eval "psd_$id = x(:,[incr i]:columns(x))"
    octave eval "psderr_$id = sqrt(psd_$id) + (psd_$id==0)"
    octave sync
    set rec(psd) 1
}

proc icp_parse_psd_fvector {id data} {
    upvar #0 $id rec

    # Data contains position sensitive detector info.
    #   c1 c2 ... c_k\np1, p2, ..., p_i,\n..., p_n\n
    #   ...
    #   c1 c2 ... c_k\np1, p2, ..., p_j,\n..., p_n\n
    # Count the number of lines as the number times we see
    #   c_k \n p1,
    # Note that we cannot count the number of lines without
    # commas since p_n might be on a line by itself.
    set rec(points) [regexp -all {[0-9] *\n *[0-9]+,} $data]
    
    # Strip the commas so that binary scan can handle it
    set data [ string map {"," " "} $data ]

    # convert data block to psd data
    fvector d $data

    # Try to guess the number of pixels per record.
    set rec(pixels) [expr {[flength d]/$rec(points) - $rec(Ncolumns)}]

    # Get data block dimensions
    set m $rec(points)
    set n [expr {$rec(pixels)+$rec(Ncolumns)}]

    # Grab the columns
    set idx 0
    foreach c $rec(columns) {
	set rec(column,$c) [fextract $m $n d $idx]
	incr idx
    }
    set rec(psd) [fextract $m $n d $rec(Ncolumns) $rec(pixels)]

    vector create ::y_$id
    ::y_$id set [fvector rec(column,y)]
    set rec(psdplot) 1
}


# Call the function we are working with
catch { rename icp_parse_psd {} }
rename icp_parse_psd_fvector icp_parse_psd
#rename icp_parse_psd_octave icp_parse_psd

proc icp_load {id} {
    upvar #0 $id rec
    
    # suck in the data file
    if {[ catch { open $rec(file) r } fid ] } { 
	message $fid
	return 0 
    }
    set data [read $fid]
    close $fid

    # chop everything until after the Mot: line
    set offset [string last "\n Mot: " $data ]
    if { $offset < 0 } { return 0 }
    set offset [string first "\n" $data [incr offset]]
    set data [string range $data [incr offset] end]

    # convert the column headers into a list (with special code for #1,#2)
    set offset [string first "\n" $data]
    set col [string range $data 0 [incr offset -1]]
    set col [string map { "COUNTS" "counts" "#1 " "" "#2 " N2 } $col]
    set rec(columns) {}
    foreach c $col { lappend rec(columns) "$c" }
    set rec(Ncolumns) [llength $rec(columns)]
    set data [string range $data [incr offset] end]

    # load the data columns into ::<column>_<id>
    if { [string first , $data] >= 0 } {
	icp_parse_psd $id $data
    } else {
	if ![get_columns $id $rec(columns) $data] { return 0 }
	set rec(psd) 0
    }

    # average temperature
    if { [vector_exists ::TEMP_$id] } {
	set rec(Tavg) "[vector expr mean(::TEMP_$id)]([vector expr sdev(::TEMP_$id)])"
    }

    # activate points with non-negative counts
    set rec(points) [::counts_$id length]
    vector create ::idx_$id
    ::idx_$id expr "::counts_$id>=0"
    return 1
}

# exclude all points in the record $id for which 2*A3 != A4
proc exclude_specular_ridge {id} {
    upvar #0 $id rec
    ::idx_$id expr "::idx_$id && (2*::A3_$id != ::A4_$id)"
}

# exclude points above a saturation value in counts per second
proc exclude_saturated {id rate} {
    upvar \#0 $id rec
    if {[vector_exists ::seconds_$id]} {
	# Find good points, which are those for which rate >= counts/seconds
	# To protect against seconds==0, use seconds*rate >= counts instead.
	# If there is uncertainty in time use least restrictive value rate,
	# which is counts/(seconds+dseconds).
	set good [vector create \#auto]
	if {[vector_exists ::dseconds_$id]} {
	    $good expr "(::seconds_$id+::dseconds_$id)*$rate >= ::counts_$id"
	} else {
	    $good expr "::seconds_$id*$rate >= ::counts_$id"
	}

	# If there are any points that are excluded by this test, warn the
	# user and remove them from the list of valid points.
	if {[vector expr "prod($good)"] == 0} {
	    message "excluding points which exceed $rate counts/second"
	    ::idx_$id expr "::idx_$id && $good"
	}
	vector destroy $good
    }
}


proc default_x {id} {
    upvar #0 $id rec
    
    set col [lindex $rec(columns) 0]
    switch -- $col {
	MON { 
	    ::MON_$id dup ::x_$id
	    cumsum ::x_$id
	    set rec(xlab) "Monitor count" 
	}
	MIN { 
	    ::MIN_$id dup ::x_$id
	    cumsum ::x_$id
	    set rec(xlab) "Time (min)" 
	}
	default { 
	    ::${col}_$id dup ::x_$id
	    set rec(xlab) $col 
	}
    }
}

# ICP sometimes records the incorrect wavelength in the file.  Make
# sure the right value is being used.  Be annoying about it so that
# if the wavelength was changed for a legitimate reason the user can
# override.
proc check_wavelength { id wavelength } {
    upvar #0 $id rec

    # yuck! wavelength in file may be wrong, so override but warn
    set key "::wavelength($rec(dataset),$rec(instrument))"
    if { [info exists $key] } {
	set rec(L) [set $key]
	message "Using wavelength $rec(L) for $rec(dataset) ($rec(instrument))"
    } elseif { $rec(L) == 0.0 } { 
	set rec(L) $wavelength 
	message "Using default wavelength $wavelength for $rec(file)"
    } elseif { abs($rec(L) - $wavelength)/$wavelength > 0.01 } {
	# This is an intrusive dialog which hopefully won't be seen much
	# by the users.  Yes we could make it nicer (e.g., by allowing
	# mouse selection of the Tcl override command), but the number of
	# datasets affected is going to be small enough that it doesn't
	# matter.
	if { [question "ICP recorded a wavelength of $rec(L) in $rec(file).  Do you want to use the default wavelength $wavelength instead?"] } {
	    set rec(L) $wavelength
	}
	set $key $rec(L)
    }
}

proc NG1_psd_octave {id} {
    upvar \#0 $id rec

    set rec(detector,width)      4 ;# 4" detector
    set rec(detector,minbin)     1 ;# assume it is using all bins
    set rec(detector,maxbin)   256 ;# 
    set rec(detector,distance)  48 ;# detector bank is 48" away
    # set rec(detector,A4slope)     [expr {double($rec(stop,4)-$rec(start,4))/($rec(stop,3)-$rec(start,3))}]
    # set rec(detector,A4intercept) [expr {$rec(start,4)-$rec(detector,A4slope)*$rec(start,3)}]
    # octave send ::A3_$id A3_$id
    vector create ::psd_$id ::psderr_$id
    octave recv psd_$id psd_$id
    octave recv psderr_$id psderr_$id
}

proc NG1_psd_fvector {id} {
#    reflplot::normalize $id
#    set_center_pixel $id 250
    upvar #0 $id rec

    if {![info exists rec(column,A3)]} {
	set v {}
	for {set i 0} {$i < $rec(points)} {incr i} {
	    lappend v [expr {$rec(start,3) + $i * $rec(step,3)}]
	}
	fvector rec(column,A3) $v
    }

    if {![info exists rec(column,A4)]} {
	set v {}
	for {set i 0} {$i < $rec(points)} {incr i} {
	    lappend v [expr {$rec(start,4) + $i * $rec(step,4)}]
	}
	fvector rec(column,A4) $v
    }

    vector create ::A3_$id ::A4_$id
    ::A3_$id set [fvector rec(column,A3)]
    ::A4_$id set [fvector rec(column,A4)]

    reflplot::set_axes $id A3 A4

    if {[string match CG* $rec(instrument)]} {
	set rec(detector,minbin)      1 ;# doesn't use all the bins
	set rec(detector,maxbin)    608 ;# => 0.42mm spacing
	set rec(detector,width)     211.;# KOD says 0.34727 mm/pixel
	set rec(detector,distance) 1600.;# KOD says detector bank is 1.6m away
    } else {
	set rec(detector,minbin)      1 ;# doesn't use all the bins
	set rec(detector,maxbin)    256 ;# => 0.42mm spacing
	set rec(detector,width)    [expr {-4*25.4}] ;# reversed 4" detector
	set rec(detector,distance) [expr {36*25.4}] ;# detector bank is 3' away
    }

    set rec(pixels) [expr {$rec(detector,maxbin)-$rec(detector,minbin)+1}]
    set rec(distance) $rec(detector,distance)
    set rec(pixelwidth) [expr {$rec(detector,width)/$rec(pixels)}]

    reflplot::set_center_pixel $id [expr {$rec(pixels)/2.}]

    set v {}
    foreach el [fvector rec(column,A3)] { lappend v $rec(monitor) }
    fvector rec(column,monitor) $v
    reflplot::normalize $id monitor
}

# Generate a column from a motor specification if no column is recorded
# in the file.
proc motor_column { id motor column_name } {
    upvar \#0 $id rec
    set column ::${column_name}_${id}
    if {![vector_exists $column] && [info exists rec(start,$motor)]} { 
	vector create $column
	$column seq 1 $rec(points)
	$column expr "$rec(start,$motor) + ($column-1)*$rec(step,$motor)"
    }
}

# Convert slits from data columns or motor specifications measured in 20ths 
# of an inch into the standard slit columns measured in millimeters.
proc build_slit { id num motor column } {
    set slit "::slit${num}_${id}"
    motor_column $id $motor $column
    if { [vector_exists ::${column}_${id}] } {
	vector create $slit
	$slit expr "${column}_${id} * 25.4/20"
    }
}

# Load contents of id(file) into x_id, y_id, dy_id
# Set id(xlab) and id(ylab) as appropriate
proc NG1load {id} {
    upvar #0 $id rec

    if ![icp_load $id] { return 0 }
    if { [info exists rec(psdplot)] } { NG1_psd_fvector $id }

    if { [string match "CG*" $rec(instrument)] } { 
	set inst cg1
    } else {
	set inst ng1
    }

    check_wavelength $id [set ::${inst}wavelength]

    # Create slit1 and slit2 columns using the stored values if available
    # otherwise generating them from the motor movement specs in the header
    build_slit $id 1 1 A1
    build_slit $id 2 2 A2
    build_slit $id 3 5 A5
    build_slit $id 4 6 A6

    # Generate alpha, beta, Qx and Qz
    motor_column $id 3 A3
    motor_column $id 4 A4
    ::A3_$id dup ::alpha_$id
    ::A4_$id dup ::beta_$id
    AB_to_QxQz $id

    # Convert MIN column to time in seconds if available
    # FIXME do we need a time uncertainty vector as well?
    if { [vector_exists ::MIN_$id] } {
	vector create ::seconds_$id
	# time measured in seconds but recorded in hundredths of a minute
	::seconds_$id expr "round(::MIN_$id*60)"
	if { $rec(base) != "TIME" } {
	    # assume no uncertainty if counting against time.  If counting
	    # against monitor, the uncertainty is +/- a half second uniformly
	    # distributed, which can be approximated by a gaussian of width
	    # 1/sqrt(12)
	    vector create ::dseconds_$id
	    ::dseconds_$id expr "::seconds_$id*0 + 1./sqrt(12.)"
	}
    } elseif { $rec(base) == "TIME" } {
	vector create ::seconds_$id
	::seconds_$id expr "0*::counts_$id + $rec(mon)*$rec(prf)"
    } else {
	# No time information
	catch { vector destroy ::seconds_$id ::dseconds_$id }
    }

    # Exclude all points exceeding the saturation rate since 
    # the dead-time correction factor for the NG1 detector 
    # has not been measured.
    exclude_saturated $id [set ::${inst}saturation]


    # Create a monitor column if necessary
    if {[vector_exists ::MON_$id] } {
	::MON_$id dup ::monitor_$id
    } elseif {$rec(base) == "NEUT"} {
	vector create ::monitor_$id
	::monitor_$id expr "0*::counts_$id + $rec(mon)*$rec(prf)"
    }

    if {[vector_exists ::monitor_$id]} {
	vector create ::dmonitor_$id
	::dmonitor_$id expr "sqrt(::monitor_$id)"
    }

    switch $rec(type) {
	psd {
	    vector create ::x_$id
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	}
	psdstep {
	    vector create ::x_$id
	    ::x_$id seq 1 $rec(points)
	    set rec(xlab) "frame"
	}
	rock {
	    ::Qx_$id dup ::x_$id
	    set rec(Qrockbar) [expr [a3toQz $rec(rockbar) $rec(L)]]
	    set rec(xlab) "Qx ($::symbol(invangstrom))"
	}
	absorption {
	    ::alpha_$id dup ::x_$id
	    set rec(xlab) "A3 ($::symbol(degree))"
	}
	rock3 {
	    ::Qx_$id dup ::x_$id
            set rec(Qrockbar) [expr [a4toQz -$rec(rockbar) $rec(L)]]
            set rec(xlab) "Qx ($::symbol(invangstrom))"
	}
	spec {
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	    ::Qz_$id dup ::x_$id
	}
	slit - psdslit {
	    # XXX FIXME XXX if slit 1 is fixed, should we use slit 2?
	    set rec(xlab) "slit 1 opening (mm)"
	    ::slit1_$id dup ::x_$id
	}
	back {
	    exclude_specular_ridge $id
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	    set col $::background_basis($rec(dataset),$rec(instrument))
	    switch $col {
		A3 {
		    vector create ::x_$id
		    ::x_$id expr [ a3toQz $rec(A3) $rec(L) ]
		}
		A4 {
		    vector create ::x_$id
		    ::x_$id expr [ a4toQz $rec(A4) $rec(L) ]
		}
	    }
	}
	default { default_x $id }
    }
    set rec(ylab) [monitor_label $rec(base) $rec(monitor)]

    return 1
}

# Load contents of id(file) into x_id, y_id, dy_id
# Set id(xlab) and id(ylab) as appropriate
proc XRAYload {id} {
    upvar #0 $id rec

    if ![icp_load $id] { return 0 }
    # set rec(monitor) [expr {$rec(mon)*$rec(prf)}]
    check_wavelength $id $::xraywavelength

    switch $rec(type) {
	rock {
	    vector create ::x_$id
	    ::x_$id expr [ atoQx ::A3_$id [expr {2*$rec(rockbar)}] $rec(L) ]
	    set rec(Qrockbar) [expr [a3toQz $rec(rockbar) $rec(L)]]
	    set rec(xlab) "Qx ($::symbol(invangstrom))"
	}
	absorption {
	    ::A3_$id dup ::x_$id
	    set rec(xlab) "A3 ($::symbol(degree))"
	}
	spec {
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	    vector create ::x_$id
	    ::x_$id expr [ a4toQz ::A4_$id $rec(L) ]
	}
	back {
	    exclude_specular_ridge $id
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	    set col $::background_basis($rec(dataset),$rec(instrument))
	    switch $col {
		A3 { 
		    vector create ::x_$id
		    ::x_$id expr [ a3toQz ::A3_$id $rec(L) ] 
		}
		A4 {
		    vector create ::x_$id
		    ::x_$id expr [ a4toQz ::A4_$id $rec(L) ]
		}
	    }
	}
	default { default_x $id }
    }
    set rec(ylab) [monitor_label $rec(base) $rec(monitor)]
    return 1
}

set ::NG7_monitor_calibration_loaded 0
proc load_NG7_monitor_calibration {} {
    if { $::NG7_monitor_calibration_loaded } { return }

    # read the monitor calibration data
    set filename NG7monitor.cal
    if { [catch {open [file join $::VIEWRUN_HOME $filename]} fid] } {
	message "Unable to load NG7 monitor calibration $filename"
	# no monitor correction
	set ::NG7_monitor_calibration { 0\t1\n1e100\t1 }
    } else {
	set ::NG7_monitor_calibration [read $fid]
	close $fid
    }

    # Send it to octave.  Use constant extrapolation beyond the
    # xrange read from the file.
    # XXX FIXME XXX confirm what to do when counts/second exceeds 31000
    # We extend the correction at the maximum rate.  Should we also
    # mark these points for exclusion?
    set data [string map { "\n" " " } $::NG7_monitor_calibration]
    octave eval "NG7monitor=sscanf('$data', '%f ', Inf)"
    octave eval {
	NG7monitor = reshape(NG7monitor,2,length(NG7monitor)/2)';
	if NG7monitor(1,1) != 0
	  NG7monitor = [0, NG7monitor(1,2); NG7monitor];
	endif
	n = length(NG7monitor);
	if NG7monitor(n,1) < 1e100
	  NG7monitor = [NG7monitor; 1e100, NG7monitor(n,2)];
	endif
    }
    set ::NG7_monitor_calibration_loaded 1
}

proc NG7monitor_calibration {id} {
    if { [vector_exists ::monitor_$id]} {
	# XXX FIXME XXX if there are 0 monitor counts in a bin for some 
	# reason then this section will fail.  Find some way to make it
	# fail cleanly.

	load_NG7_monitor_calibration

	# convert monitor counts and monitor time to monitor rate
	# XXX FIXME XXX what to do with 0 monitor counts
	octave send ::seconds_$id seconds
 	octave send ::monitor_$id monitor
	octave eval {
	    dmonitor = sqrt(monitor);
	    rate = monitor./seconds;
            # XXX FIXME XXX what's the uncertainty on the monnl interpolation?
	    correction = interp1(NG7monitor(:,1), NG7monitor(:,2), rate);
	    monitor = monitor .* correction;
	    dmonitor = dmonitor .* correction;
	    monitor(monitor==0) = 1;
	}
	vector create ::monitor_$id ::dmonitor_$id
	octave recv monitor_$id monitor
	octave recv dmonitor_$id dmonitor
	octave sync
    }
}


proc NG7_psd_fvector {id} {
    upvar #0 $id rec
    vector create ::QZ_$id theta twotheta
    ::QZ_$id set [fvector rec(column,QZ)]
    theta expr asin(::QZ_$id*$rec(L)/$::pitimes4)/$::piover180
    # XXX FIXME XXX can NG7 have Qx!=0 with PSD?
    twotheta expr 2*theta
    fvector rec(column,Theta) $theta(:)
    fvector rec(column,TwoTheta) $twotheta(:)
    vector destroy theta twotheta
    reflplot::set_axes $id Theta TwoTheta

    set rec(detector,width)       -100.;# 10cm detector, reverse pixel order
    set rec(detector,minbin)         9 ;# doesn't use all the bins
    set rec(detector,maxbin)       246 ;# => 0.42mm spacing
    set rec(detector,distance)    2000.;# detector bank is 2m away

    set rec(pixels)     256
    set rec(distance)   $rec(detector,distance)
    set rec(pixelwidth) [expr {$rec(detector,width)/($rec(detector,maxbin)-$rec(detector,minbin)+1.)}]
    reflplot::set_center_pixel $id 128

    reflplot::normalize $id MON
}

# Load contents of id(file) into x_id, y_id, dy_id
# Set id(xlab) and id(ylab) as appropriate
proc NG7load {id} {
    upvar #0 $id rec

    if ![icp_load $id] { return 0 }
    if {$rec(psdplot)} { NG7_psd_fvector $id }
    check_wavelength $id $::ng7wavelength
    
    # Build standard vectors S1,S2,S3
    build_slit $id 1 S1 S1
    build_slit $id 2 S2 S2
    build_slit $id 3 S3 S3
    build_slit $id 4 S4 S4
    
    # Build Qx,Qz,alpha,beta
    motor_column $id Qx QX
    motor_column $id Qz QZ
    if {[vector_exists ::QX_${id}]} { ::QX_${id} dup ::Qx_$id }
    if {[vector_exists ::QZ_${id}]} { ::QZ_${id} dup ::Qz_$id }
    QxQz_to_AB $id

    # Build time vector from header specification
    if { [vector_exists ::Qz_$id] } {
	vector create ::seconds_${id}
	::seconds_${id} expr "$rec(prf)*($rec(mon)+$rec(Mon1)*abs(::Qz_$id)^$rec(Exp))"
    }

    if { [vector_exists ::MON_$id] } {
	::MON_$id dup ::monitor_$id
    } else {
	message "$rec(file) has no monitor counts"
    }

    if { [vector_exists ::Qz_$id] } {
	octave send ::Qz_$id Qz
	octave send ::seconds_$id seconds
    }
    
    # monitor calibration
    NG7monitor_calibration $id

    if { [vector_exists ::monitor_$id] } {
        if { $rec(psd) } {
	    set rec(detector,width)      10 ;# 10cm detector
	    set rec(detector,minbin)      9 ;# doesn't use all the bins
	    set rec(detector,maxbin)    246 ;# => 0.42mm spacing
	    set rec(detector,distance)  200 ;# detector bank is 2m away
	    # set rec(detector,A4slope)     2 ;# XXX FIXME XXX these depend on
	    # set rec(detector,A4intercept) 0 ;# motor 13 and motor Qx but how?
	    # octave eval "A3_$id = asin(($rec(L)/(4*pi))*Qz)"
            octave eval "
                monitor = monitor * ones(1,columns(psd_$id));
                dmonitor = dmonitor * ones(1,columns(psd_$id));
                psderr_$id = sqrt ( (psderr_$id./monitor) .^ 2 + ...
                                (psd_$id.*dmonitor./monitor.^2) .^ 2 );
                psd_$id = psd_$id ./ monitor;
            "

            vector create ::psd_$id ::psderr_$id
            octave recv psd_$id psd_$id
            octave recv psderr_$id psderr_$id
        } else {
	    ::dy_$id expr "sqrt((::dy_$id/::monitor_$id)^2 + \
                (::y_$id*::dmonitor_$id/::monitor_$id^2)^2)"
	    ::y_$id expr "::y_$id/::monitor_$id"
	}
    }

    switch $rec(type) {
	psd {
	    vector create ::x_$id
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	}
	psdstep {
	    vector create ::x_$id
	    ::x_$id seq 1 $rec(points)
	    set rec(xlab) "frame"
	}
	rock {
	    ::13_$id dup ::x_$id
	    set rec(Qrockbar) $rec(start,Qz)
	    set rec(xlab) "Qx (motor 13 units)"
	}
	spec {
	    ::QZ_$id dup ::x_$id
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	    set rec(slit) S1_$id
	}
	slit - psdslit {
	    ::S1_$id dup ::x_$id
	    set rec(xlab) "slit 1 opening (mm)"
	}
	height {
	    ::12_$id dup ::x_$id
	    set rec(xlab) "height (motor 12 units)"
	}
	back {
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	    ::QZ_$id dup ::x_$id
	    set rec(slit) S1_$id
	}
	default { default_x $id }
    }
    set rec(ylab) [monitor_label $rec(base) $rec(monitor)]

    return 1
}

proc parse1 {line} {
    upvar rec rec
    # The top line of an ICP file looks like the following:
    #   'Filename' 'Date' 'Scan' Mon Prf 'Base' #pts 'Type'
    # If we split on a single quote, we get the following list:
    #   {{} Filename { } Date { } Scan { Mon Prf } Base { #pts } Type {}}
    # We then map this list onto varibles as follows:
    #     a  rec()    b  date  c  rec()     d      rec()    e     f   g
    foreach { a rec(internal_name) b date \
	    c rec(scantype) d rec(base) \
	    e f g } [split $line "'"] break
    # Parse the date appropriately
    if {[catch { clock_scan $date } rec(date)]} {
	message "clock scan fails for $date: $rec(date)"
	#puts $rec(date)
	set rec(date) 0
    }
    # Remove the extra spaces from around the values
    foreach { rec(mon) rec(prf) rec(pts) } "$d $e" break
}

proc parse2ng1 {line} {
    upvar rec rec
    foreach { a b c d e f g rec(L) rec(T) rec(dT) rec(H) rec(\#Det) Hconv dH} \
	$line break
    set rec(monitor) [expr {$rec(mon)*$rec(prf)}]
}

proc parse2ng7 {line} {
    upvar rec rec
    foreach { rec(Mon1) rec(Exp) rec(Dm) rec(L) rec(T) rec(dT) rec(H) \
	    rec(\#Det) rec(SclFac) } $line break
    set rec(monitor) 1.0
}



# MACRO loadhead
# - defines lines as the head lines of the file
# - calling procedure automatically returns if there is an error
# - creates a new record
# naughty, yes, but hopefully fast.
proc loadhead {file} {
    # Slurp file header.  An ICP header is than 15 lines, so 1200
    # bytes is more than enough.
    if [catch {open $file r} fid] {
	message $fid
	return -code return
    }
    set text [read $fid 2048] 
    if {[string match \#ICE* $text]} {
	::icedata::mark $file $fid $text
	close $fid
	return -code return
    }
    close $fid

    # if it has a motor line, then assume the format is good
    set offset [ string first "\n Mot: " $text]
    if { $offset < 0 } {
	# puts "couldn't find Mot: line in $file";
	return -code return
    }
    set lines [split [string range $text 0 [incr offset -1]] "\n"]

    # create a new record
    upvar #0 [new_rec $file] rec

    # assign run# and dataset
    foreach {rec(dataset) rec(run)} [splitname [file tail $file]] { break }

    # parse the header1 line putting the fields into "rec"
    parse1 [lindex $lines 0] ;# grab record variables from line 1

    # parse the comment line (ICP limits comments to 50 characters)
    set commentline [lindex $lines 2]
    set rec(comment) [string trim [string range $commentline 0 49]]

    # parse polarization indicator
    set polarization [string range $commentline 50 end]
    if { [regexp {F1: *(ON|OFF) *F2: *(ON|OFF)} $polarization -> f1 f2] } {
	switch $f1$f2 {
	    OFFOFF { set rec(polarization) A }
	    ONOFF { set rec(polarization) B }
	    OFFON { set rec(polarization) C }
	    ONON { set rec(polarization) D }
	}
    } else {
	set rec(polarization) {}
    }

    # parse the motor lines
    upvar fixed fixed
    set fixed 1
    foreach line [lrange $lines 5 end] {
	foreach { name start step stop } $line {
	    set rec(stop,$name) $stop
	    # make sure start is before end
	    # (you can tell if is backward from step)
	    # XXX FIXME XXX rename start/stop to lo/hi
	    if { $start <= $stop } {
		set rec(start,$name) $start
		set rec(step,$name) $step
		set rec(stop,$name) $stop
	    } else {
		set rec(start,$name) $stop
		set rec(step,$name) $step
		set rec(stop,$name) $start
	    }
	    if { $start != $stop } { set fixed 0 }
	}
    }

    # Check for psd: a comma in the data section indicates psd data
    set rec(psd) [expr {[string first , $text $offset]> 0}]

    # return the header2 line
    upvar header2 header2
    set header2 [lindex $lines 3]
    return $rec(id)
}

proc runtime {id} {
    # XXX FIXME XXX this will fail if some datasets count against
    # NEUT and others against TIME in the same dataset.
    upvar #0 $id rec
    return [expr {$rec(monitor)*$rec(prf)*$rec(pts)}]
}

proc XRAYmark {file} {
    # loadhead is a naughty function: it defines "rec", "m*" and "header2" in
    # our scope. If there is an error it causes us to return.
    set id [loadhead $file]
    upvar #0 $id rec
    set rec(load) XRAYload

    # parse2... parses the second set of fields into "rec".
    parse2ng1 $header2

    # instrument specific initialization
    set rec(instrument) [XR0info instrument]

    # based on motor movements, guess the type of the experiment
    if { ![info exists rec(start,3)] || ![info exists rec(start,4)] } {
	marktype ?
    } elseif { $rec(start,4) == 0.0 && $rec(stop,4) == 0.0 && $fixed } {
	# direct beam with no motors moving => intensity measurement
	marktype slit $rec(start,1) $rec(stop,1) $rec(polarization)
    } elseif { $fixed } {
	marktype time 0 [runtime $id]
    } elseif { $rec(start,4) == 0.0 && $rec(stop,4) == 0.0 && \
		   $rec(step,3) != 0.0 } {
	marktype absorption $rec(start,3) $rec(stop,3)
    } elseif { $rec(step,4) == 0.0 } {
	set rec(rockbar) [expr $rec(start,4)/2.]
	marktype rock $rec(start,3) $rec(stop,3)
    } elseif { abs($rec(stop,4) - 2.0*$rec(stop,3)) < 1e-10 } {
	marktype spec $rec(start,4) $rec(stop,4)
    } elseif { abs($rec(step,4) - 2.0*$rec(step,3)) < 1e-10 } {
	# offset background
	set m [string index $::background_default 1]
	set rec(A3) ::A3_$rec(id)
	set rec(A4) ::A4_$rec(id)
	if { $rec(start,4) > 2.0*$rec(start,3) } {
	    marktype back $rec(start,4) $rec(stop,4) +
	} else {
	    marktype back $rec(start,4) $rec(stop,4) -
	}
	set ::background_basis($rec(dataset),$rec(instrument)) \
		$::background_default
    } else {
	# mark anything else as some sort of background for now
	marktype back $rec(start,4) $rec(stop,4)
    }
}

# XXX FIXME XXX we only need the motors to determine the file type
# and display the data range bar.  So we can delay parsing the header
# until later.  Later in this case is when we try [addrun matches] since
# that's when we need temperature and field.  When we actually load the
# data for graphing is when we will need other fields like monitor and
# comment.
proc NG1mark {file} {
    # loadhead is a naughty function: it defines "rec", "m*" and "header2" in
    # our scope. If there is an error it causes us to return.
    set id [loadhead $file]
    upvar #0 $id rec
    set rec(load) NG1load

    # parse2... parses the second set of fields into "rec".
    parse2ng1 $header2

    # instrument specific initialization
    # icky hack to determine CG1/NG1 polarized/non-polarized
    switch -- [string index $rec(internal_name) end-2] {
	n - N {
	    if { $rec(polarization) eq "" } {
		set rec(instrument) [NG1info instrument]
	    } else {
		set rec(instrument) [NG1Pinfo instrument]
	    }
	}
	c - C {
	    if { $rec(polarization) eq "" } {
		set rec(instrument) [CG1info instrument]
	    } else {
		set rec(instrument) [CG1Pinfo instrument]
	    }
	}
	default {
	    error "expected internal file name of *.C?1 or *.N?1"
	}
    }
    #if { $rec(psd) } { append rec(instrument) "PSD" }

    # based on motor movements, guess the type of the experiment
    if { ![info exists rec(start,1)] || ![info exists rec(start,3)] \
	    || ![info exists rec(start,4)] } {
	marktype ? 0 0 $rec(polarization)
    } elseif { $rec(psd) } { 
	if { $rec(step,3) != 0.0 } {
	    marktype psd \
		[expr [a3toQz $rec(start,3) $rec(L)]] \
		[expr [a3toQz $rec(stop,3) $rec(L)]] \
		$rec(polarization)
	} elseif { !$fixed } {
	    marktype psdslit $rec(start,1) $rec(stop,1) $rec(polarization)
	} else {
	    marktype psdstep 1 $rec(pts) $rec(polarization)
	}
    } elseif { $rec(start,4) == 0.0 && $rec(stop,4) == 0.0 \
		   && ($fixed || $rec(step,1) != 0.0) } {
	# direct beam with no motors moving => slit measurement
	# direct beam with spreading slits => slit scan
	marktype slit $rec(start,1) $rec(stop,1) $rec(polarization)
    } elseif { $rec(start,4) == 0.0 && $rec(stop,4) == 0.0 \
		   && $rec(step,3) != 0.0 } {
	# direct beam with rotating A3 and fixed slits => absorption scan
	marktype absorption $rec(start,3) $rec(stop,3) $rec(polarization)
    } elseif { $rec(step,3) == 0.0 && $rec(step,4) == 0.0 } {
	marktype time 0 [runtime $id] $rec(polarization)
    } else {
	# XXX FIXME XXX check if still using slit constraints in run_matches
	if { $rec(start,3) == $rec(stop,3) } {
	    # XXX FIXME XXX why not use slits when motor 3 is fixed?
	    set rec(slits) {}
	} else {
	    set rec(slits) { 1 2 5 6 }
	}

	if { $rec(step,4) == 0.0 } {
	    set rec(rockbar) [expr $rec(start,4)/2.]
	    marktype rock $rec(start,3) $rec(stop,3) $rec(polarization)
	} elseif { $rec(step,3) == 0.0 } {
	    set rec(rockbar) $rec(start,3)
	    marktype rock3 $rec(start,4) $rec(stop,4) $rec(polarization)
	} elseif { abs($rec(stop,4) - 2.0*$rec(stop,3)) <= 2e-5 } {
	    marktype spec $rec(start,3) $rec(stop,3) $rec(polarization)
	} else {
	    # use default background basis
	    set m [string index $::background_default 1]
	    set rec(A3) ::A3_$rec(id)
	    set rec(A4) ::A4_$rec(id)
	    if { $rec(stop,4) > 2.0*$rec(stop,3) } {
		marktype back $rec(start,$m) $rec(stop,$m) +$rec(polarization)
	    } else {
		marktype back $rec(start,$m) $rec(stop,$m) -$rec(polarization)
	    }
	    set ::background_basis($rec(dataset),$rec(instrument)) \
		    $::background_default
	}
#	elseif { abs($rec(step,4) - 2.0*$rec(step,3)) < 1e-10 } {
#	    # offset background
#	    if { $rec(stop,4) > 2.0*$rec(stop,3) } {
#		marktype back $rec(start,4) $rec(stop,4) $rec(polarization)+
#	    } else {
#		marktype back $rec(start,4) $rec(stop,4) $rec(polarization)-
#	    }
#	} else {
#	    # mark anything else as some sort of background for now
#	    marktype back $rec(start,4) $rec(stop,4) $rec(polarization)
#	}
    }

}

proc NG7mark {file} {
    # loadhead is a naughty function: it defines "rec", "m*" and "header2" in
    # our scope. If there is an error it causes us to return.
    set id [loadhead $file]
    upvar #0 $id rec
    set rec(load) NG7load

    # NG-7 always counted against monitor
    set rec(base) "NEUT"

    # parse2... parses the second set of fields into "rec".
    parse2ng7 $header2

    # instrument specific initialization
    set rec(instrument) [NG7info instrument]
#    if { $rec(psd) } { append rec(instrument) "PSD" }

    # based on motor movements, guess the type of the experiment
    if { ![info exists rec(start,Qz)] || ![info exists rec(start,S1)] } {
	marktype ?
    } elseif { $rec(psd) } {
	marktype psd $rec(start,Qz) $rec(stop,Qz)
    } elseif { $fixed } {
	marktype time 0 [runtime $id]
    } elseif { [info exists rec(start,13)] && $rec(step,13) != 0. } {
	if { $rec(start,Qz) == $rec(stop,Qz) } {
	    set rec(rockbar) $rec(start,Qz)
	    marktype rock $rec(start,13) $rec(stop,13)
	} else {
	    if { $rec(step,13) > 0 } {
		marktype back $rec(start,Qz) $rec(stop,Qz) +
	    } else {
		marktype back $rec(start,Qz) $rec(stop,Qz) -
	    }
	}
    } elseif { [info exists rec(start,12)] } {
	marktype height $rec(start,12) $rec(stop,12)
    } elseif { [info exists rec(start,S1)] } {
	if { $rec(start,Qz) != 0.0 || $rec(stop,Qz) != 0.0 } {
	    marktype spec $rec(start,Qz) $rec(stop,Qz)
	} else {
	    marktype slit $rec(start,S1) $rec(stop,S1)
	}
    } else {
	marktype ?
    }
}


set ::app_version "[clock format [clock seconds] -format %Y%m%d]-CVS"

init_cmd {
    register_icp
    register_uxd
    register_reduced
    register_raw
}
set ::title Reflred

# XXX FIXME XXX how can I make this automatic?
set OCTAVE_SUPPORT_FILES {
    psdslice reduce reduce_part run_invscale
    run_div run_include run_interp run_poisson_avg
    run_scale run_sub run_tol run_trunc 
    runlog run_send run_send_pol fitslits polcor
    common_values inputname polyconf qlfit wsolve
    confidence qlconf wpolyfit interp1err
}

set ::scanpattern "S\[0-9]*"
set ::recpattern "R\[0-9]*"
init_cmd { set ::background_default "A3" }

# Delay starting octave as long as possible
init_cmd {
    rename octave octave_orig
    proc octave {args} {
	rename octave {}
	rename octave_orig octave
	restart_octave
	eval octave $args
    }
}

# process command line args, if any
if { [ string match $::argv "-h" ] } {
    puts "usage: $::argv0 \[data directory]"
    exit
}

proc initial_pattern {} {
    if { $::argc == 0 } {
	set pattern {{}}
    } else {
	set pattern $::argv
    }

    # load the initial directory (as set by the command line arguments if any)
    catch {
	if {[llength $pattern] == 1 && $pattern ne "{}"} {
	    if {[file isdir $pattern]} {
		cd $pattern
		set pattern {{}}
	    } else {
		cd [file dir $pattern]
		set pattern [list [file tail $pattern]]
	    }
	}
    }

    return $pattern
}

# useful constants
set ::log10 [expr {log(10.)}]
set ::pi [expr {4*atan(1.)}]
set ::pitimes16 [expr {64*atan(1.)}]
set ::pitimes4 [expr {16.*atan(1.)}]
set ::pitimes2 [expr {8.*atan(1.)}]
set ::piover360 [ expr {atan(1.)/90.}]
set ::piover180 [ expr {atan(1.)/45.}]
proc a3toQz {a3 lambda} {
    return "$::pitimes4*sin($a3*$::piover180) / $lambda"
}
proc a4toQz {a4 lambda} {
    return "$::pitimes4*sin($a4*$::piover360) / $lambda"
}

proc AB_to_QxQz {id} {
    upvar \#0 $id rec

    vector create ::Qx_$id ::Qz_$id
    ::Qz_${id} expr "$::pitimes2/$rec(L)*(sin($::piover180*(::beta_$id-::alpha_$id))+sin($::piover180*::alpha_$id))"
    ::Qx_${id} expr \
	"$::pitimes2/$rec(L)*(cos($::piover180*(::beta_$id-::alpha_$id))-cos($::piover180*::alpha_$id))"
}

proc QxQz_to_AB {id} {
    upvar \#0 $id rec

    # Algorithm for converting Qx-Qz to alpha-beta:
    #   beta = 2 asin(L/(2 pi) sqrt(Qx^2+Qz^2)/2) * 180/pi
    #        = asin(L sqrt(Qx^2+Qz^2) /(4 pi)) / (pi/360)
    #   if Qz < 0, negate beta
    #   theta = atan2(Qx,Qz) * 180/pi
    #   if theta > 90, theta -= 360
    #   alpha = theta + beta/2
    #   if Qz < 0, alpha += 180
    vector create ::alpha_$id ::beta_$id
    ::beta_$id expr "asin($rec(L)*sqrt(::Qx_$id^2+::Qz_$id^2)/$::pitimes4)/$::piover360"
    ::beta_$id expr "::beta_$id*(::Qz_$id>=0) - ::beta_$id*(::Qz_$id<0)"
    ## No atan2 in BLT so replace <<
    #    ::alpha_$id expr "atan2(::Qx_$id,::Qz_$id)/$::piover180)"
    # >> with <<
    set y ::Qx_$id
    set x ::Qz_$id
    ::alpha_$id expr "atan($y/($x+!$x*1e-100)) + $::pi*($x<0)*$y/abs($y+!$y)"
    ::alpha_$id expr "::alpha_$id/$::piover180"
    # >>

    ::alpha_$id expr "::alpha_$id - 360*(::alpha_$id>90) + ::beta_$id/2"
    ::alpha_$id expr "::alpha_$id + 180*(::Qz_$id<0)"
}

# exclude all points in the record $id for which 2*alpha != beta
proc exclude_specular_ridge {id} {
    upvar #0 $id rec
    ::idx_$id expr "::idx_$id && (2*::alpha_$id != ::beta_$id)"
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

monitor_init

# ======================================================


proc restart_octave {} {
    catch { octave close }
    octave connect $::OCTAVE_HOST
    #octave eval "cd /tmp;"
    foreach file $::OCTAVE_SUPPORT_FILES {
	octave mfile [file join $::VIEWRUN_HOME octave $file.m]
    }
    foreach ext { x y dy m } {
	foreach id [vector names ::${::scanpattern}_$ext] {
	    octave send $id [string map { : {} _ . } $id]
	}
    }
    set ::NG7_monitor_calibration_loaded 0
}
proc disp x {
    octave eval { retval='\n'; }
    octave eval "retval=$x;"
    octave eval { send(sprintf('set ::ans {%s}',disp(retval))); }
    vwait ::ans
    return [string range $::ans 0 end-1]
}

proc write_data { fid data args} {

    set log 0
    set pol {}
    set columns {x y dy}
    set names {}
    foreach {option value} $args {
	switch -- $option {
	    -log { set log [string is true $value] }
	    -pol { set pol $value }
	    -columns { set columns $value }
	    -names { set names $value }
	}
    }
    if { [llength $names] == 0} { set names $columns }
    if { $log } {
	# Munge names of y,dy to logy,dlogy
	set names [lreplace $names 1 1 "log[lindex $names 1]"]
	set names [lreplace $names 2 2 "dlog[string range [lindex $names 2] 1 end]"]
    }
    puts $fid "#columns $names"

    set Vx [set ${data}_[lindex $columns 0]${pol}(:)]
    set Vy [set ${data}_[lindex $columns 1]${pol}(:)]
    set Vdy [set ${data}_[lindex $columns 2]${pol}(:)]
    if { [llength $columns] == 4 } {
	set Vm [set ${data}_[lindex $columns 3]${pol}(:)]
    }

    if { [llength $columns] == 4  && $log } {
	foreach x $Vx y $Vy dy $Vdy m $Vm {
	    if { $y <= $dy/1000. } {
		puts $fid "# $x ln($y)/ln(10) ($dy/$y)/ln(10) $m"
	    } else {
		set logdy [expr $dy / ($::log10*$y)]
		set logy [expr log($y) / $::log10 ]
		puts $fid "$x $logy $logdy $m"
	    }
	}
    } elseif { [llength $columns] == 4 } {
	foreach x $Vx y $Vy dy $Vdy m $Vm {
	    if { $::clip_data && $y <= 0. } {
		puts $fid "# $x $y $dy $m"
	    } else {
		puts $fid "$x $y $dy $m"
	    }
	}
    } elseif { $log } {
	foreach x $Vx y $Vy dy $Vdy {
	    if { $y <= $dy/1000. } {
		puts $fid "# $x ln($y)/ln(10) ($dy/$y)/ln(10)"
	    } else {
		set logdy [expr $dy / ($::log10*$y)]
		set logy [expr log($y) / $::log10 ]
		puts $fid "$x $logy $logdy"
	    }
	}
    } else {
	foreach x $Vx y $Vy dy $Vdy {
	    if { $::clip_data && $y <= 0. } {
		puts $fid "# $x $y $dy"
	    } else {
		puts $fid "$x $y $dy"
	    }
	}
    }
}

proc write_scan { fid scanid } {
    # FIXME duplicates write_reduce in reduce.tcl
    # Can't replace it yet because data is not marked with the polarization
    # crosssection (the vectors are e.g., S1_x S1_y S1_dy instead of
    # S1_xA S1_yA S1_dyA).
    upvar #0 $scanid rec
    puts $fid "#RRF 1 1 $::app_version"
    puts $fid "#date [clock format $rec(date) -format %Y-%m-%d]"
    puts $fid "#title \"$rec(comment)\""
    puts $fid "#instrument $rec(instrument)"
    puts $fid "#monitor $rec(monitor)"
    puts $fid "#temperature $rec(T)"
    if { [info exists rec(Tavg)] } {
	puts $fid "#average_temperature $rec(Tavg)"
    }
    puts $fid "#field $rec(H)"
    puts $fid "#wavelength $rec(L)"
    puts $fid "#$rec(type) $rec(files)"
    if { [info exists rec(polarization)] && $rec(polarization) ne {} } {
	puts $fid "#polarization $rec(polarization)"
    }
    switch $rec(type) {
	spec - back {
	    set columns {x y dy m}
	    set names {Qz counts dcounts slit1}
	}
	refl {
	    set columns {x y dy m}
	    set names {Qz R dR slit1}
	}
	slit {
	    set columns {x y dy}
	    set names {slit1 counts dcounts}
	}
	default {
	    set columns {x y dy}
	    set names {x y dy}
	}
    }
    write_data $fid ::$scanid -columns $columns -names $names
}

proc savescan { scanid } {
    upvar #0 ::$scanid rec
    set filename [file rootname $rec(file)].$rec(type)$rec(index)
    if { [file exists $filename] &&
	 ![question "$filename exists. Do you want to overwrite it?"] } {
	return
    }

    if { [catch { open $filename w } fid] } {
	message -bell $fid
    } else {
	if { [catch { write_scan $fid $scanid } msg] } {
	    message -bell $msg
	} else {
	    message "Saving data in $filename"
	}
	close $fid
    }
}

# XXX FIXME XXX what do we do when we are running without reduce?
# should setscan call reduce_newscan directly or what?
init_cmd { set ::scancount 0 }
proc setscan { runs } {
    # XXX FIXME XXX do we need an error message here?
    if { [llength $runs] == 0 } { error "no runs" }

    # Records are created in dictionary order, so sorting by record
    # number sorts by dictionary order (with 'other' files pushed to
    # the end).  Mostly, things within the same dataset will work
    # fine.  There may be problems if data comes from multiple datasets
    # so users will have to be sure to override the names if that is
    # the case.
    set runs [lsort -dictionary $runs]

    upvar #0 [lindex $runs 0] rec
    set name "$rec(dataset)-$rec(run)$rec(index)"
    if [info exists ::scanindex($name)] {
	set scanid $::scanindex($name)
	# XXX FIXME XXX scan names are not unique!!  If the type or
	# comment has changed, then we will have to remove and reinsert
	# the scan in the reduce box lists.
    } else {
	# scanid must be a valid octave name and blt vector name
	set scanid S[incr ::scancount]
	# XXX FIXME XXX this should be the user editted comment for the
	# scan. It should maybe be a property of addrun rather than the
	# record since it is conceivable that a new scan would be
	# created having the same header, but different runs and different
	# comment.  If the comment has changed, then this should be reflected
	# in the reduce box lists.
	array set ::$scanid [array get rec]
	array set ::$scanid [list \
				 id $scanid name $name \
				 runs $runs \
				]
	set ::scanindex($name) $scanid

	# XXX FIXME XXX need a better way to change scan types
	if [string equal $rec(type) "other"] {
	    array set ::$scanid { type spec }
	}

    }
    upvar #0 $scanid scanrec

    # need to recalculate since the run list may have changed
    octave eval "$scanrec(id)=\[];"
    set scanrec(files) {}
    foreach id $runs {
	upvar #0 $id rec
	octave eval "r=\[];"

	# data (already includes attenuator)
	octave send ::x_${id} r.x
	octave send ::y_${id} r.y
	octave send ::dy_${id} r.dy

	# monitor
	octave eval "r = run_scale(r,$scanrec(monitor));"

	# slit motor position if available
	if {[vector_exists ::slit1_$id] && !($rec(type) == "slit")} {
	    octave send ::slit1_$id r.m
	}

	# remove exclusions (and generate note for the log)
	if {[vector_exists ::idx_$id] && [vector expr "prod(::idx_$id)"]==0} {
	    octave send ::idx_${id} idx
	    octave eval { r = run_include(r,idx); }
	    set exclude " \[excluding 0-origin [::idx_$id search 0]]"
	} else {
	    set exclude ""
	}

	# append run
	octave eval "$scanid = run_poisson_avg($scanid,r);"

	# pretty scale
	if { $rec(k) == 1 && $rec(dk) == 0 } {
	    set scale {}
	} elseif { $rec(dk) == 0 } {
	    set scale "*$rec(k)"
	} else {
	    set scale "*$rec(k)($rec(dk))"
	}

	# list file with scale and exclusions in the log
	lappend scanrec(files) "[file tail $rec(file)]$scale$exclude"
    }
    vector create ::${scanid}_x ::${scanid}_y ::${scanid}_dy
    octave recv ${scanid}_x ${scanid}.x
    octave recv ${scanid}_y ${scanid}.y
    octave recv ${scanid}_dy ${scanid}.dy
    # slit motor position, if defined for all sections, will be in 'm'
    octave eval "if isfield(${scanid},'m'), send('${scanid}_m',${scanid}.m); end"
    vector create ::${scanid}_ky
    vector create ::${scanid}_kdy
    octave sync

    reduce_newscan $scanid
    return $scanid
}

proc Q4_scale_vector { x y dy } {
    vector create S
    S expr "(abs($x)<=$::Q4_cutoff)*$::Q4_cutoff + (abs($x)>$::Q4_cutoff)*$x"
    S expr "(S/$::Q4_cutoff)^4"
    $y expr "$y*S"
    $dy expr "$dy*S"
}

proc Q4_unscale_point {x args} {
    if {abs($x) <= $::Q4_cutoff} { set x $::Q4_cutoff }
    set S [expr {pow(abs($x)/$::Q4_cutoff,4)}]
    set ret {}
    foreach y $args { lappend ret [expr {$y / $S}] }
    return $ret
}

proc Fresnel {Q} {
    set Qsq [expr {$Q*$Q}]
    if { $Q < 0. } {
	if { $Qsq <= -$::Fresnel_Qcsq } {
	    set F 1.
	} else {
	    set F [expr {sqrt($::Fresnel_Qcsq - $Qsq)}]
	    set F [expr {($Q + $F)/($Q - $F)}]
	}
    } else {
	if { $Qsq <= $::Fresnel_Qcsq } {
	    set F 1.
	} else {
	    set F [expr {sqrt($Qsq - $::Fresnel_Qcsq)}]
	    set F [expr {($Q - $F)/($Q + $F)}]
	}
    }
    return [expr {$F*$F}]
}

proc Fresnel_scale_vector { Qvec y dy } {
    set Flist {}
    foreach Q [set ${Qvec}(:)] { lappend Flist [Fresnel $Q] }

    vector create Fvec
    Fvec set $Flist
    $y expr "$y/Fvec"
    $dy expr "$dy/Fvec"
    vector destroy Fvec
}

proc Fresnel_unscale_point {Q args} {
    set F [Fresnel $Q]
    set ret {}
    foreach y $args { lappend ret [expr {$y * $F}] }
    return $ret
}

proc pretty_slit { m b } {
    if { $m == 0.0 } {
	return $b;
    } elseif { $b == 0.0 } {
	return "[fix $m] theta"
    } elseif { $b < 0.0 } {
	return "[fix $m] theta - [expr -$b]"
    } else {
	return "[fix $m] theta + $b"
    }
}

proc slit_ratio { id slit Q } {
    upvar #0 $id rec
    if { [info exists rec($slit)] && [info exists rec($Q)] } {
	set slope [expr double($rec(stop,$slit) - $rec(start,$slit))/($rec(stop,$Q)-$rec(start,$Q))]
	set intercept [expr $rec(start,$slit) - $slope*$rec(start,$Q)]
    } else {
	set slope NaN
	set intercept NaN
    }
    return [list $slope $intercept]
}

proc compare_slits { baseid thisid } {
    upvar #0 $baseid base
    upvar #0 $thisid this

    error "compare slits is not yet implemented"
    # XXX FIXME XXX this is old code.  The new code will have to call
    # slit_ratio itself (maybe caching the result).  Note that the
    # ratio will be based on motor 3 in some cases and motor 4 in others
    # (for NG1).  Fixed slits and variable slits should be allowed to
    # overlap (at least at one point).  Ideally, slits would only be
    # checked for the overlapping region.
    if { [info exists base(slits)] != [info exists this(slits)] } {
	return "internal error --- missing slit ratio for $base(file) or $this(file)"
    }
    if { [info exists base(slits)] } {
	foreach slit $base(slits) {
	    if { abs($base_m-$this_m)>1e-10 || abs($base_b-$this_b)>1e-10 } {
		set base_eq [pretty_slit $base_m $base_b]
		set this_eq [pretty_slit $this_m $this_b]
		message "different slit $slit: $base_eq != $this_eq"
	    }
	}
    }

}

# Return true if two runs contain the same sort of thing (same instrument
# same slits, etc.)
proc run_matches { base_rec target_rec } {
    # returns error string if no match, otherwise return {}
    upvar #0 $base_rec base
    upvar #0 $target_rec this
    if { ![string equal $this(dataset) $base(dataset)] } {
	return "different data sets: $base(dataset) != $this(dataset)"
    }
    if { ![string equal $this(instrument) $base(instrument)] } {
	return "different extension: $base(instrument) != $this(instrument)"
    }
    if { ![string equal $this(type) $base(type)] } {
	return "different data types: [typelabel $base(type)] != [typelabel $this(type)]"
    }
    if { ![string equal $this(index) $base(index)] } {
	return "different index: $base(index) != $this(index)"
    }
    if { ![string equal $this(base) $base(base)] } {
	# XXX FIXME XXX Ideally we would know if the styles were
	# commensurate; e.g. even though one section is counted
	# against monitor and another is counted against time,
	# so long as they share a monitor column with monitor normalization
	# or a time column with time normalization, there is no conflict.
	# For now we will just let the user sort it out.
	return "different monitor counting style: $base(base) != $this(base)"
    }
    # the following should never be true since we just determined
    # that the types matched
    if { [info exists this(rockbar)] } {
	if { ![info exists base(rockbar)] } {
	    return "internal error --- missing 2 theta center indicator for $base(file)"
	}
	if { abs($this(rockbar) - $base(rockbar)) > 1e-10 } {
	    return "different 2 theta centers: $base(rockbar) != $this(rockbar)"
	}
    } else {
	if { [info exists base(rockbar)] } {
	    return "internal error --- missing 2 theta center indicator for $this(file)"
	}
    }
    # XXX FIXME XXX put slit comparison code back in? Yes.

    if { $base(T) != $this(T) } {
	return "different temperature: $base(T) != $this(T)"
    }
    if { $base(H) != $this(H) } {
	return "different field: $base(H) != $this(H)"
    }
    return {}
}

# XXX FIXME XXX building an extension could be faster if we didn't
# start from scratch every time we added a new run to the extension.
# For now the speed seems adequate.

# Return true if the run extends the range covered by the list of runs.
# The range is extended if there are x values in the run which are not
# in the run list.  This will fill holes in the coverage of the run list.
proc run_extends { runlist run } {
    upvar #0 $run rec
    set start $rec(start)
    set stop $rec(stop)
    set progress 1
    while { $progress } {
	set remainder {}
	set progress 0
	foreach id $runlist {
	    upvar #0 $id rec
	    if { $start >= $rec(start) && $start < $rec(stop) } {
		set progress 1
		set start $rec(stop)
	    } elseif { $stop > $rec(start) && $stop <= $rec(stop) } {
		set progress 1
		set stop $rec(start)
	    } elseif { $start >= $rec(start) && $stop <= $rec(stop) } {
		lappend remainder $id
	    } else {
	    }
	}
	set runlist $remainder
    }
    return [expr {$start < $stop}]
}


# Return true if the run extends the range covered by the list of runs.
# The range is extended if there are x values in the run which are beyond
# the ends of the run list.  This will not fill holes in the coverage of
# the run list.
proc run_extends_total_range { runlist run } {
    if { [llength $runlist] == 0 } { return 1 }
    set start 1.e308
    set stop -1.e308
    foreach id $runlist {
	upvar #0 $id rec
	set fstart $rec(start)
	set fstop $rec(stop)
	if { $fstart < $start } { set start $fstart }
	if { $fstop > $stop } { set stop $fstop }
    }
    upvar #0 $run rec
    set fstart $rec(start)
    set fstop $rec(stop)
    return [expr ($fstart<$start && $fstop<$stop) \
	    || ($fstart>$start && $fstop>$stop)]
}

proc addrun_matches { arg } {
    if { [llength $::addrun] == 0 } { return {} }

    # build a list of indexes used
    foreach id $::addrun {
	set index [set ::${id}(index)]
	if ![info exists heads($index)] { set heads($index) $id }
    }

    # if the new run shares an existing index, check that it conforms
    set index [set ::${arg}(index)]
    if [info exists heads($index)] {
	return [run_matches $heads($index) $arg]
    } else {
	return {}
    }
}

proc set_absolute {id} {
    if {[info exists ::x_$id]} { ::x_$id expr abs(::x_$id) }
}

proc set_absolute_all { } {
    foreach id $::addrun { set_absolute $id }
}


proc clear_run {id} {
    upvar #0 $id rec
    if { [incr rec(loaded) -1] > 0} { return }
    if { $rec(loaded) < 0 } {
	set rec(loaded) 0
	error "reference count error for $id"
    }
    eval vector destroy [vector names ::*_$id]
}

# HELP developer
# Usage: dataset_clear
#
# Clear the current set of marked records from memory.
# Be sure to clear the tree as well if it is displayed.
proc dataset_clear {} {
    catch { unset ::group }
    catch { unset ::grouprange }
    catch { array unset ::background_basis_nodes }
    catch { array unset ::background_basis }
    foreach var [info vars ::$::recpattern] { array unset $var }
    set var [vector names ::*_$::recpattern]
    if { [llength $var] > 0 } { eval vector destroy $var }
    catch { unset ::dataset }
    catch { unset ::datafiles }
    ## Don't reuse record numbers so that way we know whether or not
    ## we can reload the scan
    # set ::rec_count 0
}

# HELP developer
# Usage: note_rec id note1 note2 ...
#
# Add notes to the current record which will be stored in the datafile.
proc note_rec { id args } {
    if { [llength $args] } {
	lappend ::${id}(notes) $args
    } else {
	set ::${id}(notes) {}
    }

}

# HELP developer
# Usage: new_rec
#
# Create a new record for the data in the given file.
# Initializes the id and file fields.
# Returns the new unique record id.
proc new_rec { file } {
    set id R[incr ::rec_count]
    set ::${id}(id) $id
    set ::${id}(file) $file

    return $id
}
init_cmd { set ::rec_count 0 }

# HELP developer
# Usage: marktype type start stop index
#
# Record the type and index for the current record.
# The current record must be named "rec" in the calling context.
proc marktype {type {start 0} {stop 0} {index ""}} {
    upvar rec rec
    set root [file rootname $rec(file)]
#    set rec(run) [string range $root end-2 end] ;# 3 digit run number
#    set rec(dataset) [string range [file tail $root] 0 end-3] ;# run name
    set rec(type) $type
    set rec(start) $start
    set rec(stop) $stop
    set rec(index) $index
    categorize
}

# HELP developer
# dataset
#
# ::dataset(id) is the date of the newest record in dataset id
# ::group(id,inst,type) is a list of records with
#     the same dataset,instrument,type
# ::datafiles is the list of all files currently categorized
#
# See dataset_clear dataset_list group_list group_range categorize


# HELP internal
# Usage: categorize
#
# Register the current record according to instrument and type, etc.
# The current record must be named "rec" in the calling context.
#
# FIXME figure out how to ignore the dates of the processed files
proc categorize {} {
    upvar rec rec

    # keep track of the date range for the dataset
    if { [info exists ::dataset($rec(dataset))] } {
	if { $rec(date) > $::dataset($rec(dataset)) } {
	    set ::dataset($rec(dataset)) $rec(date)
	}
    } else {
	set ::dataset($rec(dataset)) $rec(date)
    }
    lappend ::group($rec(dataset),$rec(instrument),$rec(type)) $rec(id)
}

# HELP internal
# Usage: dataset_list
#
# Return a list of currently available datasets. Used by the tree builder.
proc dataset_list {} {
    return [lsort [array names ::dataset]]
}

# HELP internal
# Usage: group_list id
#
# Return a list of record ids in the given dataset. Used by the tree builder.
proc group_list {dataset} {
    return [lsort -dictionary [array names ::group "$dataset,*"]]
}


# HELP internal
# Usage: group_range id start stop
#
# Sets $start and $stop to the limits of the data ranges within the group.
proc group_range {gid Vstart Vstop } {
    upvar $Vstart start
    upvar $Vstop stop
    if { [info exists ::grouprange($gid)] } {
	foreach {start stop} $::grouprange($gid) break
    } else {
	set start 1.e100
	set stop -1.e100
	foreach id $::group($gid) {
	    upvar #0 $id rec
	    if { $start > $rec(start) } { set start $rec(start) }
	    if { $stop < $rec(stop) } { set stop $rec(stop) }
	}
	set ::grouprange($gid) [list $start $stop]
    }
}

# HELP developer
# Usage: set_background_basis dataset basis
#
# Set the background basis for aligning specular and background to
# A3 or A4.
#
# FIXME replace A3/A4 with alpha/beta and motor 3/4 with alpha/beta.
proc set_background_basis {dataset basis} {
    # puts "changing basis from $::background_basis($dataset) to $basis for $dataset"
    set ::background_basis($dataset) $basis
    foreach id $::group($dataset,back) {
	switch $basis {
	    A3 {
		set ::${id}(start) [set ::${id}(start,3)]
		set ::${id}(stop) [set ::${id}(stop,3)]
		if {[vector_exists ::x_$id]} {
		    ::x_$id expr [ a3toQz ::alpha_$id [set ::${id}(L)] ]
		}
	    }
	    A4 {
		set ::${id}(start) [set ::${id}(start,4)]
		set ::${id}(stop) [set ::${id}(stop,4)]
		if {[vector_exists ::x_$id]} {
		    ::x_$id expr [ a4toQz ::beta_$id [set ::${id}(L)] ]
		}
	    }
	}
    }
}

# HELP user
# Usage: load_files file1 ...
#
# Load the data associated with a set of files returning the associated
# record ids.
proc load_files {args} {
    message "load_files is not yet implemented"
}


# HELP developer
# Usage: load_run id
#
# Load the data associated with the record.
proc load_run {id} {
    upvar #0 $id rec

    # It is an error to load while a load is pending
    # Unfortunately it could happen if for example the user clicks
    # to load the file again before the file could be loaded in the
    # first place.
    # XXX FIXME XXX this works if there is only one 'client' for the
    # loaded record since that client doesn't need multiple copies.
    # If there are multiple clients, then the other clients should
    # block until loading completes.  This didn't work when I tried
    # it using "vwait rec(loading)", presumably because the octave
    # sync block which allowed another thread to enter was waiting
    # on a separate variable.
    if [info exists rec(loading)] {
	messsage "shouldn't call load_run if already loading"
    }

    # check if already loaded (using reference counts)
    if {![info exists rec(loaded)]} { set rec(loaded) 0 }
    if {$rec(loaded) > 0} { incr rec(loaded); return 1 }

    # avoid loading from a separate "thread" while this thread is loading
    set rec(loading) 1

    # default values for everything
    set rec(ylab) R
    set rec(xlab) Q
    # attenuator factor; if you remove the condition, then it
    # will keep the last value used for the attenuator.
    # XXX FIXME XXX do we want to reset it?
    # if { ![info exists rec(k)] } {
	set rec(k) 1.0
	set rec(dk) 0.0
    # }

    # XXX FIXME XXX these should be post-loding operations, but loadreduced
    # jumps immediately to ghost mode.

    # define scaled vectors (atten_set sets their values according to the
    # scale factor and the current monitor)
    vector create ::ky_$id ::kdy_$id

    # set other fields
    set ::${id}(legend) "[set ::${id}(run)][set ::${id}(index)]"

    # call the type-specific loader
    if { [$rec(load) $id] } {
	# register the successful load
	incr rec(loaded)
    }

    # norm vectors
    vector create ::y_$id ::dy_$id
    if { ![vector_exists ::dcounts_$id] } {
	vector create ::dcounts_$id
	::dcounts_$id expr "sqrt(::counts_$id) + (::counts_$id == 0)"
    }
    if { [vector_exists ::monitor_$id] } {
	set rec(norm) "monitor"
    } else {
	set rec(norm) "seconds"
    }

    # okay to try load again now
    unset rec(loading)

    # let the loader know if load was successful.
    return $rec(loaded)
}


# HELP developer
# Usage: get_columns id columns data
#
# Convert a string containing:
#    val val val \n val val val \n ...
# into a set of vectors
#    Col1_id Col2_id Col3_id
proc get_columns { id columns data } {
    # ptrace

    # convert newlines to spaces so that we can change the data to a list
    set data [string map { "\n" " " } $data]
    if { [catch { eval list $data } valuelist] } {
	message "data isn't a matrix of numbers"
	return 0
    }

    # create data columns
    foreach col $columns {
	vector create ::${col}_$id
	::${col}_$id length 0
    }

    # translate rows of data to BLT vectors
    # XXX FIXME XXX maybe faster to do this in octave until BLT has
    # the ability to process ranges of the form start:step:stop
    if [catch {
	foreach $columns $valuelist {
	    foreach col $columns {
		::${col}_$id append [set $col]
	    }
	}
    }] {
	message "data isn't a matrix of numbers"
	return 0
    }
    return 1
}

# HELP developer
# Usage: typelabel type
#
# Convert a type name into a type label
array set ::typelabel { \
	slit "Slit scan" back "Background" \
	spec "Specular" rock "Rocking curve" \
	? "Unknown" height "Height scan" \
	time "Time evolution" other "Processed" \
    }
proc typelabel { type } {
    if { [info exists ::typelabel(type)] } {
	return $::typelabel(type)
    } else {
	return $type
    }
}


# HELP user
# Usage: rec filename|index
#
# Finds the record associated with the name and binds it to rec.  It first
# checks for a name in the currently selected records.  For example, if
# record 003 for dataset sfaaa is selected, then [rec 003] will set the
# current record to sfaaa003.  If the desired record is not selected then
# you will need to use e.g., [rec sfaaa003] or [rec sfaaa003.na1]. File
# names are case insensitive.
#
# This is meant to be called from the tcl console.  It is never
# called by the rest of the application.  Note that the current
# implementation is slow, and could easily be improved if needed.
proc rec { file } {
    if { [isgui] && [winfo exists .graph] } {
	foreach r [.graph elem names] {
	    if [string match $file [.graph elem cget $r -label]] {
		upvar #0 $r ::rec
		return $::rec(id)
	    }
	}
    }
    foreach r [info var ::$::recpattern] {
	if {[string match -nocase "$file*" [file tail [set ${r}(file)]]]} {
	    upvar #0 $r ::rec
	    return $::rec(id)
	}
    }
    return {}
}


# HELP developer
# Usage: mark_pattern { prefix1 prefix2 ... }
#
# Categorize a set of files and create records for each of them.
proc mark_pattern { pattern_set } {

    # FIXME should be able to add files to the existing list
    if { [info exists ::datafiles] && [llength $::datafiles]>0 } {
	message "Must call dataset_clear before mark_pattern"
	return
    }

    # set up a progress bar so that the user knows what percentage of
    # the files in the tree have been processed.
    set ::loading_text "Categorizing files..."
    set ::loading_abort 0
    set ::loading_progress 0
    if [isgui] {
	ProgressDlg .loading -textvariable ::loading_text -stop Stop \
	    -variable ::loading_progress -maximum 100 \
	    -command { set ::loading_abort 1 ; set ::loading_text "Stop..." }
	#  grab release .loading ;# allow user interaction while loading
    } else {
	message "$::loading_text"
    }

    # glob the patterns
    set files {}
    foreach p $pattern_set {
        # implicitly extend patterns as if they are prefixes
	set p [file normalize $p]
        if { [file isdirectory $p] } {
            set p [file join $p *]
        } else {
            set p "$p*"
        }
        set files [concat $files [glob -nocomplain $p]]
    }
    set ::datafiles [lsort -dictionary -unique $files]

    # set steps between progress bar updates based on number of files
    set n [llength $::datafiles]
    if { 0 < $n && $n <= 100 } {
	.loading configure -maximum $n
	set step 1
    } else {
	set step [expr $n/100.]
    }
    update idletasks

    # process all the files
    set count 0
    set next 0
    set others {}
    foreach f $::datafiles {
	if { [incr count] >= $next } {
	    incr ::loading_progress
	    update
	    set next [expr {$next + $step}]
	    if { $::loading_abort } { break }
	}
	if [file isdirectory $f] continue
	set ext [string tolower [file extension $f]]
	if {[info exists ::extfn($ext)]} {
	    if 0 { # For debugging, allow error to show context
		$::extfn($ext) mark $f
	    } elseif { [ catch { $::extfn($ext) mark $f } msg ] } {
		if {![message -cancel "$msg\nwhile loading $f"]} { break }
	    }
	} else {
	    lappend others $f
	}
    }

    # Delay marking others so that we know what datasets are available
    # We want to try to match the 'other' to the dataset it may have
    # come from, but we can't do that without knowing the datasets
    foreach f $others {
	if 0 { # For debugging, allow error to show context
	    markother $f
	} elseif { [catch { markother $f } msg] } {
	    message $msg
	}
    }

    # all done --- remove the progress dialog
    if [isgui] { destroy .loading } { message "...done loading" }
}

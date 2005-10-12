# Load in ICE data files.   Currently these are treated as
# a subset of ICP data files so do not use the regular
# register-classify-mark-load interface.  mark and load
# are triggered when ICP files start with #ICE.
namespace eval icedata {

proc register {} {}

# Untested and unused as of this writing --- icedata presently
# works as an alternate backend to icp.  Some day this may
# change, and then we will call this function directly.
proc classify { action {name {}} } {
    # ptrace
    switch $action {
	instrument { return CG-1 }
	dataset { return [string range $name 0 4] }
	info {
	    set date [file mtime $name]
	    set comment [file tail [file rootname $name]]
	    catch {
		set fid [open $name]
		date_comment $fid date comment
		close $fid
	    }
	    return [list date $date comment $comment]
	}
	pattern { return "$name*.\[cC]\[gG]1" }
	mark { mark $name }
    }
}

# Grab the date and comment from an ICE datafile.
proc date_comment {fid date_var comment_var} {
    set data [read $fid 1024]
    set date ????
    set comment ????
    textkey $head date date
    textkey $head comment comment
    uplevel set $comment_var $comment
    uplevel set $date_var [clock_scan $date]
}

proc read_header {fid chunk} {
    set header {}
    while {1} {
	if {[regexp -lineanchor -indices "\n\[^\\#]" $chunk idx]} {
	    append header [string range $chunk 0 [lindex $idx 0]]
	    break
	} elseif {[eof $fid]} {
	    append header $chunk
	    break
	} else {
	    append header $chunk
	    set chunk [read $fid 2048]
	}
    }
    return $header
}

proc mark {file fid start} {
    # if {[ catch { open $file r } fid ] } { return 0 }
    set header [read_header $fid $start]
    # close $fid

    upvar #0 [new_rec $file] rec
    set rec(load) [namespace code load]
    set rec(dataoffset) [string length $header]
    set rec(header) $header

    foreach {rec(dataset) rec(run)} [splitname $file] { break }

    # process the header
    parseheader $header
}



# parseheader rec head
#
# Process header for ICE files
# rec is the name of the record
# header is the header data
proc parseheader {head} {
    upvar rec rec

    # process the header lines
    set rec(fixed) 0
    set rec(L) 0.0
    set rec(T) 0
    set rec(H) 0
    set rec(monitor) 1.0
    set rec(instrument) CG-1
    set rec(polarization) {}
    set pattern "#\\s*(\\w+)(?:\\s*\[:=]\\s*|\\s+)\"?(.*?)\"?\\s*$"
    set fixed 1
    set rec(signal) Detector
    # XXX FIXME XXX do we really want to normalize to monitor even if we
    # are counting against time?
    set rec(base) Monitor
    set rec(dims) 0
    # puts $head
    foreach line [split $head \n] {
	if {![regexp $pattern $line {} label value]} {
	    # puts "Could not interpret <$line>"
	    continue
	}
	# puts "label=$label, value=$value"
	switch -- $label {
	    Filename { set rec(internal_name) $value }
	    Date { set rec(date) [clock scan $value] }
	    Comment { set rec(comment) $value }
	    Npoints { set rec(points) $value }
	    Ncolumns { set rec(Ncolumns) $value }
	    DetectorDims { 
		set rec(dims) $value 
		set rec(pixels) [lindex $value 0]
	    }
	    Signal { set rec(signal) [lindex $value 1] }
	    Scan { set rec(scan) [lindex $value 1] }
	    ScanRange { 
		set name [lindex $value 0]
		if {[llength $value] == 4} {
		    # convert start step stop to y=x, remembering start/stop
		    set Rstart [lindex $value 1]
		    set Rstep [lindex $value 2]
		    set Rstop [lindex $value 3]
		    set value [list $name 1 0]
		}
		if {[llength $value] == 3 && ![info exist Rstart]} {
		    # ScanRange slope/intercept without full range
		    continue
		}
		set m [lindex $value 1]
		set b [lindex $value 2]
		set start [expr {$m*$Rstart + $b}]
		set stop  [expr {$m*$Rstop  + $b}]
		set step  [expr {$m*$Rstep}]
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
	    ScanDescr { set rec(description) $value }
	    Wavelength { set rec(L) $value }
	    Columns { set rec(columns) $value }
	    default { 
		# puts "ICE load ignoring $label $value" 
	    }
	}
    }

    if { $rec(Ncolumns) != [llength $rec(columns)] } {
	message "Ncolumns not equal to \# of column headings in $rec(file)"
    }
    set rec(Ncolumns) [llength $rec(columns)]
    set rec(psd) [expr {"$rec(signal)" == "Area"}]
    if { $rec(psd) } { 
	append rec(instrument) "PSD"
    } elseif {"$rec(dims)" != "0"} {
	# If we are not a psd and we still have detector channels to
	# deal with, create fake columns for them.
	set n 1
	foreach i $rec(dims) {set n [expr {$n*$i}]}
	for {set i 1} { $i <= $n } { incr i } {
	    lappend rec(columns) "$rec(signal)Channel$i"
	}
    }
    if { ![info exist rec(scan)] } { set rec(scan) S1 }


    # Based on motor movements, guess the type of the experiment.
    # XXX FIXME XXX This is inadequate --- for motors that aren't
    # moving, we need to know where they are.  We should be able
    # to grab that info from the first row of data.
    set Ain [info exists rec(start,Theta)]
    set Aout [info exists rec(start,TwoTheta)]
    set S1 [info exists rec(start,S1)]
    set pol $rec(polarization)
    if { $fixed } {
	if 1 { 
	switch -- $rec(scan) {
	    Theta { marktype spec 0 0 $pol }
	    TwoTheta { marktype rock 0 0 $pol }
	    S1 - S2 - S3 - S4 { marktype slit 0 0 $pol }
	    default { marktype $rec(scan) 0 0 $pol }
	} 
	} else { marktype slit 0 0 $pol }
    } elseif { !$Ain && !$Aout } {
	# XXX FIXME XXX check that Ain=Aout=0
	if { $S1 } {
	    marktype slit $rec(start,S1) $rec(stop,S1) $pol
	} else {
	    marktype time 0 1 $pol
        }
    } elseif { !$S1 && !$Aout } {
	# direct beam with rotating A3 and fixed slits => absorption scan
	# XXX FIXME XXX check that Ain=Aout=0
	marktype absorption $rec(start,Theta) $rec(stop,Theta) $pol
    } elseif { $rec(psd) } {
	if { $Ain } {
	    marktype spec $rec(start,Theta) $rec(stop,Theta) $pol
	} else {
	    marktype spec $rec(start,TwoTheta) $rec(stop,TwoTheta) $pol
	}
    } else {
	set rec(slits) { S1 S2 S3 S4 }

	if { !$Aout || $rec(step,TwoTheta)==0.} {
	    # set rec(rockbar) [expr $rec(start,TwoTheta)/2.]
	    marktype rock $rec(start,Theta) $rec(stop,Theta) $pol
	} elseif { !$Ain || $rec(step,Theta)==0.} {
	    # set rec(rockbar) $rec(start,Theta)
	    marktype rock3 $rec(start,4) $rec(stop,4) $pol
	} elseif { abs($rec(stop,TwoTheta) - 2.0*$rec(stop,Theta)) <= 2e-5 } {
	    marktype spec $rec(start,Theta) $rec(stop,Theta) $pol
	} else {
	    # use default background basis
	    set rec(start,3) $rec(start,Theta)
	    set rec(stop,3) $rec(stop,Theta)
	    set rec(start,4) $rec(start,TwoTheta)
	    set rec(stop,4) $rec(stop,TwoTheta)
	    set m [string index $::background_default 1]
	    if { $rec(stop,TwoTheta) > 2.0*$rec(stop,Theta) } {
		marktype back $rec(start,$m) $rec(stop,$m) +$pol
	    } else {
		marktype back $rec(start,$m) $rec(stop,$m) -$pol
	    }
	    set ::background_basis($rec(dataset),$rec(instrument)) \
		    $::background_default
	}
    }

}


proc parsepsd {id data} {
    upvar #0 $id rec

    # Strip the commas and newlines so that sscanf can handle it
    set data [ string map {"," " " "\n" " "} $data ]
    octave eval "x=sscanf('$data', '%f ',Inf)"
    octave eval "nc=prod(\[$rec(dims)])+$rec(Ncolumns);"
    octave eval "x=reshape(x,nc,length(x)/nc)';"
    set i 0
    foreach c $rec(columns) {
	vector create ::${c}_$id
	octave recv ${c}_$id x(:,[incr i])
	if { "$c" == $rec(base) } {	octave eval "mon = x(:,$i)" }
    }
    # XXX FIXME XXX need dead-time correction
    # XXX FIXME XXX better correction for 0 signal
    octave eval "psd_$id = x(:,[incr i]:columns(x))"
    octave eval "psderr_$id = sqrt(psd_$id) + (psd_$id==0)"
    octave eval "mon = mon * ones(1,columns(psd_$id))"
    octave eval "psderr_$id = sqrt(psd_$id+!psd_$id + psd_$id.^2./mon)./mon"
    octave eval "psd_$id = psd_$id ./ mon"
    octave sync
}


proc parsedata {id} {
    # ptrace

    upvar #0 $id rec
    if {[ catch { open $rec(file) r } fid ] } { return 0 }
    # skip header and read data
    seek $fid $rec(dataoffset) start
    set data [read $fid]
    close $fid

    if { $rec(psd) } {
	parsepsd $id $data
    } else {
	if {![get_columns $id $rec(columns) $data]} { return 0 }
    }

    return 1
}

proc load {id} {
    upvar #0 $id rec

    if {![parsedata $id]} { return 0 }

    check_wavelength $id $::cg1wavelength

    set signal ::$rec(signal)_$id
    set monitor ::$rec(base)_$id
    # XXX FIXME XXX need dead-time correction
    # XXX FIXME XXX better correction for 0 signal
    ::$rec(signal)_$id dup ::counts_$id
    vector create ::dcounts_$id ::idx_$id
    ::dcounts_$id expr "sqrt(::counts_$id+!::counts_$id)"
    ::idx_$id expr "::counts_$id*0 + 1"
    catch { 
	::Monitor_$id dup ::monitor_$id
	vector create ::dmonitor_$id
	::dmonitor_$id expr "sqrt(::monitor_$id+!::monitor_$id)"
    }
    catch { ::Time_$id dup ::seconds_$id }
    catch { ::Theta_$id dup ::alpha_$id }
    catch { ::TwoTheta_$id dup ::beta_$id }
    catch { ::S1_$id dup ::slit1_$id }
    catch { ::S2_$id dup ::slit2_$id }
    catch { ::S3_$id dup ::slit3_$id }
    catch { ::S4_$id dup ::slit4_$id }

    set haveA3 [expr {[lsearch $rec(columns) "Theta"]>=0}]
    set haveA4 [expr {[lsearch $rec(columns) "TwoTheta"]>=0}]

    if {$haveA3 && $haveA4} {
	AB_to_QxQz $id
    } elseif {$haveA3} {
	vector create ::Qz_$id
	::Qz_$id expr [ a3toQz ::Theta_$id $rec(L) ]
    } elseif {$haveA4} {
	vector create ::Qz_$id
	::Qz_$id expr [ a4toQz ::TwoTheta_$id $rec(L) ]
    }

    if { "$rec(signal)" == "Area" } {
	# XXX FIXME XXX what is the limit?
	# XXX FIXME XXX do we also want to test ROI?
	set limit 8000
    } else {
	set limit 10000
    }
    exclude_saturated $id $limit

    upvar #0 $id rec
    switch -- $rec(type) {
	spec {
	    set rec(slit) S1_$id
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	    ::Qz_$id dup ::x_$id
	}
	rock - rock3 {
	    set rec(xlab) "Qx ($::symbol(invangstrom))"
	    ::Qx_$id dup ::x_$id
	}
	slit {
	    set rec(xlab) "slit opening (motor S1 units)"
	    ::slit1_$id dup ::x_$id
	}
	back {
	    set rec(slit) slit1_$id
	    # XXX FIXME XXX exclude_specular_ridge $id
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	    set col $::background_basis($rec(dataset),$rec(instrument))
	    switch $col {
		A3 {
		    vector create ::x_$id
		    ::x_$id expr [ a3toQz ::alpha_$id $rec(L) ] 
		}
		A4 {
		    vector create ::x_$id
		    ::x_$id expr [ a4toQz ::beta_$id $rec(L) ]
		}
	    }
	}
	default { 
	    ::$rec(scan)_$id dup ::x_$id
	    set rec(xlab) "$rec(scan)"
	}
    }
    set rec(ylab) "Reflectivity"

    return 1
}


}

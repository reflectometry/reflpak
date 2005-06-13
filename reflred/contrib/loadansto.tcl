# See README.load

namespace eval ANSTO {

    # note the new extension
    proc register {} {
	set ::extfn(.csv) [namespace which summary]
    }

    proc summary { action {name {}} } {
	# ptrace
	switch -- $action {
	    instrument { return ANSTO }
	    dataset { return [string range $name 0 end-7] }
	    info {
		set data {}
		catch {
		    set fid [open $file]
		    catch { set data [read $fid] }
		    close $fid
		}
		return [get_date_comment $data]
	    }
	    pattern { return "$name*.\[cC]\[sS]\[vV]" }
	    mark { mark $name }
	}
    }

    proc get_date_comment { data } {
	# ptrace
	set date ????
	set comment ????
	catch {
	    regexp {Run Title,([^\n]*)\n} $data in comment
	    regexp {Date: ([^\n]*)\n} $data in datestr
	    foreach {dd mm yyyy} [split $datestr "/"] break
	    set datenum [clock_scan "$yyyy-$mm-$dd"]
	    set date [clock format $datenum -format %Y-%m-%d]
	}
	return [list date $date comment $comment]
    }

    proc mark {file} {
	# ptrace
	# suck in the file
	if {[ catch { open $file r } fid ] } { 
	    message "Error: $fid"
	    return 
	}
	set data [read $fid]
	close $fid

	# create a new record
	upvar #0 [new_rec $file] rec
	set rec(load) [namespace which load]

	# assign run# and dataset
	set root [file rootname $file]
	set rec(run) [string range $root end-2 end] ;# 3 digit run number
	set rec(dataset) [string range [file tail $root] 0 end-3] ;# run name

	# get info about the run
	array set rec [get_date_comment $data]
	set date $rec(date)
	if {[catch { clock_scan $date } rec(date)]} {
	    message "clock scan fails for $date: $rec(date)"
	    #puts $rec(date)
	    set rec(date) 0
	}
	set rec(instrument) [summary instrument]
	set rec(T) unknown
	set rec(H) unknown
#	set rec(L) 4.0

	# We are actually counting against time, but we will be dividing
	# by monitor so we need to report counts per monitor rather than
	# counts per time unit.
	set rec(monitor) 1
	set rec(base) NEUT
	
	set lines [split $data \n]
	set first [lindex $lines 3]
	set last [lindex $lines end-6]
	set start [string range $first 0 [expr [string first , $first]-1]]
	set stop [string range $last 0 [expr [string first , $last]-1]]
	marktype spec $start $stop
    }
    
    proc load {id} {
	# ptrace
	upvar #0 $id rec

	# suck in the file
	if {[ catch { open $rec(file) r } fid ] } { 
	    message "Error: $fid"
	    return 0
	}
	set data [read $fid]
	close $fid

	# Columns are as follows, each separated by comma and space
	# 1:q(invAngstroms)    2:Raw Count
	# 3:Monitor ID(string) 4:Monitor Count       5:interval(s)
	# 6:Slit1(mm)          7:Slit2(mm)           8:Slit3(mm)
	# 9:theta(deg)         10:Detector Height(mm)
	# We aren't going to process the Monitor ID == slit2 column
	set columns {x y monitors time S1 S2 S3 theta height}

	# Strip commas and the Monitor ID==slit2 column.
	# Chop the data into lines.
	set lines [split [string map { { slit2} {} , {} } $data] \n]

	# Compute number of data lines.  Skip three header lines, 
	# 4 footnote lines and 2 background lines (for now).
	set n [expr {[llength $lines]-10}]

	# Create data vectors of the appropriate size
	foreach c $columns {
	    vector create ::${c}_${id}($n)
	}

	# Convert data 
	set n 0
	foreach line [lrange $lines 3 end-7] {
	    foreach c $columns v [split $line { }] {
		set ::${c}_${id}($n) $v
	    }
	    incr n
	}

	# dead time correction?
	# can calculate rate, which is mon/time, but don't know correction
	# curve.  See loadicp.tcl:NG7load for details.


	# Divide counts by monitors, propagating error
	vector create ::dmonitors_$id ::dy_$id
	::dmonitors_$id expr "sqrt(::monitors_$id) + !::monitors_$id"
	::dy_$id expr "sqrt(::y_$id) + !::y_$id"
	::dy_$id expr "sqrt((::dy_$id/::monitors_$id)^2 + \
            (::y_$id*::dmonitors_$id/::monitors_$id^2)^2)"
	::y_$id expr "::y_$id/::monitors_$id"

	# That should be it
	set rec(xlab) "Qz ($::symbol(invangstrom))"
	set rec(slit) S1_$id
	set rec(ylab) "Unnormalized Reflectivity"

	return 1
    }
}

# multiple registrations do not hurt anything, so
# this file can be sourced during debugging.
ANSTO::register

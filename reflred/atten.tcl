# ======================================================

## XXX FIXME XXX need to be able to choose ratio from a list
## XXX FIXME XXX need to be able to calc ratio relative to
## another
proc atten_table_reset {} {
    if { ![winfo exists .attenuator] } { return }
    unset ::atten_table
    array set ::atten_table { -1,0 Run -1,1 Attenuator -1,2 "Std. error" -1,3 "id"}
    set row -1
    foreach id $::addrun {
	upvar #0 $id rec
	incr row
	array set ::atten_table [list $row,0 "$rec(run)$rec(index)" $row,1 $rec(k) $row,2 $rec(dk) $row,3 $id]
    }
    .attenuator.t conf -rows [expr 1 + [llength $::addrun]]
    tableentry::reset .attenuator.t
}

proc atten_table {} {
    if { [winfo exists .attenuator] } {
	raise .attenuator
	focus .attenuator
	return
    }

    toplevel .attenuator
    wm geometry .attenuator 300x150
    table .attenuator.t -cols 4 -resizeborders col -colstr unset \
	    -titlerows 1 -titlecols 1 -roworigin -1 -variable ::atten_table
    .attenuator.t width 0 4
    pack [vscroll .attenuator.t] -fill both -expand yes

    if 0 { # suppress Align until it is robust
	frame .attenuator.b
	button .attenuator.b.align -text "Align" -command { addrun align }
	button .attenuator.b.unalign -text "Revert" -command { addrun unalign }
	pack .attenuator.b.align .attenuator.b.unalign -side left -anchor w
	grid .attenuator.b
    }

    # XXX FIXME XXX want a combo box here
    tableentry .attenuator.t { if { %i } { atten_update %r %c %S } else { set ::atten_table(%r,%c) } }
    atten_table_reset
}

proc atten_update { row col val } {
#    ptrace
    if {![string is double $val] || $val < 0} {
        message "expected non-negative scale factor"
        return 0
    } elseif {$val < 0} {
	message "must be non-negative"
        return 0
    }

    # the new value is good so save it in the appropriate record
    set ::atten_table($row,$col) $val
    # attenuator.t clear cache
    upvar #0 [lindex $::addrun $row] rec
    if { $col == 1 } {
	set rec(k) $val
    } else {
	set rec(dk) $val
    }

    # update the graph
    # XXX FIXME XXX this is overkill; minimum is "[lindex $::addrun 0] $id"
    atten_set $::addrun

    # return the value to display in the table
    return 1
}


proc atten { id1 id2 args} {
    switch [llength $args] {
	0 {
	    set range1 end
	    set range2 0
	}
	1 {
	    set overlap $args
	    if { $overlap > 1 } {
		incr overlap -1
		set range1 "end-$overlap:end"
		set range2 "0:$overlap"
	    } else {
		set range1 "end"
		set range2 "0"
	    }
	}
	2 {
	    set range1 [lindex $args 0]
	    set range2 [lindex $args 1]
	}
	default {
	    error "atten id1 id2 ?overlap|?range1 ?range2"
	}
    }

    upvar \#0 $id2 rec

    set rec(k) 1.0
    set rec(dk) 0.0
    monitor_norm $id
    set y1  [vector expr "sum(::y_${id1}($range1))"]
    set dy1 [vector expr "sqrt(sum(::dy_${id1}($range1)^2))"]
    set y2  [vector expr "sum(::y_${id2}($range2))"]
    set dy2 [vector expr "sqrt(sum(::dy_${id2}($range2)^2))"]

    set k   [vector expr "$y1/$y2"]
    set dk  [vector expr "sqrt( ($dy1/$y2)^2 + ($y1*$dy2/$y2^2)^2 )"]
    atten_from_ratio $id $k $dk
}

proc _atten_sum_points {points Iname dIname} {
    upvar $Iname I
    upvar $dIname dI
    set I 0.
    set dI 0.
    foreach p $points {
	foreach {x y name idx} $p break
	set I [vector expr "$I+[set ::y_${name}($idx)]"]
	set dI [vector expr "$dI+[set ::dy_${name}($idx)]^2"]
    }
    set dI [expr {sqrt($dI)}]
}

proc atten_from_screen {{n 0}} {
    # select list of points from high line
    graph_select_list .graph hi
    vwait ::hi
    if { [llength $::hi] == 0 } { return }

    # select list of points from low line
    graph_select_list .graph lo
    vwait ::lo
    
    # FIXME: should simply select low line and determine corresponding
    # points automatically
    # FIXME: maybe check that hi/lo are from the same sets
    if {[llength $::hi] != [llength $::lo]} {
	message -bell "Hi and lo have a different number of points"
	return
    }
    
    # get attenuated record
    set id [lindex [lindex $::lo 0] 2]
    # FIXME: don't hardcode form of the name
    if { ![string match {R[0-9]*} $id] } {
	message -bell "invalid line selected for lo"
	return
    }
    upvar \#0 [lindex [lindex $::lo 0] 2] rec
    set rec(k) 1.0
    set rec(dk) 0.0
    monitor_norm $id
    
    # sum points
    _atten_sum_points $::hi yhi dyhi
    _atten_sum_points $::lo ylo dylo
    if 0 {
	puts "hi=$yhi ($dyhi) from $::hi"
	puts "lo=$ylo ($dylo) from $::lo"
    }

    set k [vector expr "$yhi/$ylo"]
    set dk [vector expr "sqrt(($dyhi/$ylo)^2 + ($yhi*$dylo/$ylo^2)^2)"]

    atten_from_ratio $id $k $dk
}

proc atten_from_counts { id s1 s2 } {
    set k   [vector expr "$s1/$s2"]
    set dk  [vector expr "$s1/$s2*sqrt( 1/s1 + 1/s2)"]
    atten_from_ratio $id $k $dk
}

proc atten_from_ratio { id k dk } {
    upvar \#0 $id rec

    # Record the attenuator with two digits of precision in uncertainty
    set rec(k) [fix $k [expr {$k-$dk}] [expr {$k+$dk}] 2]
    set rec(dk) [fix $dk {} {} 2]
    atten_table_reset
    atten_set $::addrun
}

proc atten_copy {id1 args} {
    upvar \#0 $id1 rec1
    foreach id2 $args {
	upvar \#0 $id2 rec2
	set rec2(k) $rec1(k)
	set rec2(dk) $rec1(dk)
    }
    atten_table_reset
    atten_set $::addrun
}


# =====================================================

# XXX FIXME XXX not using either of these but should be
# will need to move entire scale calc algorithm to octave, so delay.
proc average_seq {} {
    octave send ::x_seq r.x
    octave send ::y_seq r.y
    octave send ::dy_seq r.dy
    # XXX FIXME XXX what about excluded points?
    octave eval "r = run_poisson_avg(r)"
    octave recv x_seq r.x
    octave recv y_seq r.y
    octave recv dy_seq r.dy
}
proc average_seq_tcl {} {
    # pure tcl version, gaussian statistics
    set dups {}
    for {set i 1; set j 0} { $i < [::x_seq length] } { incr i; incr j } {
	if { abs($::x_seq($j) - $::x_seq($i)) < 1e-8 } {
	    ## usual average of x1 and x2 -> x1
	    set ::x_seq($j) [expr ($::x_seq($i)+$::x_seq($j))/2.];
	    ## error-weighted average of y1 and y2 -> y1
	    set si [expr 1./($::dy_seq($i)*$::dy_seq($i))]
	    set sj [expr 1./($::dy_seq($j)*$::dy_seq($j))]
	    set w [expr $si + $sj]
	    set inerr "$::dy_seq($i) $::dy_seq($j)"
	    if { $w == 0.0 } {
		puts "dyi=$::dy_seq($i), dyj=$::dy_seq($j), w=$w"
	    }
	    set ::y_seq($j) [expr double($::y_seq($i)*$si + $::y_seq($j)*$sj)/$w]
	    set ::dy_seq($j) [expr 1./sqrt($w)];
	    puts "avg: $inerr -> $::dy_seq($j)"
	    ## remove y2 from set
	    lappend dups $i
	}
    }
    if { ![string equal $dups ""] } {
	eval ::x_seq delete $dups
	eval ::y_seq delete $dups
	eval ::dy_seq delete $dups
    }
}



# calculate the amount of overlap between x_$id1 and x_$id2
proc find_overlap { id1 id2 } {
    upvar $id1 x1
    upvar $id2 x2

    # xrange is monotonic but not necessarily increasing
    if { $x2(0) <= $x2(end) } {
	set idx [ $id1 search $x2(0) $x2(end) ]
    } else {
	set idx [ $id1 search $x2(end) $x2(0) ]
    }
#   puts "overlap at idx $idx"
    set n [llength $idx]
    if { $n == 0 } {
#	puts "none"
	return -1;
    } else {
#	puts "range [expr $x1([lindex $idx end]) -  $x1([lindex $idx 0]) ]"
	return [expr 1.0e-30 + $x1([lindex $idx end]) - $x1([lindex $idx 0]) ]
    }
}

proc join_one {id seq} {
    upvar ::x_$id x
    upvar ::y_$id y
    upvar ::dy_$id dy
    # xrange is monotonic but not necessarily increasing
    if { $x(0) <= $x(end) } {
	set y1idx [ ::x_seq search $x(0) $x(end) ]
    } else {
	set y1idx [ ::x_seq search $x(end) $x(0) ]
    }
    if { $::x_seq(0) < $::x_seq(end) } {
	set y2idx [ ::x_$id search $::x_seq(0) $::x_seq(end) ]
    } else {
	set y2idx [ ::x_$id search $::x_seq(end) $::x_seq(0) ]
    }
    ### XXX FIXME XXX need better estimate of scaling factor
    ### for now only using one point
    set y1 $::y_seq([lindex $y1idx 0])
    set y2 $y([lindex $y2idx 0])
    set dy1 $::dy_seq([lindex $y1idx 0])
    set dy2 $dy([lindex $y2idx 0])
    upvar #0 $id rec
    if { $y2 == 0 } {
	# XXX FIXME XXX need better handling of this, but it should
	# come when we clean up the atten factor code
	message "ignoring 0 when scaling"
	set rec(k) 1.0
	set rec(dk) 0.0
#puts "appending ::x_$id to ::x_seq"
	::x_seq append ::x_$id
	::y_seq append ::y_$id
	::dy_seq append ::dy_$id
    } elseif { $y1 >= $y2 } {
#	puts "scale new run against the old"
	set rec(k) [expr double($y1)/$y2]
	set p [expr double($dy1)/$y2]
	set q [expr (double($y1)/$y2)*(double($dy2)/$y2)]
	set rec(dk) [expr sqrt($p*$p + $q*$q)]
	::ky_$id expr "$rec(k)*::y_$id"
	::kdy_$id expr "sqrt($rec(k)^2*::dy_$id^2 + ::y_$id^2*$rec(dk)^2)"
#puts "appending ::x_$id to ::x_seq"
	::x_seq append ::x_$id
	::y_seq append ::ky_$id
	::dy_seq append ::kdy_$id
    } else {
#	puts "scale all old runs against the new"
	set rec(k) 1.0
	set rec(dk) 0.0
	set k [expr double($y2)/$y1]
	set p [expr double($dy2)/$y1]
	set q [expr (double($y2)/$y1)*(double($dy1)/$y1)]
	set dk [expr sqrt($p*$p + $q*$q)]
	foreach oldid $seq {
	    #puts "updating [set ::${oldid}(run)] by $k +/- $dk"
	    set ::${oldid}(dk) [vector expr "sqrt($k^2*[set ::${oldid}(dk)]^2 + [set ::${oldid}(k)]^2*$dk^2)"]
	    set ::${oldid}(k) [expr $k*[set ::${oldid}(k)]]
	}
	::dy_seq expr "sqrt( $k^2 * ::dy_seq^2 + ::y_seq^2 * $dk^2 )"
	::y_seq expr "$k * ::y_seq"
	#puts "appending [set ::${id}(run)] to ::x_seq"
	::x_seq append ::x_$id
	::y_seq append ::y_$id
	::dy_seq append ::dy_$id
    }
    ::x_seq sort ::y_seq ::dy_seq

}

# Find a connected sequence of runs and join them together with
# scaling relative to the peak
proc get_seq {runs monitor} {
    # start with the first run
    set seq [lindex $runs 0]
    set ::${seq}(k) 1.0
    set ::${seq}(dk) 0.0
    set runs [lrange $runs 1 end]
    ::x_$seq dup ::x_seq
    ::y_$seq dup ::y_seq
    ::dy_$seq dup ::dy_seq

    ## XXX FIXME XXX the following fails with unable to find peakid if
    ## the first thing we do is double click on a file which is all zeros.
    ## E.g., ~borchers/Neutron/G126a/g126a010.na1

    # cycle through the remaining runs, extracting
    # the maximally overlapping one. This is an n^2 algorithm,
    # but we could easily make it nlogn by sorting the
    # runs by ::x_$id(0) and using the first overlapping run.
    set seqnum [set ::${seq}(run)]
    while {1} {
	# find the maximal overlap
	set peak -1
	foreach id $runs {
#puts -nonewline "checking overlap between {$seqnum} ($::x_seq(0) ... $::x_seq(end)) and [set ::${id}(run)] ([set ::x_${id}(0)] ... [set ::x_${id}(end)]): "
	    set v [find_overlap ::x_seq ::x_$id]
	    if { $v > $peak } {
		set peak $v
		set peakid $id
	    }
	}

	if { $peak >= 0 } {
	    # overlap so add it to our sequence
	    join_one $peakid $seq
#puts "x_seq: $::x_seq(:)"
	    lappend seq $peakid
	    lappend seqnum [set ::${peakid}(run)]
	    set runs [ldelete $runs $peakid]
	} else {
	    # no overlap so finished the current sequence
	    break;
	}
    }
    return $runs
}

# Given a set of run ids $runs, find k/dk which joins them.
proc atten_calc {runs} {
    if { [string equal $runs {}] } { return }
    upvar #0 [lindex $runs 0] rec
    set runs [get_seq $runs $rec(monitor)]
    while { [llength $runs] > 0 } {
puts "remaining runs: $runs"
	# get the next connected sequence out of $runs, removing the elements
	# it uses and constructing ::x_seq, ::y_seq, ::dy_seq
	set runs [get_seq $runs $rec(monitor)]
    }
}


proc fmultiply {name value} {
    upvar $name vec
    set s [fvector vec]
    set t {}
    foreach el [fvector vec] { lappend t [expr {$el*$value}] }
    fvector vec $t
}

proc findex {name idxstr} {
    if {[fprecision] == 8} { set pattern d } else { set pattern f }
    upvar $name vec
    set len [flength vec]
    set idx [expr [string map [list end "$len-1"] $idxstr]]
    if {$idx<0 || $idx>=$len} { 
	error "$idxstr out of range of 0..[expr {$len-1}] in vector $name" 
    }
    set start [expr {$idx*[fprecision]}]
    set stop [expr {($idx+1)*[fprecision]-1}]
    binary scan [string range $vec $start $stop] $pattern val
    return $val
}

proc fvector {name args} {
    if {[fprecision] == 8} { set pattern d* } else { set pattern f* }
    upvar $name vec
    set nargin [llength $args]
    if {$nargin == 0} {
	binary scan $vec $pattern h
	return $h
    } elseif {$nargin == 1} {
	set vec [binary format $pattern [lindex $args 0]]
    } else {
	error "wrong # args: should be \"fvector name ?value_list\""
    }
}

proc ferr {val err} {
    upvar $val v
    upvar $err dv
    set res {}
    foreach x [fvector v] { lappend res [expr {sqrt($x) + ($x!=0)}] }
    fvector dv $res
}


proc flength {name} {
    # XXX FIXME XXX vector length could be wrong if the byte sequences 
    # happens to code to UTF multi-byte patterns.  Need something better
    # than [string length x] to handle this properly.
    upvar $name vec
    return [expr {[string length $vec]/[fprecision]}]
}

proc flimits {name {limits {}}} {
    upvar $name vec
    set s [fvector vec]
    if {[llength $limits] == 0} {
	set min [lindex $s 0]
	set max $min
    } else {
	set min [lindex $limits 0]
	set max [lindex $limits 1]
    }
    foreach v $s {
	if {$v < $min} {
	    set min $v
	} elseif {$v > $max} {
	    set max $v
	}
    }

	
    return [list $min $max]
}

proc edges {centers delta} {
#  if { [llength $centers] == 1 }
#    set e [list [expr {$centers-$delta}] [expr {$centers+$delta}]]
  if { [lindex $centers 0] == [lindex $centers end] } {
    set c [lindex $centers 0]
    set e [expr {$c-$delta}]
    set sign 1.
    foreach r $centers {
        lappend e [expr {$c+$sign*$delta}]
        set sign [expr {-$sign}]
    }
  } else {
    set l [lindex $centers 0]
    set r [lindex $centers 1]
    set e [expr {$l - 0.5*(($r)-($l))}]
    foreach r [lrange $centers 1 end] {
      lappend e [expr {0.5*(($l)+($r))}]
      set l $r
    }
    set l [lindex $centers end-1]
    lappend e [expr {$r + 0.5*(($r)-($l))}]
  }
  return $e
}

proc integer_edges {n {base 0}} {
  set v {}
  for {set p 0} {$p <= $n} {incr p} {
    lappend v [expr {$base+$p+0.5}]
  }
  return $v
}

proc integer_centers {n {base 0}} {
  set v {}
  for {set p 1} {$p <= $n} {incr p} {
    lappend v [expr {$base+$p}]
  }
  return $v
}

proc linspace {start stop steps} {
    set b [expr {double($stop-$start)/($steps-1)}]
    set l {}
    for {set i 0} {$i < $steps} {incr i} { 
	lappend l [expr {$start + $i*$b}] }
    return $l
}

proc colorgradient {colors weights {alpha 1.} {n 64}} {
    if {[llength $weights]+1 != [llength $colors]/3} {
	error "colorgradient: need one weight for each interval"
    }

    # Convert weights into indices in the resulting colormap
    set total 0.
    foreach w $weights { set total [expr {$total+$w}] }
    set indices 0
    set cum 0.
    foreach w $weights {
	set cum [expr {$cum + $w}]
	lappend indices [expr {int(round(($n-1)*$cum/$total))}]
    }

    # Generate color gradients
    foreach {R G B} $colors idx $indices {
	if {$idx == 0} {
	    set channelR $R
	    set channelG $G
	    set channelB $B
	} elseif {$idx != $lastidx} {
	    set steps [expr {$idx - $lastidx + 1}]
	    eval lappend channelR [lrange [linspace $lastR $R $steps] 1 end]
	    eval lappend channelG [lrange [linspace $lastG $G $steps] 1 end]
	    eval lappend channelB [lrange [linspace $lastB $B $steps] 1 end]
	}
	set lastR $R
	set lastG $G
	set lastB $B
	set lastidx $idx
    }

    # Generate constant alpha channel
    set channelA {}
    foreach R $channelR { lappend channelA $alpha }

    # Join them into an (n x 4) matrix
    fvector map [concat $channelR $channelG $channelB $channelA]
    ftranspose $n 4 map

    return $map
}

proc colormap_bright {{n 64}} {
    return [colorgradient {0.8 0.8 0.6  1 1 0  1 0 0  1 1 1} {1 1 1} 1 $n]
}

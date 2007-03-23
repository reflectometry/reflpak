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
    # FIXME check if this should be upvar 0 to keep the variable local
    # to the current function; similarly elsewhere
    upvar $val v
    upvar $err dv
    set res {}
    foreach x [fvector v] { lappend res [expr {sqrt($x) + ($x!=0)}] }
    fvector dv $res
}


proc flength {name} {
    # FIXME vector length could be wrong if the byte sequences 
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
    # remove jitter
    set delta 0
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
    if {$steps == 0} {
	return {}
    } elseif {$steps == 1} {
	return [expr {double($stop-$start)/2.}]
    } else {
	set b [expr {double($stop-$start)/($steps-1)}]
	set l {}
	for {set i 0} {$i < $steps} {incr i} { 
	    lappend l [expr {$start + $i*$b}] }
	return $l
    }
}

namespace eval colormap {
    
proc gradient {colors weights {alpha 1.} {n 64}} {
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

proc bright {{n 64}} {
    set alpha 1
    return [gradient {0.8 0.8 0.6  1 1 0  1 0 0  1 1 1} {1 1 1} $alpha $n]
}

proc copper {{n 64}} {
    set alpha 1
    set map {}
    foreach x [linspace 0 1 $n] {
	if { $x < 0.8 } {
	    lappend map [expr {1.25*$x}] [expr {0.8*$x}] [expr {$x/2}] $alpha
	} else {
	    lappend map 1 [expr {0.8*$x}] [expr {$x/2}] $alpha
	}
    }
    fvector M $map
    return $M
}

proc prism {{n 64}} {
    set alpha 1
    set map {}
    foreach x [linspace 0 1 $n] { lappend map $x 1 1 1 }
    fvector M $map
    fhsv2rgb $n M
    return $M
}

proc gray {{n 64}} {
    set alpha 1
    set map {}
    foreach x [linspace 0 1 $n] { lappend map 0 0 $x 1 }
    fvector M $map
    fhsv2rgb $n M
    return $M
}

proc bone {{n 64}} {
    set alpha 1
    set map {}
    foreach x [linspace 0 1 $n] {
	if {$x < 3./8.} {
	    lappend map [expr {7*$x/8}] [expr {7*$x/8}] [expr {29*$x/24}] $alpha
	} elseif {$x < 3./4.} {
	    lappend map [expr {7*$x/8}] [expr {(29*$x-3)/24}] [expr {(7*$x+1)/8}] $alpha
	} else {
	    lappend map [expr {(11*$x-3)/8}] [expr {(7*$x+1)/8}] [expr {(7*$x+1)/8}] $alpha
	}
    }
    fvector M $map
    return $M
}

proc graded {{n 64}} {
    
    # Maintain visual distinction between neighbouring colours.
    # For each hue in a list of different hues, use 10 graded values of brightness.
    # Usually the number of sets will be less than 100, but if it is more then
    # repeat the hue list until it is long enough.
    # Hues are given as numbers in [0,6]
    set numsets [expr {$n/10}]
    set huelist {}
    foreach hue {1 2 2.9 3.3 5 0.3 1.5 2.4 3.2 4.1 5.6} { 
	lappend huelist [expr {$hue/6.}]
    }
    while {[llength $huelist] < $numsets} { lappend huelist $huelist }
    set valuelist [linspace 0.4 1. 10]
    
    # Do all full gradations
    set map {}
    foreach hue [lrange $huelist 0 [expr {$numsets-1}]] {
	foreach value $valuelist {
	    lappend map $hue 1. $value 1.
	}
    }

    # Fill the remainder of the list with the next gradation.
    set hue [lindex $huelist $numsets]
    foreach value [lrange $valuelist 0 [expr {$n-10*$numsets-1}]] {
	lappend map $hue 1. $value 1.
    }
    
    # Convert to an rgb map
    fvector M $map
    fhsv2rgb $n M
    return $M
}

set maps {bright copper gray bone prism graded}

}

proc clip {x lo hi} {
    if { $x < $lo } { 
	return $lo
    } elseif { $x > $hi } { 
	return $hi     
    } else { 
	return $x 
    }
}

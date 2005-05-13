
proc fvector {name args} { 
    upvar $name vec
    set nargin [llength $args]
    if {$nargin == 0} {
	binary scan $vec f* h
	return $h
    } elseif {$nargin == 1} {
        set vec [binary format f* [lindex $args 0]]
    } else {
	error "wrong # args: should be \"fvector name ?value_list\""
    }
}

proc flimits {name} {
    upvar $name vec
    set s [fvector vec]
    set min [lindex $s 0]
    set max [lindex $s 0]
    foreach v $s {
	if {$v < $min} {
	    set min $v
	} elseif {$v > $max} {
	    set max $v
	}
    }
    return [list $min $max]
}

proc edges {centers} {
  if { [llength $centers] == 1 } {
    if { $centers == 0. } {
      set e {-1. 1}
    } elseif { $centers < 0. } {
      set e [list [expr {2.*$centers}] 0.]
    } else {
      set e [list 0 [expr {2.*$centers}]]
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

proc integer_edges {n} {
  set edges {}
  for {set p 0} {$p <= $n} {incr p} {
    lappend edges [expr {$p+0.5}]
  }
  return $edges
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

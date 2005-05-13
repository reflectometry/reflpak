set verbose 0
proc try {statements} {
    if {$::verbose} { puts "Trying $statements" }
    if {[catch {uplevel $statements} result]} {
        puts "[info script] fail: $result\n$statements"
    }
}

proc fail {statements {with {}} {msg {}}} {
    if {$::verbose} { puts "Trying $statements" }
    if {[catch {uplevel $statements} result]} {
        if {![string equal $msg $result]} {
	    puts "[info script] fail: in $statements\nexpected \"$msg\"\nbut got  \"$result\"\n"
        }
    } else {
        puts "[info script] fail: no error\n$statements"
    }
}  

proc assert_vector {name b {tol 0.}} {
    upvar $name vec
    binary scan $vec f* a
    if {[llength $a] != [llength $b]} {	error "length of a and b differ" }
    foreach ai $a bi $b { 
	if {abs($ai-$bi)>$tol} { error "expected { $b } but got { $a }" }
    }
}

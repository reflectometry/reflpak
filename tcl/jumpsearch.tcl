# Jump search function which tries to evade local minima.
#
# From the options > tcl console menu, do the following:
#
#   source jumpsearch.tcl
#   jumpsearch $parameter $step $scale $minstep
#
# E.g.,
#
#   jumpsearch td2 50 0.6 10
#
#
# The search algorithm:
#
#    least squares descent at current point
#    while step > end
#       step right by step and descend
#       if improvement, continue stepping right
#       otherwise
#          step left by step and descend
#          if improvement, continue stepping left
#          otherwise
#             if last descent didn't move, return
#       decrease step by a factor of scale
#    return
#
# The user interface records the set of values searched and the
# resulting chi-squared.
#
# Paul Kienzle
# 2004-01-28


# create a control dialog
proc jumpinit {par} {
  vector create ::jsx ::jsy
  ::jsx delete :
  ::jsy delete :
  set ::jshalt 0

  if {[winfo exists .js]} {
    raise .js
  } else {
    toplevel .js
    graph .js.graph
    active_graph .js.graph
    .js.graph legend conf -hide yes
    .js.graph element create chisq -xdata ::jsx -ydata ::jsy \
	-pixels 4 -linewidth 0 -fill {}
    button .js.stop -text Stop -command { jumphalt "user abort" }
    label .js.message -relief ridge -anchor w -textvariable ::jsmessage
    grid .js.graph -sticky news
    grid .js.stop -sticky e
    grid .js.message -sticky ew
    grid rowconf .js 0 -weight 1
    grid columnconf .js 0 -weight 1
  }

  .js.stop conf -state normal
  .js.graph conf -title "Jump search of parameter $par"
  .js.graph axis conf y -title "Chi^2"
  .js.graph axis conf x -title "$par"
  eval [linsert [.js.graph marker names] 0 .js.graph marker delete]
  return .js
}

# halt the process, either by user or under program control
proc jumphalt {msg} {
  set ::jshalt 1
  gmlayer halt
  .js.stop conf -state disabled
  set ::jsmessage $msg
}

# macro to take a step, update the graph, etc.
proc jumpstep { start msg } {
  upvar field field
  upvar num num
  upvar v v
  upvar chisq chisq

  layer $num $field $start
  # XXX FIXME XXX shouldn't need read_reflectivity to get chisq
  # XXX FIXME XXX may not want the extra reflectivity calc here
  send_layout
  read_reflectivity
  set chisq_start [gmlayer send chisq]
  set ::jsmessage "$msg at $start"
  do_fit                              ;# find nearest local minimum
  if {$::jshalt} {                    ;# check for user abort
    return -code return
  }
  # XXX FIXME XXX shouldn't need read_reflectivity to get chisq
  read_reflectivity
  set chisq [gmlayer send chisq]      ;# remember chisq
  set v [layer $num $field]           ;# remember parameter value
  ::jsx append $v
  ::jsy append $chisq
  .js.graph marker create text -text [::jsx length] -outline red \
	-anchor s -coords [list $v $chisq] -fill antiquewhite -under 1
  .js.graph marker create line -coords [list $start $chisq_start $v $chisq]
}

proc stepsearch {par min max frames} {
  parse_par $par field num
  jumpinit $par
  gmlayer vanone; gmlayer va$par      ;# make sure only par is varying

  chisqplot $par $min $max [expr {5*$frames}]
  catch {
    .js.graph element create scan -xdata scan_p -ydata scan_chi \
  	-pixels 3 -color green
  }

  set step [vector expr "($max - $min)/($frames-1)"]
  for {set i 0} { $i < $frames } { incr i } { 
    jumpstep $min "descent" 
    set min [expr {$min+$step}]
  }

  jumphalt "done"
}


proc jumpsearch {par step scale stop} {
  if { $scale >= 1. } { error "scale must be less than 1." }
  parse_par $par field num
  jumpinit $par

  # start out in a clean state
  gmlayer vanone; gmlayer va$par      ;# make sure only par is varying
  jumpstep [layer $num $field] "initial descent"
  set best_v $v
  set best $chisq

  while { $step > $stop } {
    # determine which direction to jump by
    # trying each of them and seeing which
    # leads to an improvement in chisq
    jumpstep [expr {$best_v + $step}] "check +$step"
    if { $chisq < $best-1e-9 } {
        set direction +
    } else {
      jumpstep [expr {$best_v - $step}] "check -$step"
      if { $chisq < $best-1e-9 } {
        set direction -
      } else {
        if { abs($v-$best_v) < 1e-10 } {
	  jumphalt "stuck in valley at $v"
          return
        } else {
          set step [expr {$scale*$step}]
          continue
        }
      }
    }

    while { $chisq < $best } {
      set best_v $v
      set best $chisq
      jumpstep [expr $best_v $direction $step] \
	"continue $direction$step"
    }
    set step [expr {$scale*$step}]
  }

  jumphalt "can't find better minimum within $step of $best_v"
}


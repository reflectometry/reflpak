# Script to turn a starkit into a standalone interpreter.
# Place it in e.g., ncnrpack.vfs/main.tcl then run sdx wrap
#     copykit sdx.kit wrap ncnrpack -runtime Tclkit
# where copykit is a copy of the Tclkit runtime you are 
# using.  DQKit with BWidget, TkTable and tkcon is a good
# combination.

package require starkit
starkit::startup
switch -glob -- [lindex $argv 0] {
  {} {
    package require Tk
    package require tkcon
    set ::tkcon::PRIV(protocol) exit
    tkcon show
  }
  -v {
    foreach p [package names] { puts "$p [package versions $p]" }
  }
  -h - -? {
    puts {
Standalone Tcl/Tk interpreter with BLT, BWidgets and TkTable

ncnrpack
  start Tcl console for entering commands directly
ncnrpack source.tcl args
  run script in source.tcl
ncnrpack -v
  list versions of available packages
ncnrpack -h
  print this help message
    }
  }
  default {
    set p [lindex $argv 0]
    set argv [lrange $argv 1 end]
    source $p
  } 
} 

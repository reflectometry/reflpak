# Create configuration file to be used at run-time by wrapped application.
# This TCL script is used by the freeWrap Makefile
catch {console show}
if {$argv != ""} {
    set configFile {_freewrap_init.txt}
    if {[catch {open $configFile w} fout]} {
	  _freewrap_message {.} warning ok {freeWrap error!} "Error creating $configFile.\n\n$fout."
	  return 8
	 }
    puts $fout freewrap.tcl
    puts $fout "$::freewrap::progname $::freewrap::patchLevel"
    puts $fout [::freewrap::getStubSize]
    close $fout
    foreach filename $argv {
		exec zip -Af $filename _freewrap_init.txt
	    }
    file delete -force _freewrap_init.txt
   }
exit

# This file performs the following functions while building the freeWrap application:
#     1) strip all comments and white space from the TCL/TK standard scripts
#        and copy to the specified destination
#     2) Add the standard TCL library directories to the auto_path variable
#
# Revison  Date           Author             Description
# -------  -------------  -----------------  ----------------------------------------------
#   5.2    June 2, 2002   Dennis R. LaBelle  1) Added code to append standard TCL 
#                                               directories into init.tcl file.
#   5.3    Aug. 19,2002   Dennis R. LaBelle  2) Made minor modifications relating to how
#                                               the tclIndex files are copied.

update
catch {console show}

set pkg [lindex $argv 0]
puts "argv = $argv"
set scriptdir [file dirname [lindex $argv 1]]
set zipdir [file dirname [lindex $argv 2]]
set autolist {}
switch $pkg {
	 tcl		{
			 set specDirIn($pkg) $scriptdir
			 set specDirOut($pkg) $zipdir
			 set dirlist [glob -types d [file join $scriptdir *]]
			 set speclist($pkg) [list [file join $scriptdir *.tcl] [file join $scriptdir tclIndex]]
			 foreach dirname $dirlist {
				   if {[string first reg $dirname] < 0
					 && [string first encod $dirname] < 0
					 && [string first dde $dirname] < 0
					} {
					   lappend autolist [file tail $dirname]
					   set newdir [file join $zipdir [file tail $dirname]]
					   file mkdir $newdir
					   lappend speclist($pkg) [file join $dirname *.tcl]
					  }
				 }
			 set newdir [file join $zipdir encoding]
			 file mkdir $newdir
			 lappend autolist encoding
			 lappend speclist($pkg) [file join $scriptdir encoding cp1252.enc]
			}
	 tk		{
			 set specDirIn($pkg) $scriptdir
			 set specDirOut($pkg) $zipdir
			 set speclist($pkg) {tclIndex *.tcl}
			}
	 blt		{
			 set specDirIn($pkg) $scriptdir
			 set specDirOut($pkg) $zipdir
			 set speclist($pkg) {tclIndex *.* dd_protocols/*.*}
			}
	 default	{
			 exit 1
			}
     }

foreach spec $speclist($pkg) {
	  set fpath [file join $specDirIn($pkg) $spec]
	  set slen [string length $specDirIn($pkg)]
	  incr slen
	  set filelist [glob -nocomplain $fpath]
	  foreach filename $filelist {
		    set fileout [file join $specDirOut($pkg) [string range $filename $slen end]]
		    puts "$filename  -> $fileout"
		    if {[file extension $filename] == {.tcl}} {
			  set fin [open $filename r]
			  set fout [open $fileout w]
			  while {![eof $fin]} {
				   gets $fin s
				   if {$s != ""} {
					 # get rid of whitespaces
					 set s [string trim $s]

					 #drop empty strings and comments
					 if {([string range $s 0 3] == {#def}) 
					     || (($s != "") && ([string index $s 0] != "#"))} {
						#merge splitted strings back
						if {[string index $s end] == "\\"} {
						    puts -nonewline $fout [string replace $s end end " "]
						   } {
							 puts -nonewline $fout $s
							 puts $fout ""
						     }
					    }
					}
				   }
			   close $fin
			   close $fout
			  } { file copy -force $filename $fileout }
		  }
	}
if {$pkg == "tcl"} {
	set initfile [file join $zipdir init.tcl]
	file rename -force $initfile ${initfile}.org
	set fout2 [open $initfile w]
	foreach dir $autolist {
		  set newpath [file join /tcl $dir]
		  # puts $fout2 "lappend env(TCLLIBPATH) $newpath"
		  puts $fout2 "lappend auto_path $newpath"
		}
	set fin2 [open ${initfile}.org r]
	fcopy $fin2 $fout2
	close $fin2
	close $fout2
	file delete -force ${initfile}.org
   }
exit 0

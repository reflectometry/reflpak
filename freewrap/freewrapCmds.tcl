# freeWrap is Copyright (c) 1998-2001 by Dennis R. LaBelle (labelled@nycap.rr.com)
# All Rights Reserved.
#
# This software is provided 'as-is', without any express or implied warranty. In no
# event will the authors be held liable for any damages arising from the use of 
# this software. 
#
# Permission is granted to anyone to use this software for any purpose, including
# commercial applications, and to alter it and redistribute it freely, subject to
# the following restrictions:
#
# 1. The origin of this software must not be misrepresented; you must not claim 
#    that you wrote the original software. If you use this software in a product, an
#    acknowledgment in the product documentation would be appreciated but is not
#    required.
#
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software. 
#
# 3. This notice may not be removed or altered from any source distribution.
#
# This TCL/TK script provides the freeWrap namespace commands.
#
# Revision history:
#
# Revison  Date           Author             Description
# -------  -------------  -----------------  --------------------------------------------
#   5.0    Dec. 31, 2001  Dennis R. LaBelle  1) Extracted freeWrap namespace items to
#                                               this separate file.
#                                            2) Added ::freewrap::reconnect procedure to
#                                               reattach archives to the freeWrap stub
#                                            3) Replaced the TCL "source" command in order
#                                               to handle freeWrap encrypted scripts.
#                                            4) Original "source" command renamed to 
#                                               ::freewrap::source
#                                            5) Added ::freewrap::getStubSize procedure.
#                                            6) Added ::freewrap::encrypted variable.
#							   7) Added replacement for glob command using
#								some source code from Dave Bodenstab
#   5.1    Jan. 26, 2002 Dennis R. LaBelle   1) Adjusted setting of auto_path variable.
#                                            2) Fixed error in ::freewrap::getStubSize
#                                               that occurred since file names are no
#                                               longer converted to lower case.
#                                            3) Replaced the TCL "info" command in order
#                                               to handle the "info script" command for
#                                               wrapped files.
#   5.2    June  2, 2002 Dennis R. LaBelle   1) Removed replacement glob command.
#                                            2) Fixed unpack procedure to prevent addition
#                                               of newline character at end of unpacked file.
#                                            3) Removed reroot procedure. Correct root directory
#                                               is now established in main.c file.
#                                            4) Adjusted setting of auto_path variable to include
#                                               /blt directory when running BLT version.
#   5.3    Aug. 17, 2002 Dennis R. LaBelle   1) Added errormsg variable to ::freewrap namespace. Modified
#                                               ::freewrap::unpack proc to set this variable if file cannot
#                                               be written to the destination.
#
#   5.4    Nov. 23, 2002 Dennis R. LaBelle   1) ::freewrap::unpack proc now sets the timestamp of the copied
#                                               file to that of the wrapped copy.

# create ::freeWrap namespace
#
namespace eval ::freewrap:: {
variable patchLevel {5.5}     ;# Current freeWrap revision level
variable progname {}          ;# Official freeWrap program name
variable encrypted 0          ;# Set to 1 if attached scripts are encrypted
variable scriptFile {}        ;# Name of executing script file when freeWrap's SOURCE replacement procedure is used.
variable errormsg {}          ;# Last freeWrap error message.

proc normalizePath { filename} {
# Return absolute path with . and .. resolved
global tcl_platform

if {$tcl_platform(platform) == "windows"} {
    if {[string index $filename 1] == {:}} {
	  set newpath [string range $filename 2 end]
	 } { set newpath $filename }
   } { set newpath $filename }

return $newpath
}


proc isSameRev { filename} {
# Checks whether the specified file contains a copy of the same freeWrap
# revision as the currently executing program.
#
# Returns: 0, if file is not a copy
#	  1, if file is a copy
#
set rtnval 0

if {$filename != ""} {
   if {![catch {::zvfs::mount $filename /fwtestsameas}]} {
      # retrieve the information for the specified file.
      set fwRev unknown
      set stubsize 0
      if {[::zvfs::exists /fwtestsameas/_freewrap_init.txt]} {
	set fin [open /fwtestsameas/_freewrap_init.txt r]
	gets $fin line
	gets $fin fwRev
	gets $fin stubsize
	close $fin
	unset fin
        }
      ::zvfs::unmount $filename

      # retrieve the information for the currently running program
      set fwRevCur current
      set stubsizeCur 0
      if {[::zvfs::exists /_freewrap_init.txt]} {
	set fin [open /_freewrap_init.txt r]
	gets $fin line
	gets $fin fwRevCur
	gets $fin stubsizeCur
	close $fin
	unset fin
        }
       if { ($fwRev == $fwRevCur) && ($stubsize == $stubsizeCur) } { set rtnval 1 }
      }
   }
return $rtnval
}


proc unpack {path {destdir {}}} {
# Unpack a file from ZVFS into a native location.
#
# path    = ZVFS path of file to unpack
# destdir = optional destination directory for unpacked file.
#
# Returns: on success, the name of the native file
#          on failure, an empty string
#
global env
global tcl_platform
variable errormsg

set filename {}
if {[file exists $path]} {
    if {$destdir == {}} {
	  if {$tcl_platform(platform) == "windows"} {
		set destdir [file attributes $env(TEMP) -longname]
	     } { set destdir /tmp }
	 }
    if {![file isdirectory $destdir]} { return {}}
    set dest [file join $destdir [file tail $path]]
    if {[file exists $dest]} {
		# The file has already been copied once.
		set filename $dest
	 } {
		# copy the file to its temporary location
		set fin [open $path r]
		if {[catch {open $dest w} fout]} {
			set errormsg $fout
			close $fin
		   } {
			 fconfigure $fin -translation binary -buffersize 500000 -encoding binary
			 fconfigure $fout -translation binary -buffersize 500000 -encoding binary
			 set ext [file extension $path]
			 if {$::freewrap::encrypted && [lsearch {.tcl .tk .tsh} $ext] != -1} {
				  puts -nonewline $fout [::freewrap::decrypt [read $fin]]
			    } { puts -nonewline $fout [read $fin] }
			 close $fin
			 close $fout
			 set filename $dest
			 catch {file mtime $dest [file mtime $path]}
		     }
	   }
   }
return $filename
}


proc iswrapped {filename} {
# Determine whether a file is a freeWrap application
#
# Returns:	1, if file is a freeWrap application
#           0, if file is NOT a freeWrap application

set rtnval 0

# get name of the running application
set execname [info nameofexecutable]
if {[file type $execname] == "link"} {
	set execname [file readlink $execname]
   }

# Is the user asking about the current application?
if {$filename == $execname} {
    set rtnval 1
   } {
	# mount the file
	if {![catch {::zvfs::mount $filename /fwtemp_mount} result]} {
	    if {[::zvfs::exists /fwtemp_mount/_freewrap_init.txt]} { set rtnval 1 }
	    ::zvfs::unmount $filename
	   }
     }
return $rtnval
}


proc getStubSize {{stubname {}}} {
# Retrieve the size of the freeWrap stub associated with file stubname.
#
# Returns: the size of the stub in bytes or 0, if the stub size cannot be determined or the file does not exist.
global tcl_platform
          
set rtnval 0

# get name of currently executing program
set execname [info nameofexecutable]
if {[file type $execname] == "link"} {
    set execname [file readlink $execname]
   }
set execExt [string tolower [file extension $execname]]

if {$stubname == ""} {
    # return the stub size for the currently executing program.
    if {[::zvfs::exists /_freewrap_init.txt]} {
	  set fin [open /_freewrap_init.txt r]
	  gets $fin line
	  gets $fin line
	  gets $fin line
	  close $fin
	  unset fin
	  if {$line != {}} {
		# simply return the currently stored value
		return $line
	     }
	 }
    set stubname $execname

   } elseif {![file exists $stubname]} { return 0 }

# Extract ZIP executable so we can run it.
set zipProgram [unpack zip$execExt]

# Use ZIP program to retrieve stub size
if {$zipProgram != ""} {
	if {$tcl_platform(platform) == {unix}} {
		file attributes $zipProgram -permissions 0700
	   }
	if {[string length $execExt] == 0} { append stubname . }
	catch {exec $zipProgram -T $stubname} result
	set signature {found a preamble of }
	set pos [string first $signature $result]
	incr pos [string length $signature]
	if {$pos > 0} {
	    set pos2 [string first byte $result]
	    incr pos2 -2
	    set rtnval [string range $result $pos $pos2]
	   }
   }

return $rtnval
}


proc reconnect {src dest} {
# Copy the specified mounted source file to the specified destination file name.
# Reattach the freeWrap stub to the beginning of the destination file.
#
# Returns: 0, on success
#          1, on failure

global tcl_platform

set rtnval 1
set stubsize 0
# get name of currently executing program
set execname [info nameofexecutable]
if {[file type $execname] == "link"} {
    set execname [file readlink $execname]
   }

# Extract ZIP executable so we can run it.
if {$tcl_platform(platform) == "unix"} {
    # under UNIX, our file must have an extension of .zip in order to readjust
    # the preamble (i.e use the zip -A option)
    set wdest ${dest}.zip
    set zipProgram [unpack /zip] 
    file attributes $zipProgram -permissions 0700 
   } {
	set wdest $dest
	set zipProgram [unpack /zip.exe]
      }

set stubsize [getStubSize]
if {$stubsize > 0} {
    if {![catch {open $wdest w} fout]} {
	  # get name of currently executing program
	  set execname [info nameofexecutable]
	  if {[file type $execname] == "link"} {
		set execname [file readlink $execname]
	     }

	  # copy the freeWrap stub
	  if {![catch {open $execname r} fin]} {
		fconfigure $fin -translation binary -buffersize 500000 -encoding binary
		fconfigure $fout -translation binary -buffersize 500000 -encoding binary
		fcopy $fin $fout -size $stubsize
		close $fin
		if {[catch {open $src r} fin]} {
			puts $fin
			close $fout
			file delete -force $dest
		   } {
			fconfigure $fin -translation binary -buffersize 500000 -encoding binary
			puts -nonewline $fout [read $fin]
			close $fout
			catch {exec $zipProgram -A $wdest} result
			if {$wdest != $dest} {
			    # under UNIX, rename file to final name and mark it
			    # as executable
			    file rename -force $wdest $dest
			    file attributes $dest -permissions 0700
			   }
			set rtnval 0
		     }
	     } { puts $fin }
	 } { puts $fout }
   }

return $rtnval
}


# File extension association procedures for Windows.
# 
# These procedures are based upon (with minor modifications) the ms_shell_setup package by 
# Earl Johnson whose Copyright notice follows.

  # This is a simple wrapper arround the registry commands provided by the standard TCL
  # installation on Windows.

  # By using this library you advoid some details of the registry use, but not all.  Remember
  # to treat your registry with caution!

  #
  # Copyright (c) 1999
  # Earl Johhnson
  # earl-johnson@juno.com
  # http://www.erols.com/earl-johnson
  #
  # Permission to use, copy, modify, distribute and sell this software
  # and its documentation for any purpose is hereby granted without fee,
  # provided that the above copyright notice appear in all copies and
  # that both that copyright notice and this permission notice appear
  # in supporting documentation.  Earl Johnson makes no
  # representations about the suitability of this software for any
  # purpose.  It is provided "as is" without express or implied warranty.
  #

if {$tcl_platform(platform) == "windows"} { package require registry }

# Check whether a key exists for an extension
# Example: shell_assoc_exist .txt => 1
# Example: shell_assoc_exist .NEVER => 0
proc shell_assoc_exist {extension} {
	if {[catch {registry get "HKEY_CLASSES_ROOT\\$extension" ""}]} {set ret 0} {set ret 1}
	return $ret
}

# Show whether a file type exists
# Example: shell_fileType_exist txtfile => 1
# Example: shell_fileType_exist NEVER => 0
proc shell_fileType_exist {fileType} {
	if {[catch {registry get "HKEY_CLASSES_ROOT\\$fileType" ""}]} {set ret 0} {set ret 1}
	return $ret
}

# Creates a file extension and associates it with fileType.
# Example: shell_fileExtension_setup .txt txtfile
# Remove connection between extension and fileType
# Example: shell_fileExtension_setup .txt ""
proc shell_fileExtension_setup {extension fileType} {
  registry set "HKEY_CLASSES_ROOT\\$extension" "" $fileType
}

# Creates a fileType
# Example: shell_fileType_setup txtfile "Text Document"
proc shell_fileType_setup {fileType title} {
  registry set "HKEY_CLASSES_ROOT\\$fileType" "" $title
}

# Creates a open command on left click.
# Allows sets action for double click.
# Example: shell_fileType_open txtfile "C:\WINDOWS\NOTEPAD.EXE %1"
# Please note the %1 for passing in file name
proc shell_fileType_open {fileType openCommand} {
   registry set "HKEY_CLASSES_ROOT\\$fileType\\Shell\\open\\command" "" $openCommand"
}

# Creates a print command on left click.
# Example: shell_fileType_print txtfile "C:\WINDOWS\NOTEPAD.EXE /p %1"
# Please note the %1 for passing in file name
proc shell_fileType_print {fileType printCommand} {
   registry set "HKEY_CLASSES_ROOT\\$fileType\\Shell\\print\\command" "" $printCommand
}

# Sets an icon for a fileType
# Example: shell_fileType_icon txtfile "C:\WINDOWS\SYSTEM\shell32.dll,-152"
# Please note the C:\WINDOWS\SYSTEM\shell32.dll,-152
# We can give a name.ico file or a dll or exe file here.
# If a dll or exe file is used the index for resource
# inside it that gives the icon must be given.
proc shell_fileType_icon {fileType icon} {
   registry set "HKEY_CLASSES_ROOT\\$fileType\\DefaultIcon" "" $icon
}

# Sets the quick view for a fileType
proc shell_fileType_quickView {fileType quickViewCmd} {
   registry set "HKEY_CLASSES_ROOT\\$fileType\\QuickView" "" $quickViewCmd
}

# This adds any command you like to a fileType
# Example: shell_fileType_addAny_cmd scrfile config "%1"
proc shell_fileType_addAny_cmd {fileType cmdName cmd} {
   registry set "HKEY_CLASSES_ROOT\\[set fileType]\\Shell\\$cmdName\\command" "" $cmd
}

# Uses some string instead of actual command on right mouse menu.
proc shell_fileType_setMenuName {fileType cmdName str} {
   registry set "HKEY_CLASSES_ROOT\\$fileType\\Shell\\$cmdName" "" $str
}

# Show or not show the extension on the fileType
# Example: shell_fileType_showExt txtfile
proc shell_fileType_showExt {fileType {yesOrNo t}} {
   if {$yesOrNo} {
      registry set "HKEY_CLASSES_ROOT\\$fileType" "AlwaysShowExt" ""
   } {
      registry delete "HKEY_CLASSES_ROOT\\$fileType" "AlwaysShowExt"
     }
}

# Over-ride the windows ordering of commands on right click
# Example: shell_fileType_setCmdOrder txtfile {print open}
proc shell_fileType_setCmdOrder {fileType cmds} {
   set str ""
   foreach cmd $cmds {
		append str "$cmd, "
	   }
   set slen [string length $str]
   if {$slen > 0} {
	 incr slen -3
	 set str [string range $str 0 $slen]
	 registry set "HKEY_CLASSES_ROOT\\$fileType\\Shell" "" $str
	}
}

# Never show extension on fileType
# Example: shell_fileType_neverShowExt txtfile
proc shell_fileType_neverShowExt {fileType {yesOrNo t}} {
   registry set "HKEY_CLASSES_ROOT\\[set fileType]" "NeverShowExt" ""
   if {$yesOrNo} {
      registry set "HKEY_CLASSES_ROOT\\[set fileType]" "NeverShowExt" ""
   } {
      registry delete "HKEY_CLASSES_ROOT\\[set fileType]" "NeverShowExt"
     }
}

# Gets all the commands assocated with a extension
# Example: shell_getCmds file.txt => {open print}
proc shell_getCmds {file} {
  set extension [file extension $file]
  if {[catch {set fileType [registry get "HKEY_CLASSES_ROOT\\$extension" ""]} err_str]} {
	puts $err_str; return; # No assocation or fileType
     }
  if {[catch {set cmds [registry keys "HKEY_CLASSES_ROOT\\$fileType\\shell"]} err_str]} {
	puts $err_str return ; # No commands assocated with file Type
     }
  return $cmds
}

# Gets the implimentation of command given a file extension
# Example: shell_getCmd_imp test.txt open => C:\WINDOWS\NOTEPAD.EXE %1
proc shell_getCmd_imp {file cmd} {
  set extension [file extension $file]
  if {[catch {set fileType [registry get "HKEY_CLASSES_ROOT\\$extension" ""]} err_str]} {
	puts $err_str; return; # No assocation or fileType
     }
  if {[catch {set imp [registry get "HKEY_CLASSES_ROOT\\$fileType\\shell\\$cmd\\command" ""]} err_str]} {
	puts $err_str return ; # No commands assocated with file Type
     }
  set ret $imp
  return $ret
}

# End of file extension association procedures for Windows.

# Export ::freewrap procedures
set name {}
set shortname {}
foreach name [info commands ::freewrap::*] {
	  set shortname [string range $name 12 end]
	  if {[string equal -length 6 $shortname "shell_"]} {
		# shell_ commands can only be used on Windows platforms
		if {$tcl_platform(platform) == "windows"} {
		    namespace export shortname
		   } { rename $name {} }
	     } { namespace export $shortname }
	}
unset name
unset shortname
}

#
# end of ::freeWrap namespace definitions

proc newInfo {args} {
	if {$args == {script} && $args != {}} {
	    return [lindex $::freewrap::scriptFile end]
	   } {
		set cmd "::freewrap::infocmd $args"
            set rc [catch {uplevel 1 $cmd} err]
            if {$rc == 1} {
       	   set ei [split ${::errorInfo} \n]
       	   set eilen [llength $ei]
       	   incr eilen -3
       	   set line [lindex $ei $eilen]
       	   incr eilen -1
       	   set ::errorInfo [join [lrange $ei 0 $eilen] \n]
       	   #regsub {.*body line ([0-9]*).*} $line {\1} line
       	   #append ::errorInfo "\n    (file \"$filename\" line $line)"
       	 } elseif {$rc == 2} { set rc 0 }
            return -code $rc -errorinfo ${::errorInfo} -errorcode ${::errorCode} $err
	     }
}


proc newsource {filename} {
# Replacement for SOURCE command to handle encrypted ZVFS script files.
     if {[catch {open $filename} fd]} {
	   set ec ${::errorCode}
	   set ei ${::errorInfo}
	   set err $fd
	   return -code error -errorinfo $ei -errorcode $ec $err
	  } { set err {} }

     if {[catch {
	   fconfigure $fd -translation binary -buffersize 500000 -encoding binary
	   set data [read $fd]
	   close $fd
	  } err]} {
			set ec ${::errorCode}
			set ei ${::errorInfo}
			catch {close $fd}
			return -code error -errorinfo $ei -errorcode $ec $err
		    }
     if {[::zvfs::exists $filename]} {
	   # named file is part of the ZVFS
	   set firstdir [lindex [file split $filename] 1]
	   if {[::zvfs::exists $filename] 
		 && $::freewrap::encrypted 
		 && ([lsearch {tcl tk blt} $firstdir] == -1) 
		 && ([lsearch {.tcl .tk .tsh} [file extension $filename]] != -1)} {
		 # file is an encrypted script
		 set data [::freewrap::decrypt $data]
		}
	  }

     regsub -all {\r} $data {} cmd	;# remove all carriage returns
     lappend ::freewrap::scriptFile $filename
     set rc [catch {uplevel 1 $cmd} err]
     set ::freewrap::scriptFile [lrange $::freewrap::scriptFile 0 end-1]
     if {$rc == 1} {
	   set ei [split ${::errorInfo} \n]
	   set eilen [llength $ei]
	   incr eilen -3
	   set line [lindex $ei $eilen]
	   incr eilen -1
	   set ::errorInfo [join [lrange $ei 0 $eilen] \n]
	   regsub {.*body line ([0-9]*).*} $line {\1} line
	   append ::errorInfo "\n    (file \"$filename\" line $line)"
	 } elseif {$rc == 2} { set rc 0 }

    return -code $rc -errorinfo ${::errorInfo} -errorcode ${::errorCode} $err
}

# Establish proper freeWrap program name for the operating system
# The extname variable is set from the main.c or tclAppInit.c code.
switch $tcl_platform(platform) {
      "unix"	{ set ::freewrap::progname "freewrap$extname" }
      "windows"	{ set ::freewrap::progname "freewrap${extname}.exe" }
       default	{
			  if {[info exists tk_patchLevel]} {
                        tk_messageBox -parent . -icon warning -type ok -title "freeWrap$extname" -message "Sorry. freeWrap$extname is only supported on Unix and Windows."
                       } { puts "freeWrap$extname: Sorry. freeWrap$extname is only supported on Unix and Windows." }
                    exit 4
			}
     }

# re-define the SOURCE command
rename source ::freewrap::source
rename newsource source

# re-define the INFO command
rename info ::freewrap::infocmd;rename newInfo info

# Adjust auto_path variable. Strip out unwanted default paths.
global auto_path
global blt_library

set newpath {}
foreach path $auto_path {
	set prefix [string range $path 0 3]
	if {$prefix == {/tcl} || $prefix == {/tk}} {
	    lappend newpath $path
	   }
      }
set auto_path $newpath
if {$extname == {blt}} {
    lappend auto_path {/blt}
    set blt_library {/blt}
   }

# remove variables that are no longer necessary
unset newpath
unset path
unset prefix
unset extname

# load the default character encoding
encoding system /tcl/encoding/cp1252

# Load the main application script.
if {[::zvfs::exists /_freewrap_init.txt]} {
    set fin [open /_freewrap_init.txt r]
    gets $fin mainfile
    close $fin
    unset fin
    if {[string index $mainfile 0] == { } } { set ::freewrap::encrypted 1 }
        set mainfile [string trim $mainfile]
	  if {[string index $mainfile 1] == {:}} { set mainfile [string range $mainfile 2 end] } 
        if {[string index $mainfile 0] != {/}} { set mainfile /$mainfile }
        if {$mainfile != {freewrap.tcl}} { set tcl_interactive 0 }
        if {[catch {source $mainfile} rtnval]} {
            catch {console show}
            puts "Error sourcing $mainfile: $rtnval"
           } {
              if {[info exists mainfile]} {
			if {[file tail $mainfile] == "freewrap.tcl"} {
				_freewrap_main
				rename _freewrap_main ""
			   }
			unset mainfile
		     }
              if {![info exists tk_patchLevel] && $tcl_interactive == 0} {
			exit 0
		     }
             }
   } {
      catch {console show}
      puts "freeWrap configuration file (_freewrap_init.txt) not found.\nUnable to determine which script to run."
     }


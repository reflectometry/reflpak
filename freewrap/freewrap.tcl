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
#
# This TCL/TK script is used to produce the freeWrap program.
#
# freeWrap allows creation of stand-alone TCL/TK executables without using a
# compiler. Renaming freeWrap to some other file name causes freeWrap to
# behave as a a stand-alone, single-file WISH that can be used to run any 
# TCL/TK script. 
#
# Revision history:
#
# Revison  Date           Author             Description
# -------  -------------  -----------------  ------------------------------------
#     0    Aug. 21, 1998  Dennis R. LaBelle  Original work
#   1.0    Sep. 19, 1998  Dennis R. LaBelle  Public issue
#   2.0    May  23, 1999  Dennis R. LaBelle  Implemented using MKTCLAPP (formerly Embedded TCL).
#   2.1    May  29, 1999  Dennis R. LaBelle  Reissued with substitute CONSOLE command.
#                                            Freewrap did not work on Windows machines without
#                                            TCL/TK installed if the normal WISH console was used.
#   2.2    June  2, 1999  Dennis R. LaBelle  Added a replacement for flush command to handle the STDOUT and STDERR channels
#   2.3    June 22, 1999  Dennis R. LaBelle  Modified to use the normal WISH console under Windows.
#   3.0    July 18, 1999  Dennis R. LaBelle  1) Added ability to wrap multiple scripts.
#                                            2) Added ability to wrap binary image files. (GIF, PPM, PGM)
#                                            3) Added automatic encryption of wrapped files.
#   3.1    Aug. 15, 1999  Dennis R. LaBelle  1) Corrected improper decryption of additional wrapped files
#                                            2) Corrected handling of line continuations (\ character) under Windows
#   3.2    Sept  8, 1999  Dennis R. LaBelle  1) Now uses [info nameofexecutable] instead of argv0
#                                            2) Added _freewrap_patchLevel variable to indicate Freewrap revision number
#                                            3) Added copyright notices
#   3.3    Oct.  4, 1999  Dennis R. LaBelle  1) Reinstated TCL "load" command in support of stubs load interface
#                                            2) Added -f command line option for freewrap
#   4.0    Dec.  5, 1999  Dennis R. LaBelle  1) Added curly brackets around wrapped file names to account for file
#                                               paths that include spaces.
#                                            2) Removed unused _freewrap_puts and _freewrap_flush procedures
#                                            3) Changed format for storing files at end of freewrap. Done to support
#                                               file distribution capabilities.
#                                            4) Binary files are now stored without first converting to a Hex string
#                                            5) Assigned exit function to WM_DELETE_WINDOW event of root window.
#                                            6) Added _freewrap_stubsize variable to indicate size of base Freewrap executable.
#                                            7) Added -p command line option to wrap distribution packages
#                                            8) tcl_interactive now set to 1 if used as stand-alone wish shell.
#   4.1    Mar. 26, 2000  Dennis R. LaBelle  1) Added a -b option for wrapping any type of binary file.
#                                            2) Added _freewrap_getExec procedure
#   4.2    Apr. 23, 2000  Dennis R. LaBelle  1) Replaced use of _freewrap_getExec proc in _freewrap_pkgfilecopy with in-line code.
#   4.3    May  17, 2000  Dennis R. LaBelle  1) Fixed "Main application script not specified" error when "\" was used in script name.
#                                               This problem was introduced by a "helpful" feature of TCL 8.3.0
#   4.4    Oct.  6, 2000  Dennis R. LaBelle  1) Added a -w "wrap using" option to specify the file to use as the freeWrap stub. This
#                                               allows cross-platform creation of wrapped applications.
#                                            2) Created ::freewrap namespace and moved all existing freewrap variables, commands and
#                                               procedures into it.
#                                            3) Added ::freewrap::getSpecialDir and ::freewrap::shortcut commands
#                                            4) Incorporated ms_shell_setup procedures by Earl Johhnson and included into
#                                               ::freewrap namespace
#   5.0    Dec.  31, 2001 Dennis R. LaBelle  1) Changed method of storing files at end of freeWrap. Converted to a ZIP file format.
#   5.3    Aug.  18, 2002 Dennis R. LaBelle  1) Corrected problems produced by interpretation of path name for main file to wrap.
#   5.4    Oct.  26, 2002 Dennis R. LaBelle  1) Output files are now placed in the current directory instead of the main source
#                                               file's directory.

proc _freewrap_normalize {filename} {
# Return absolute path with . and .. resolved
global tcl_platform

set curDir [pwd]
if {$tcl_platform(platform) == "windows"} {
    set curDir [string range $curDir 2 end]
   }
set fullpath [file join $curDir $filename]
set newpath {}
foreach item [file split $fullpath] {
	  switch -- $item  {
		.	{ }
		..	{
			 set slen [llength $newpath]
			 incr slen -2
			 set newpath [lrange $newpath 0 $slen]
			}
		default	{ lappend newpath $item }
	         }
           }
eval "set rtnval \[file join $newpath\]"
return $rtnval
}


proc _freewrap_getExec {} {
# Returns the name of the executable file, taking into account any symbolic links
set fname [info nameofexecutable]
if {[file type $fname] == "link"} {
	set fname [file readlink $fname]
   }
return $fname
}


proc _freewrap_message {parent icon type title message} {
global tk_patchLevel

if {[info exists tk_patchLevel]} {
    tk_messageBox -parent $parent -icon $icon -type $type -title $title -message $message
   } { puts "$title: $message" }
}


proc _freewrap_wrapit {cmdline {DelList {}}} {
# Create a single file executable out of the specified scripts and image files.
# This is done by appending the specified files to the end of a copy of the freewrap program.
# 
# cmdline = freeWrap style command line
# DelList = list of files to remove from the current application archive section
#
global argv0
global encrypt
global tcl_platform
global env

# List of extensions recognized as belonging to binary files.
# Binary files must be handled differently (i.e. converted to hexadecimal string notation).
#
set ScriptExts {.tcl .tk .tsh}

# Process command line arguments
set argctr 0
set argstr ""
set LookInFile 0
set getStubFile 0
set stubfile {}
foreach arg $cmdline {
	  switch -- $arg {
		   ""		{
				 # Empty argument. Do nothing
				}
		   {-e}	{
				 # turn off default encryption
				 set encrypt 0
				}
		   {-f}	{
				 # Next argument is the name of a file containing a list of files, one per line
				 set LookInFile 1
				}
		   {-w}	{
				 # Next argument is the name of the file to use as the freeWrap stub.
				 # This option allows cross-platform construction of freeWrapped programs.
				 set getStubFile 1
				}
		   default	{
				 if {$LookInFile} {
					 set LookInFile 0
                               if {![catch {open $arg} fin]} {
                                   while {![eof $fin]} {
                                          gets $fin line
                                          set line [string trim $line]
                                          if {$line != ""} {
                                              if {[lsearch $ScriptExts [string tolower [file extension $line]]] != -1} {
                                                  lappend argstr s$line
                                                 } { lappend argstr b$line }
                                              incr argctr
                                             }
                                         }
                                   close $fin
                                  } {
						 catch {wm withdraw .}
						 _freewrap_message {.} warning ok {freeWrap error!} "Could not find list file: $arg.\n\nWrapping aborted."
						 return 10
						}
                            } elseif {$getStubFile} {
                                      regsub -all {\\} $arg {/} stubfile
                                      set getStubFile 0
                                     } {
                                        if {[lsearch $ScriptExts [string tolower [file extension $arg]]] != -1} {
                                            lappend argstr s$arg
                                           } { lappend argstr b$arg }
                                        incr argctr
                                       }
				}
             }
      }
if {$argctr > 0} {
    set stub [_freewrap_getExec]
    set OSext [string tolower [file extension $stub]]
    if {$stubfile != {}} { set stub $stubfile }
    set DESText [string tolower [file extension $stub]]
    if {[string index [lindex $argstr 0] 0] != "s"} {
	  catch {wm withdraw .}
	  _freewrap_message {.} warning ok {freeWrap error!} {No main application script specified.}
	  return 1
	 }
    set filename [string range [lindex $argstr 0] 1 end]
    if {[file exists $filename]} {
	  set fname [file root [file tail $filename]]
	  set execname ${fname}$DESText
	  set zipname  [file join ${fname}.zip]
	 } {
	    catch {wm withdraw .}
	    _freewrap_message {.} warning ok {freeWrap error!} "Could not find $filename to wrap."
	    return 6
	   }

    # Copy freeWrap program itself to produce initial output file.
    file copy -force $stub $zipname

    if {$tcl_platform(platform) == {unix}} {
	file attributes $zipname -permissions 0700
       } {
		if {[file attributes $zipname -readonly] == 1} {
		    file attributes $zipname -readonly 0
		   }
	   }

    # Get size of the freeWrap stub we will be using.
    set stubsize [::freewrap::getStubSize $zipname]

    # Extract ZIP executable so we can run it.
    set zipProgram [::freewrap::unpack /zip$OSext]
    if {$zipProgram == {}} {
	  catch {wm withdraw .}
	  _freewrap_message {.} warning ok {freeWrap error!} "Unable to locate ZIP \(/zip$OSext\) program."
	  return 2
	 } {
		if {$tcl_platform(platform) == {unix}} {
			file attributes $zipProgram -permissions 0700
		   }
	   }
    if {[file exists $zipname]} {
	  # remove the specified files from the archive
	  set cmd "exec \"$zipProgram\" \"$zipname\" -Ad $DelList"
	  catch $cmd result

	  set totSize 0
	  set cmd "|\"$zipProgram\" -A9q \"$zipname\" -@"
	  set mainfile {}
	  set mainfile_org {}
	  set namelist {}
	  set orgPath {}
	  set encPath {}
	  if {$tcl_platform(platform) == "windows"} {
		set tempdir [file attributes $env(TEMP) -longname]
	     } { set tempdir /usr/tmp }
	  while {$argctr > 0} {
			set pos [expr $argctr - 1]
			set filename [lindex $argstr $pos]

			# Add file to ZIP command line
     	            set filetype [string index $filename 0]
		      set srcname [_freewrap_normalize [string range $filename 1 end]]
			if {[file exists $srcname]} {
			    if {$argctr == 1} {
				  # We are processing the main script
				  set mainfile $srcname
				 }
			    if {$encrypt && ($filetype == {s})} {
				  set file_org [file join $tempdir [file tail $srcname]]

				  # check whether the current file has already been encrypted
				  if {[lsearch -exact $orgPath $file_org] != -1} {
					# We need to move the current list of encrypted files to the archive
					# so that we don't overwrite a previous file by the same name.
					set fout [open $cmd r+]
					puts $fout $namelist
					flush $fout
					close $fout
					set namelist {}

					# Replace the encrypted files by their originals.
					foreach src $orgPath dest $encPath {
						  file rename -force $src $dest
						}

					# Clear out the waiting list of encrypted files
					set orgPath {}
					set encPath {}
				     }

				  lappend encPath $srcname
				  lappend orgPath $file_org

				  # save original file
				  file rename -force $srcname $file_org

				  if {[catch {open $srcname w} fout]} {
					catch {wm withdraw .}
					_freewrap_message {.} warning ok {freeWrap error!} "Insufficient permissions to encrypt $srcname."
					return 9
				     } {
					  # encrypt file
					  fconfigure $fout -translation binary
					  set fin [open $file_org r]
					  fconfigure $fin -translation auto
					  set outstr [read $fin]
					  set outstr [::freewrap::encrypt $outstr]
					  puts -nonewline $fout $outstr
					  close $fin
					  close $fout
					 }
				 }
			    if {($filetype == {b}) && [::freewrap::isSameRev $srcname]} {
				  # process previously freeWrapped file
				  #
				  # Remove freeWrap stub from file
				  set pkgname [file join [file dirname $srcname] fwpkg_[file rootname [file tail $srcname]].zip]
				  file copy -force $srcname $pkgname
				  set cmdstr "exec \"$zipProgram\" -JA \"$pkgname\""
				  catch {eval $cmdstr} result
				  set srcname $pkgname
				 }
			   } {
				catch {wm withdraw .}
			 	_freewrap_message {.} warning ok {freeWrap error!} "Could not find $srcname to wrap."
			      return 4
			     }

			append namelist $srcname\n

			incr argctr -1
		  }

	  # create configuration file to be used at run-time by wrapped application.
	  set configFile {_freewrap_init.txt}
	  if {[file exists _freewrap_init.txt]} {
		catch {wm withdraw .}
	 	_freewrap_message {.} warning ok {freeWrap error!} "Error creating $configFile.\n\nFile already exists."
		return 7
	     }
	  if {[catch {open $configFile w} fout]} {
		catch {wm withdraw .}
	 	_freewrap_message {.} warning ok {freeWrap error!} "Error creating $configFile.\n\n$fout."
		return 8
	     }
	  if {$encrypt} { puts -nonewline $fout { }}
	  puts $fout [::freewrap::normalizePath $mainfile]
	  puts $fout "$::freewrap::progname $::freewrap::patchLevel"
	  puts $fout $stubsize
	  close $fout
	  append namelist $configFile\n

	  # Add all the files to the archive
	  set fout [open $cmd a]
	  puts $fout $namelist
	  flush $fout
	  close $fout

	  # Do some cleanup
	  foreach src $orgPath dest $encPath {
		    file rename -force $src $dest
		  }
	  file delete _freewrap_init.txt

	  # change output file to its final executable name
	  if {[catch {file delete -force $execname} result]} {
		catch {wm withdraw .}
		_freewrap_message {.} warning ok {freeWrap error!} "Unable to overwrite existing copy of $execname.\n\n$execname may be currently running."
		catch {file delete -force $zipProgram}
		return 11
	     } {
		  file rename -force $zipname $execname
		  catch {file delete -force $zipProgram}
		 }
	 }
   } {
	catch {wm withdraw .}
	_freewrap_message {.} warning ok {freeWrap error!} {No main application script specified.}
	return 3
     }
return 0
}


proc _freewrap_main {} {
global argv0
global argv
global argc
global tcl_platform
global encrypt
global tcl_interactive
global tk_patchLevel

catch {console hide}
catch {wm protocol . WM_DELETE_WINDOW { exit 0}}
set _freewrap_progsrc ""

if {"[string tolower [file tail [_freewrap_getExec]]]" == $::freewrap::progname} {
    # wrap an application
    set encrypt 1
    exit [_freewrap_wrapit $argv]
   } {
	 # Run as a stand-alone WISH or TCLSH
	 set _freewrap_argv0 [file tail [_freewrap_getExec]]

       regsub -all {\\} [lindex $argv 0] {/} argv0
       set argv [lrange $argv 1 end]
       incr argc -1
	 set argv1 $argv0

	 # Remove unneeded procedures and variables
	 rename _freewrap_wrapit {}
	 rename _freewrap_getExec {}
	 rename _freewrap_normalize {}

       if {![catch {open $argv1 r} _freewrap_filein]} {
           # Read in the program source code
             set _freewrap_progsrc [read $_freewrap_filein]
             close $_freewrap_filein
             set ::freewrap::scriptFile $argv1
	     unset _freewrap_filein
	     unset argv1

           # Run the program
             rename _freewrap_message {}
             uplevel 1 "$_freewrap_progsrc"
	     if {![info exists tk_patchLevel]} { exit 0 }
          } {
             if {$argv1 == {}} {
                 set tcl_interactive 1
		     if {[info command console] != {}} {
			   rename _freewrap_message {}
                     catch {console show}
                    }
		    } {
                   set msg "Unable to open\n$argv1"
                   catch {wm withdraw .}
                   _freewrap_message {.} warning ok $_freewrap_argv0 $msg
                   exit 5
                  }
		}
     }
}


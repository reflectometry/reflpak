package provide winreg 0.1

namespace eval winreg {
    package require registry
    package require winlink 1.2
    namespace import -force ::winlink::link
    namespace export log warn key filetype fileop extension group desktop link

    variable warnings {}
    variable messages {}

    # Usage: log ?-clear ?msg
    #   Adds another line to the log.
    #   If -clear, clear the log before adding the new message.
    #   Returns the new log.
    proc log { args } {
	variable messages
	set clear false
	if { [lindex $args 0] == "-clear" } {
	    set clear true
	    set args [lrange $args 1 end]
	}
	if { [llength $args] > 1 } { 
            error "[namespace current]::log ?-clear msg" 
        }
	if { $clear } { set messages {} }
	if { [llength $args] == 1 } {
	    set msg [lindex $args 0]
	    if { $messages ne {} } {
		append messages "\n" $msg
	    } else {
		set messages $msg
	    }
	}
	return $messages
    }

    # Usage: warn ?-clear ?msg
    #   Adds another line to the log and to the warnings.
    #   If -clear, clear the warnings before adding the new message.
    #   Returns the new warnings.
    proc warn { args } {
	variable warnings
	set clear false
	if { [lindex $args 0] == "-clear" } {
	    set clear true
	    set args [lrange $args 1 end]
	}
	if { [llength $args] > 1 } { 
            error "[namespace current]::log ?-clear msg" 
        }
	if { $clear } { set warnings {} }
	if { [llength $args] == 1 } {
	    set msg [lindex $args 0]
	    log "!! $msg"
	    if { $warnings ne {} } {
		append warnings "\n" $msg
	    } else {
		set warnings $msg
	    }
	}
	return $warnings
    }

    # Usage: key ?-force key name val
    # Set the name attribute of key to the given string value.  If -force,
    # replace an existing key with a new
    proc key { args } {
	set force false
	if { [lindex $args 0] == "-force" } {
	    set force true
	    set args [lrange $args 1 end]
	}
	if { [llength $args] != 3 } {
        puts "args is actually <$args>"
	    error "[namespace current]::key ?-force key name value"
	}
	foreach {key name val} $args break

	set desc $name
	if { $name == {} } { set desc "(default)" }
	if { [ catch { registry get $key $name } contents ]} {
	    log "regedit: creating $key $desc = <$val>"
	    registry set $key $name $val
	} elseif { $val != $contents } {
	    if { $force } {
		log "regedit: $key $desc contains <$contents>, setting to <$val>"
		registry set $key $name $val
	    } else {
		warn "regedit: $key $desc contains <$contents> --- please set it to <$val>"
		return 0
	    }
	} else {
	    log "regedit: $key $desc already contains <$val>"
	}
	return 1
    }


    # Usage:  filetype type desc exe ?arg ?arg
    # Register a new filetype.
    #   type is the name of the type
    #   desc is the description of the type
    #   exe is the path to the executable
    #   args are the arguments to the executable, one of which is {"%1"}
    # E.g., 
    #   filetype ReflfitFile "Reflfit par file" $reflpak_path fit {"%1"}
    proc filetype { type desc exe args } {
	set root HKEY_CLASSES_ROOT\\$type
	if { [key $root {} $desc] } {
	    key -force $root\\shell {} {}
	    key -force $root\\shell\\Open {} "&Open"
	    key -force $root\\shell\\Open\\command {} \
		"[file nativename [file normalize $exe]] [join $args { }]"
	    return 1
	} else {
	    return 0
	}
    }
    # Usage: fileop type op exe ?arg ?arg
    # Register a new operation on a file type
    proc fileop { type op exe args } {
	set root HKEY_CLASSES_ROOT\\$type
	key -force $root\\shell\\$op {} $op
	key -force $root\\shell\\$op\\command {} \
	    "[file nativename [file normalize $exe]] [join $args { }]"
    }

    # Usage: extension ext type
    # Associate an extension with a file type
    #   ext is everything after the final .
    #   type is the name of the file type
    # Existing associations are left alone, and a warning is issued.
    proc extension { ext type } {
	key HKEY_CLASSES_ROOT\\.$ext {} $type
    }

    # Usage: group ?name
    # Create a program group of the given name in the start menu,
    # returning its path.  If no name is given, return the root of
    # the programs menu.
    proc group {{name {}}} {
	if {$name ne ""} { 
	    set path [file join [link path programsmenu] $name]
	} else {
	    set path [link path programsmenu]
	}
	set path [file native [file normalize $path]]
	file mkdir $path
	return $path
    }

    # Usage: desktop ?name
    # Create a folder on the desktop of the given name, returning
    # its path.  If no name is given, return the path to the desktop.
    proc desktop {{name {}}} {
	if {$name ne ""} { 
	    set path [file join [link path desktop] $name]
	} else {
	    set path [link path desktop]
	}
	set path [file native [file normalize $path]]
	file mkdir $path
	return $path
    }
}

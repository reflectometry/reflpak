# This procedure should be used instead of the normal LOAD command when
# using binary extensions with freeWrap.
#
# Returns: On success, the full file path to the shared library 
#          on the local file system.
#          On failure, an error message starting with the text "Load Error: "
#
rename load ::freewrap::builtin_load
proc load {libfile args} {
    global env
    set rtnval {}
    set fpath [::freewrap::unpack $libfile]

    if {[string length $fpath] == 0} {
	# Couldn't unpack --- let's assume the file is not wrapped and
	# try loading it directly.
	set fpath $libfile
    } else {
	if {[file mtime $libfile] > [file mtime $fpath]} {
	    # The wrapped library file is newer than the existing one on disk.
	    # Let's delete the existing one first, then copy the newer file.
	    file delete -force $fpath
	    set target $fpath
	    set fpath [::freewrap::unpack $libfile]
	    if {[string length $fpath] == 0} {
		error "unable to replace $target with $libfile."
	    }
	}
    }

    uplevel ::freewrap::builtin_load \{$fpath\} $args

    return $fpath
}

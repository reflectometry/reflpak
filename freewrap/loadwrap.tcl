# This procedure replaces the normal LOAD command when
# using binary extensions with freeWrap.  If the target
# file is wrapped, it will unwrap then load it.  If it
# is not wrapped, then it will call load directly.
#
# Returns: On success, the full file path to the shared library 
#          on the local file system.
#          On failure, generates an error.
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
    uplevel [linsert $args 0 ::freewrap::builtin_load $fpath]

    return $fpath
}

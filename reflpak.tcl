#! /bin/sh
# \
exec wish "$0" "$@"

#console show
set file [info script]
while {![catch { set file [file link $file] }]} {}
set dir [file normalize [file dir $file]]
lappend auto_path [file normalize [file dir $file]]
package require [file tail [file rootname [info script]]]

#! /bin/sh
# \
exec ncnrkit "$0" "$@"

set file [info script]
while {![catch { set file [file link $file] }]} {}
set dir [file normalize [file dir $file]]
lappend auto_path [file normalize [file dir $file]]
package require [file tail [file rootname [info script]]]

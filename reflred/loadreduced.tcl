# Populate the file extensions reflred can produce.
# <type> possibly followed by [ABCD] possibly followed by [+-] if type is back
proc register_reduced {} {
return
    foreach ext { slit back spec refl div sub } {
	foreach idx { {} A B C D } { set ::extfn(.$ext$idx) reduced_info }
    }
    foreach idx { {} A B C D } {
	foreach side { + - } { set ::extfn(.back$idx$side) reduced_info }
    }
}
    
proc reduced_info { action {name {}} } {
    # ptrace
    switch $action {
	instrument { return Processed }
	dataset { return [file join [file dirname $name] Processed] }
	info {
	    set date [file mtime $name]
	    set comment [file tail [file rootname $name]]
	    catch {
		set fid [open $name]
		textkey [gets $fid] REFLRED version
		textkey [gets $fid] date date
		textkey [gets $fid] title comment
		close $fid
		set date [clock_scan $date]
	    }
	    return [list date $date comment $comment]
	}
	pattern {
	    return [file join [file dirname $name] "*.\{spec,back,slit,refl,div,sub\}{,a,A,b,B,c,C,d,D}{,+,-}"]
	}
	mark { markreduced $name }
    }
}

proc guessindex {file} {
    # Check the file extension to guess index
    set end [string index $file end]
    if { $end == "-" || $end == "+" } {
	set back $end
	set end [string index $file end-1]
    } else {
	set back ""
    }
    switch -- $end {
	a - A { set pol A }
	b - B { if {![string match "*sub$back" $file]} {set pol B} }
	c - C { if {![string match "*spec$back" $file]} {set pol C} }
	d - D { if {![string match "*add$back" $file]} {set pol D} }
	default { set pol "" }
    }
    return $pol$back
}

proc markreduced {file} {
    if {[ catch { open $file r } fid ] } { return 0 }
    set data [read $fid]
    close $fid

    upvar #0 [new_rec $file] rec
    set rec(load) loadreduced
    set root [file rootname $file]
    set run [string range [file tail $root] 0 end]
    set dataset [string range [file tail $root] 0 end]

    # split the header from data
    regexp -indices -lineanchor "^\[^#]" $data idx
    set head [string range $data 0 [expr [lindex $idx 0] - 1]]
    set rec(data) [string range $data [lindex $idx 0] end]

    set rec(index) [guessindex $file]

    # process the header
    reducedheader rec $head
}

# reducedheader rec head
#
# Process header for reduced files
# rec is the name of the record
# head is the header data
proc reducedheader {r head} {
    upvar $r rec

    # process the header lines
    set rec(fixed) 0
    set rec(L) 4.75   ;# XXX FIXME XXX don't want to default L!!
    set rec(monitor) 1.0
    foreach line [split $head \n] {
	regexp {^#\s*(\w+)\s+(\w*)?\s*\n$} $line full label value
	switch -- $label {
	    xlabel { set rec(xlab) $value }
	    ylabel { set rec(ylab) $value }
	    title { set rec(comment) $value }
	    monitor { set rec(monitor) $value }
	    wavelength { set rec(L) $value }
	    field { set rec(H) $value }
	    temperature { set rec(T) $value }
	    columns { set rec(col) $value }
	    subtracted { set rec(subtracted) [string is true $value] }
	    instrument { set rec(instrument) $value }
	    date { catch { set rec(date) [clock_scan $value] } }
	    type { set rec(type) $value }
	    polarization { set rec(polarization) $value }
	    slits { 
		regexp {fixed\s+below\s+(\S+)\s*$} $value full rec(fixed)
	    }
	    from {
		if { [regexp {^\w+\s+(\S.*)$} $value full type files] } {
		    lappend rec(parts) [list $type $files]
		}
	    }
	}
    }
}


proc loadreduced {id} {
    upvar #0 $id rec
    
    set data $rec(data)

    # interpret the data
    if {![get_columns $id $rec(col) $data]} { return 0 }
    if {[llength $rec(col)] > 4} {
	if { [lsearch [string tolower $rec(col)] slit] > -1 } {
	    set rec(slits) [list slit1_$id slit2_$id]
	} else {
	    message "$rec(file): did not find slits in { $rec(col) }"
	}
    }

    # correct for monitor
    ::y_$id expr "::y_$id/$rec(monitor)"
    ::dy_$id expr "::dy_$id/$rec(monitor)"
    
    # We immediately convert preprocessed files into scans without
    # keeping them as records.  We display the ghost immediately
    # scaled to the current attenuators.  We do NOT save the scan
    # because we just loaded it so there is no reason to save it.
    addrun_addscan [setscan $id]
    atten_set {}

    # All that work and we pretend that loading fails because we don't
    # actually want the file selected.  Isn't that a hint that
    # loading scans via the compose screen is the wrong thing to do?
    # Maybe not, because we may want to compare complete scans to new
    # partial scans.
    return 0
}


# textkey text label name
#
# Set name to the value associated with label in text. 
#
# Label can be a pattern such as temp\w*.  The match is case insensitive 
# unless the label starts with (?c). If you want to be less accepting,
# you can use non-capturing grouping followed by ? to optionally match the
# suffix.  For example, the label {T(?:emp(?:erature)?)?} matches "t", 
# "temp" and "temperature", but not "time". Alternate labels can be 
# specified with non-grabbing branch patterns such as (?:H|field).
#
# The format is line oriented, with any sort of comment characters allowed
# at the start of the line, followed by label, possibly followed by : or =
# followed by a value which may or may not be in quotes.
# The following are all examples of valid label-value pairs:
#    Title This is the title
#    !date 2002-12-10
#    % DATE     Dec 10, 2002
#    # wavelength: 1.75
#    # temperature=15
#    field "17"
#
# XXX FIXME XXX how can we support units?  Perhaps we don't.  We can process
# the returned string just like we do for date.
proc textkey { text label name } {
    set pattern {(?:\s*[:=]\s*|\s+)"?(.*?)"?\s*$}
    upvar $name value
    return [regexp -line -nocase "^\\W*$label$pattern" $text {} value]
}

proc markother {file} {
    # trap exceptions before we start
    if { [catch { file mtime $file } date] } { return }

    # create a new record
    upvar #0 [new_rec $file] rec
    
    set rec(load) loadother
    
    set rec(date) [file mtime $file]
    set rec(comment) "Unknown file $file"
    set rec(T) unknown
    set rec(H) unknown
    set rec(base) unknown
    set rec(index) [guessindex $file]
    set rec(start) 0
    set rec(stop) 0

    set trim [string range [file tail $file] 0 end-[string length $rec(index)]]
    set root [file rootname $trim]
    set dataset [string range $root 0 end-3]
    if { [info exists ::dataset($dataset)] } {
	set rec(type) processed
	set rec(dataset) $dataset
	set rec(run) "[string range $root end-2 end][file extension $trim]"
	set rec(instrument) [lindex [split [lindex [lsort [array names ::group $dataset,*]] 0] ,] 1]
    } else {
	set rec(type) none
	set rec(dataset) unknown
	set rec(run) $trim
	set rec(instrument) none
    }
    categorize
}

proc loadother {id} {
    upvar #0 $id rec

    # suck in the data file
    if {[ catch { open $rec(file) r } fid ] } { return 0 }
    set data [read $fid]
    close $fid

    # Interpret header.
    # XXX FIXME XXX it may be faster to grab each header line and
    # test it against a big switch statement.  Alternatively, just
    # use the header lines when looking for fields.
    set head $data

    set rec(L) 4.75   ;# XXX FIXME XXX don't want to default L!!
    # message "Wavelength for $rec(file) defaults to $rec(L)"
    set rec(monitor) 1.0
    textkey $head xlab(?:el)? rec(xlab)
    textkey $head ylab(?:el)? rec(ylab)
    textkey $head mon(?:itor)? rec(monitor)
    textkey $head (?:wavelength|L) rec(L)
    textkey $head (?:title|comment) rec(comment)
    textkey $head (?:field|H) rec(H)
    textkey $head t(?:emp(?:erature)?)? rec(T)
    textkey $head col(?:umn)?s? rec(col)
    textkey $head "slits fixed until" rec(fixed)
    textkey $head polarization rec(polarization)
    textkey $head subtracted rec(subtracted)
    textkey $head linear linear
    if [textkey $head date date] {
	catch { set rec(date) [clock_scan $date] }
    }

    # guess instrument and experiment type
    # New files have these fields:
    #   # inst[rument] <inst>
    #   # type <type>
    #   # from <type> <files>
    #   # from <type> <files>
    #   # ...
    # Some old files may have:
    #   # source <inst> <type>
    #   # source <inst>
    #   # spec <files>
    #   # back <files>
    #   # slit <files>
    # XXX FIXME XXX we should take the guesswork out of this
    unset rec(type)
    if { [textkey $head source source] } {
	set rec(instrument) [lindex $source 0]
	set sourcelab [lrange $source 1 end]

	# lookup label in type label table
	foreach {type label} [array get ::typelabel] {
	    if [string equal $sourcelab $label] {
		set rec(type) $type
		break;
	    }
	}
    }
    if { ![info exists rec(instrument)] } {
	textkey $head inst(?:rument)? rec(instrument)
    }
    if { ![info exists rec(type)] } {
	if ![textkey $head type rec(type)] {
	    # XXX FIXME XXX it's bogus trying to guess when I can just
	    # print out the type and forget about it
	    set havespec [textkey $head spec junk]
	    set haveback [textkey $head back junk]
	    set haveslit [textkey $head slit junk]
	    set havefoot [textkey $head foot\w* junk]
	    if { $havespec && $havefoot } {
		message "corrected reflectivity curve"
		set rec(type) spec
	    } elseif { $havespec && $haveback && $haveslit } {
		message "uncorrected reflectivity curve"
		set rec(type) spec
		set rec(monitor) 1.0
	    } elseif { $havespec && $haveslit } {
		message "uncorrected specular"
		set rec(type) spec
		set rec(monitor) 1.0
	    } elseif { $havespec && $haveback } {
		message "background subtracted"
		set rec(type) spec
	    } elseif { $havespec } {
		message "specular"
		set rec(type) spec
	    } elseif { $haveback && $haveslit } {
		message "background / slitscan"
		set rec(type) back
		set rec(monitor) 1.0
	    } elseif { $haveback } {
		message "background"
		set rec(type) back
	    } elseif { $haveslit } {
		message "slit scan"
		set rec(type) slit
	    } else {
		message "unknown curve type"
		set rec(type) other
	    }
	}
    }
    

    # Strip all comments and blank lines
    # Comments start with # / ! or % and go to the end of the line so
    # no block comments allowed.  This will prepend a \n.
    regsub -all -line {(?:[[:blank:]]*(?:[#/!%].*$)?\n)+[[:blank:]]*} \n$data\n \n data

    if {[info exists rec(col)]} {
	if {![get_columns $id $rec(col) $data]} { return 0 }
	if {[llength $rec(col)] > 3} {
	    if { [lsearch [string tolower $rec(col)] slit] > -1 } {
		set rec(slit) slit_$id
	    } else {
		message "$rec(file): did not find slit in { $rec(col) }"
	    }
	}
    } else {
	# Check that whether we have QR or QRdR data
	set D {[-+0-9dDeE.]+}
	set S {\s+}
	set T {\s*\n}

	if {[regexp "^\n(?:$D$S$D$T)+$" $data]} {
	    set rec(col) [list x y]
	    if {![get_columns $id $rec(col) $data]} { return 0 }
	    vector create ::dy_$id
	    ::dy_$id expr "sqrt(::y_$id)"
	} elseif { [regexp "^\n(?:$D$S$D$S$D$T)+$" $data]} {
	    set rec(col) [list x y dy]
	    if {![get_columns $id $rec(col) $data]} { return 0 }
	} elseif { [regexp "^\n(?:$D$S$D$S$D$S$D$T)+$" $data]} {
	    set rec(col) [list x y dy s]
	    if {![get_columns $id $rec(col) $data]} { return 0 }
	    set rec(slit) s_$id
	} else {
	    message "$rec(file) is not a Q,R, a Q,R,dR or a Q,R,dR,S data file"
	    return 0
	}
    }

    # If data is log, exponentiate.  It is log if the ylabel says it is
    # log or if the data is mostly negative.  The second criterion will
    # certainly fail for slit scans.  If users don't like this, then they
    # will have to convert it back to log themselves by calling runlog id
    # from the tcl console, followed by atten_set.
    if { [info exists linear] } {
	if { ![string is true $linear] } {
	    runexp $id
	}
    } elseif { [string match {[Ll]og *} $rec(ylab)] } {
	set rec(ylab) [string range $rec(ylab) 4 end]
	runexp $id
    } elseif { [vector expr "sum(::y_$id > 0) < length(::y_$id)/3"] } {
	runexp $id
    }

    # correct for monitor
    ::y_$id expr "::y_$id/$rec(monitor)"
    ::dy_$id expr "::dy_$id/$rec(monitor)"
    
    # We immediately convert preprocessed files into scans without
    # keeping them as records.  We display the ghost immediately
    # scaled to the current attenuators.  We do NOT save the scan
    # because we just loaded it so there is no reason to save it.
    addrun_addscan [setscan $id]
    atten_set {}

    # All that work and we pretend that loading fails because we don't
    # actually want the file selected.  Isn't that a hint that
    # loading scans via the compose screen is the wrong thing to do?
    # Maybe not, because we may want to compare complete scans to new
    # partial scans.
    return 0
}


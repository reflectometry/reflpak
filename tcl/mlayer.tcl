if { ($argc == 1 && [lindex $argv 0] eq "-h") || ($argc > 1) } {
    puts "usage: $argv0 \[fitfile|datafile]"
    exit
}

tk appname Reflfit

# XXX FIXME XXX ask before closing the application without saving

namespace import blt::bitmap blt::vector blt::graph

# Supporting widgets and helpers
source [file join $MLAYER_LIB pan.tcl]
source [file join $MLAYER_LIB tableentry.tcl]
source [file join $MLAYER_LIB htext.tcl]
source [file join $MLAYER_LIB balloonhelp.tcl]
source [file join $MLAYER_LIB ctext.tcl]

# generic is not really mlayer specific, but I haven't yet
# resolved the differences between it and the generic.tcl
# in viewrun.
source [file join $MLAYER_HOME generic.tcl]

# popup help for the individual fields
array set field_help {
    qcsq "Scattering length density.  Use Options menu to change between number density units and Qc^2 units."
    depth "Layer depth in angstroms"
    ro "Layer roughness in angstroms."
    mu "Absorption."
    mqcsq "Magnetic scattering length density."
    mdepth "Depth of magnetic layer"
    mro "Roughness for magnetic layer"
    theta "Theta relative to -k in the H-k plane"
    bi 	"Intensity of incoming beam.  If the reflectivity signal is properly normalized, then this will be 1.0.  If however there is a scaling factor such as an attenuator that is not accounted for by the data reduction process, then some other value should be used.  An initial guess can be further refined by fitting the variable BI."
    bk "Background signal.  This is the level of background noise expected in the signal.  Any data below this level will be ignored by the fit.  An initial guess can be further refined by fitting the variable BK."
    wl "Incident wavelength."
    dl "wavelength divergence"
    dt "angular divergence"
}

# By default, select and export tables as text with titles
# XXX FIXME XXX how can you put \n and \t into the resource file?
option add *SelectTitles true widgetDefault
option add *rowSeparator \n widgetDefault
option add *colSeparator \t widgetDefault
load_resources $::MLAYER_HOME tkmlayer

set sixteenpi [expr 64.0*atan(1)]
set ::use_sld [string is true [option get . useSLD UseSLD]]
set ::use_Q4 [string is true [option get . useQ4 UseQ4]]

# Print dialog
proc PrintDialog { args } {
    rename PrintDialog {}
    uplevel #0 [list source [file join $::MLAYER_LIB print.tcl]]
    eval PrintDialog $args
}



# how much debugging output to spit out
tracing 0

# whether to show interaction with mlayer
# exp_log_user 0


# This assumes BLT, Tktable, Expect and BWidget are already loaded, and
# that blt::* has been imported into the namespace.

# Determine if we are using polarized or unpolarized version
# based on the name of the executable.
set MAGNETIC [expr [string match "*gj2*" $argv0] || [string match "*pol*" $argv0] ]
set ::env(MLAYER_CONSTRAINTS) [file native [file join $::MLAYER_HOME makeconstrain]]
if {$::MAGNETIC} {
    set title Reflpol
} else {
    set title Reflfit
}


# which fields should we process in the layer table and on the profile
# graph (user can override in ~/.mlayer if they so desire)
if { $::MAGNETIC } {
    set active_slices { a b c d }
    set active_fields { qcsq mu mqcsq theta }
    set active_depths { depth mdepth }
} else {
    set active_slices { {} }
    set active_fields { qcsq mu }
    set active_depths { depth }
}

# layers program defaults
# XXX FIXME XXX the prompt which expect looks for must
# be embedded in the expect statements themselves
if { $::MAGNETIC } {
    set fitext .sta
    set allfiles  {{All Files} {*}}
    set fitfiles  {{Fit Files} {.sta}}
    set datafiles {{Data Files} {.reflA .reflB .reflC .reflD .refla .reflb .reflc .refld}}
    set fitglob   {*.sta}
    set dataglob  {*.refl[ABCDabcd]}
    set defaultfile "gmagblocks4.sta"
    set MAX_LAYERS 1000
} else {
    set fitext .staj
    set allfiles  {{All Files} {*}}
    set fitfiles  {{Fit Files} {.staj}}
    set datafiles {{Data Files} {.refl}}
    set fitglob "*.staj"
    set dataglob "*.refl"
    set defaultfile "mlayer.staj"
    set MAX_LAYERS 28
}


# Let the user customize their version without changing the original
# by loading resources from a file in their directory.
# XXX FIXME XXX put this as late as possible in the source so that
# the user can override more of the program.
# XXX FIXME XXX also check version of ipc corresponds to current mlayer.tcl
set VERSION 0.0.1
source [file join $MLAYER_HOME defaults.tcl]
if { [ file exists [file join [HOME] .mlayer] ] } {
    source [file join $MLAYER_HOME defaults.tcl]
}



# ==================== main frames =================================

# These are the main windows which are used throughout.
# XXX FIXME XXX only create the contents of the window when the user
# clicks on the notebook tab so that startup is faster
set panes [ PanedWindow .panes -side right -weights available ]
set reflectivitybox [ $panes add -weight 45 ]
set notebookbox [ $panes add -weight 55 ]
sashconf .panes

set notebook [ NoteBook $notebookbox.notebook -internalborderwidth 3]
#set notebook [ tabset $notebookbox.notebook ]
set layerbox [ $notebook insert end LayerProfile -text "Profile" \
	-raisecmd { focus $::layerbox } ]
set tablebox [ $notebook insert end LayerTable -text "Layers" \
	-raisecmd { focus $::tablebox } ]
set beambox [ $notebook insert end Beam -text "Beam" \
	-raisecmd { focus $::beambox } ]
set fitbox [ $notebook insert end Fit -text "Fit" \
	-raisecmd { focus $::fitbox } ]
set constraintbox [ $notebook insert end Constraints -text "Constraints" \
	-raisecmd { focus $::constraintbox } ]
set commandbox [ $notebook insert end Command -text "Command" \
	-raisecmd { focus $::commandbox } ]

# ==================== Layer data access =======================

# ::pars is used to communicate parameters between mlayer.tcl and mlayer.
# Its layout is encoded in src/ipc.c and decoded in set_vars_from_pars.
# ::layer_offset is the offset of the parameters for the first layer.
# The arrangement of the layers is decoded in layer.
vector create ::pars
if {$::MAGNETIC} {
    set ::num_fields 8
} else {
    set ::num_fields 4
}

# Usage: set_vars_from_pars
# decode the various parameters from ::pars into the associated globals
proc set_vars_from_pars {} {
    # XXX FIXME XXX can we leave the parameters in the par vector
    # and access them directly from there (e.g., via [layer])?  Can
    # we attach a vector element as a textvariable to an input field?
    set ::layer_offset -1

    # layers/sections
    set ::num_layers [makeint $::pars([incr ::layer_offset])]
    if {!$::MAGNETIC} {
	set ::ntl        [makeint $::pars([incr ::layer_offset])]
	set ::nml        [makeint $::pars([incr ::layer_offset])]
	set ::nbl        [makeint $::pars([incr ::layer_offset])]
	set ::nrepeat    [makeint $::pars([incr ::layer_offset])]
    }

    # beam characteristics
    set ::bi         $::pars([incr ::layer_offset])
    set ::bk         $::pars([incr ::layer_offset])
    set ::dt         $::pars([incr ::layer_offset])
    set ::dl         $::pars([incr ::layer_offset])
    set ::wl         $::pars([incr ::layer_offset])

    # roughness profile
    set ::roughwidth $::pars([incr ::layer_offset])
    set ::nrough     $::pars([incr ::layer_offset])

    incr ::layer_offset

    # correct for sld units
    if { $::use_sld } {
	set n [::pars length]
	for {set i $::layer_offset} { $i < $n } { incr i $::num_fields } {
	    set ::pars($i) [ expr { $::pars($i) / $::sixteenpi } ]
	}
	if { $::MAGNETIC } {
	    for {set i [expr {$::layer_offset+4}]} { $i < $n } { incr i $::num_fields } {
		set ::pars($i) [ expr { $::pars($i) / $::sixteenpi } ]
	    }
	}
    }

    layer_renumber
}

proc set_pars_from_vars { pars_name } {
    ::pars dup $pars_name
    upvar #0 $pars_name pars
    # XXX FIXME XXX can we leave the parameters in the par vector
    # and access them directly from there (e.g., via [layer])?  Can
    # we attach a vector element as a textvariable to an input field?
    set ::layer_offset -1

    # layers/sections
    set pars([incr ::layer_offset]) $::num_layers
    if {!$::MAGNETIC} {
        set pars([incr ::layer_offset]) $::ntl
        set pars([incr ::layer_offset]) $::nml
        set pars([incr ::layer_offset]) $::nbl
        set pars([incr ::layer_offset]) $::nrepeat
    }

    # beam characteristics
    set pars([incr ::layer_offset]) $::bi
    set pars([incr ::layer_offset]) $::bk
    set pars([incr ::layer_offset]) $::dt
    set pars([incr ::layer_offset]) $::dl
    set pars([incr ::layer_offset]) $::wl

    # roughness profile
    set pars([incr ::layer_offset]) $::roughwidth
    set pars([incr ::layer_offset]) $::nrough

    incr ::layer_offset

    # correct for sld units
    if { $::use_sld } {
	set n [::pars length]
	for {set i $::layer_offset} { $i < $n } { incr i $::num_fields } {
	    set pars($i) [ expr { $::pars($i) * $::sixteenpi } ]
	}
	if { $::MAGNETIC } {
	    for {set i [expr {$::layer_offset+4}]} { $i < $n } { incr i $::num_fields } {
		set pars($i) [ expr { $::pars($i) * $::sixteenpi } ]
	    }
	}
    }
}

set pars_stack 0
proc push_pars {} {
    set_pars_from_vars ::pars[incr ::pars_stack]
}

proc pop_pars {} {
    if { $::pars_stack > 0 } {
        ::pars$::pars_stack dup ::pars
        incr ::pars_stack -1
        set_vars_from_pars
    }
}

# Set the parameters to valid defaults if none are known.
proc default_pars {} {
    # Layout is as follows
    # ::pars set { nlayers \
    #       sections  (non-magnetic only) \
    #	    beam characteristics \
    # 	    roughness profile \
    #	    layer1 \
    #	    layer2 \
    #	    ...   \
    #       layern }

    if {$::MAGNETIC} {
	::pars set { 2.0 \
		1.0 1.0e-10 0.00001 0.05 4.75  \
		0.0 7.0 \
		0.0 0.0 0.0 0.0 0.0  0.0  0.0  0.0 \
		1.0e-5 1.0e-9 1.0 30.0 1.0e-5 0.0  1.0 30.0 }
    } else {
	::pars set { 4.0 \
		1.0 1.0 1.0 1.0 \
		1.0 1.0e-10 0.00001 0.05 4.75 \
		0.0 7.0 \
		0.0 0.0 0.0  0.0 \
                1.0e-5 1.0e-9 1.0 10.0 \
		1.0e-5 1.0e-9 1.0 10.0 \
                1.0e-5 1.0e-9 1.0 30.0 }
    }
    set_vars_from_pars
}


# Parse the string as section field number and translate it into
# a field-number pair suitable for [ layer $number $field ].  field
# and number are passed as variable names.  The vacuum section is
# returned as layer 0 of section T.
#
# Return 1 if success, 0 if not the correct form or if correct
# form but not in range.
array set parse_par_extra {
    BK background BI beamintensity MUV mu VMU mu QCV qcsq VQC qcsq
}
array set parse_par_field { QC qcsq MU mu RO ro D depth }
if { $::MAGNETIC } {
    array set parse_par_extra { VQM mqcsq VMQ mqcsq }
    array set parse_par_field { QM mqcsq TH theta RM mro DM mdepth }
}
proc parse_par { string field number } {
    upvar $field ret_f
    upvar $number ret_n

    set string [ string toupper $string ]

    # Check for non-layered parameters (background, beam intensity, etc).
    # Conveniently, with the appropriate mapping in parse_par_extra, the
    # vacuum layer parameters are handled without special code.
    if { ![ catch { set ret_f $::parse_par_extra($string) } ] } {
	set ret_n 0
	return 1
    }

    # Parse <section><field><number>
    if { $::MAGNETIC } {
	# the magnetic version doesn't use sections, so pretend that
	# each layer is prepended with section L
	set section "L"
	if { [ string match "\[1-9]" [ string index $string 1 ] ] } {
	    set f [ string index $string 0 ]
	    set n [ string range $string 1 end ]
	} else {
	    set f [ string range $string 0 1 ]
	    set n [ string range $string 2 end ]
	}
	if { ![ string is integer $n ] } { return 0 }
	if { $n < 1 } { return 0 }
    } else {
	set section [ string index $string 0 ]
	if { $section != "T" && $section != "M" && $section != "B" } {
	    return 0
	}
	set f [ string range $string 1 end-1 ]
	set n [ string index $string end ]
	if { ![ string match "\[1-9]" $n ] } { return 0 }
    }

    # make sure the field is valid and the layer exists
    if { [ catch { set ::parse_par_field($f) } ] } { return 0 }
    if { ![ layer_in_section $section $n ] } { return 0 }

    # correct layer number for section offset
    if { $section == "M" || $section == "B" } { incr n $::ntl }
    if { $section == "B" } { incr n $::nml }

    # section is valid, so overwrite the caller variables $field and $number
    set ret_f $::parse_par_field($f)
    set ret_n $n
    return 1

}

# Usage: layer # parameter [value]
# get/set field value for particular layer
# Also supports some non-layer parameters (background and beamintensity)
# so that special code is not required elsewhere.
# Does not update profile graph, profile table or mlayer program
proc layer { number field {value {}} } {
    # make sure the layer exists
    if { $number >= $::num_layers || $number < 0 } {
	error "require layer 0 <= $number < $::num_layers"
    }
    set update [expr ! [ string match $value {} ]]

    # Interpret field name.  For actual layer parameters, comput the offset
    # from the start of the layer in the ::pars array.
    switch -- $field {
	background {
	    if { $update } { set ::bk $value }
	    return $::bk
	}
	beamintensity {
	    if { $update } { set ::bi $value }
	    return $::bi
	}
	qcsq   { set idx 0 }
	mu     { set idx 1 }
	ro     { set idx 2 }
	depth  { set idx 3 }
	offset {
	    if { $update } { set ::offsets($number) $value }
	    return $::offsets($number)
	}
	mqcsq   { set idx 4 }
	theta  { set idx 5 }
	mro    { set idx 6 }
	mdepth { set idx 7 }
	moffset {
	    if { $update } { set ::moffsets($number) $value }
	    return $::moffsets($number)
	}
	name {
	    if { $update } { set ::layer_names($number) $value }
	    return $::layer_names($number)
	}
	default {
	    error "invalid field $field"
	}
    }

    # Add layer offset to the ::pars index
    incr idx [ expr $::layer_offset + $::num_fields*$number ]

    # If given a new value then update the ::pars array, making sure
    # that roughness does not exceed layer depth for the surrounding
    # layers.  If you are modifying depth, it will reduce the surrounding
    # roughnesses if they are too large.  If you are modifying roughness,
    # it will be limited to the surrounding depths.
    if { $update } {
	# force depth/roughness >= 1
	switch $field {
	    depth - ro - mdepth - mro { if { $value < 1 } { set value 1 } }
	}

	# the code to handle nuclear and magnetic depths is identical
	# except that the corresponding roughness and depth have different
	# field names.  Find the conjugate name for the field being updated.
	switch $field {
	    depth { set conj ro }
	    ro { set conj depth }
	    mdepth { set conj mro }
	    mro { set conj mdepth }
	}
	# Replace 0 with $field to apply the constraint
	switch 0 {
	    depth {
# Grrr... can't comment out switches
# Magnetic roughness is not subject to the depth constraint in this version.
# Uncomment the "mdepth -" line and put it in front of "depth" tag and
# uncomment the "mro -" line and put it in front of "ro" tag to make the
# constraint apply.
#	    mdepth -
#	    mro -
		set ro [ layer $number $conj ]
		## XXX FIXME XXX clean up ugly code which results because
		## the substrate has ill-defined depth; that is, all the
		## tests against $::num_layers-1
		if { $number == $::num_layers-1 } {
		    if { [layer $number $conj] > $value } {
			layer $number $field $ro
		    }
		} else {
		    if { [layer $number $conj] > $value } {
			layer $number $conj $value
		    }
		    set next [expr $number + 1]
		    if { [layer $next $conj] > $value } {
			layer $next $conj $value
		    }
		}
	    }
	    ro {
		if { $number == $::num_layers-1 } {
		    set depth [layer [expr $number - 1] $conj]
		    if { $depth < $value } { set value $depth }
		    # layer $number $conj [expr $::roughwidth*$value]
		} elseif { $number > 1 } {
		    set depth [layer $number $conj]
		    if { $depth < $value } { set value $depth }
		    set depth [layer [expr $number - 1] $conj]
		    if { $depth < $value } { set value $depth }
		} elseif { $number == 1 } {
		    set depth [layer $number $conj]
		    if { $depth < $value } { set value $depth }
		    # layer 0 $conj [expr $::roughwidth*$value]
		} else {
		    error "cannot set roughness for vacuum"
		}
	    }
	}

	## update the table with the new value
	set ::pars($idx) $value
    }


    # Like the set command, if you are not updating the value, the
    # old value will be returned, otherwise the new value will be
    # returned.
    return $::pars($idx)
}

# Usage: layer_renumber
# generate layer names for each layer in pars.  These names are returned
# by calling [ layer $number name ]
proc layer_renumber { } {
    layer 0 name "V"
    if { $::MAGNETIC } {
	for {set i 1} { $i < $::num_layers } { incr i } {
	    layer $i name "$i"
	}
    } else {
	# the nonmagnetic version has a repeated middle section that
	# must be labelled appropriately.
	for {set i 1} { $i < $::num_layers } { incr i } {
	    if { $i <= $::ntl } {
		layer $i name "T$i"
	    } elseif { $i <= $::ntl + $::nml } {
		layer $i name "M[expr $i - $::ntl]"
	    } else {
		layer $i name "B[expr $i - $::ntl - $::nml]"
	    }
	}
    }
}

# helper function for layer operations.  Returns true if the layer
# number exists in its section.  If the section is L then it returns
# true if that layer exists.
proc layer_in_section { s n } {
    switch $s {
	T { return [ expr $n <= $::ntl ] }
	M { return [ expr $n <= $::nml ] }
	B { return [ expr $n <= $::nbl ] }
	L { return [ expr $n <= $::num_layers ] }
    }
}

# Usage: layer_index name section_var number_var offset_var type
#
# Helper function for layer operations.  Decodes a layer name into
# section and number, and returns the offset of the layer into ::pars
# Reports an error if the section is invalid form, or is not valid as
# a source or destination.
#
# Sets variable named $section to the section code and the variable
# named $number to the number within the section.
#
# Sets variable named $offset to the index in ::pars of the start of
# the section.
#
# Returns 1 on success, 0 on failure
proc layer_index { id section number offset type } {
    upvar $section s
    upvar $number n
    upvar $offset idx
    if { $::MAGNETIC } {
	set s "L"
	set n $id
	if { ![ string is integer $id ] } {
	    tk_messageBox -message "Layer <$id> is not a number" -type ok
	    return 0
	}
    } else {
	set s [ string toupper [ string index $id 0]]
	set n [ string range $id 1 end ]
	if { ![ string match "\[tTmMbB]\[123456789]" $id ] } {
	    tk_messageBox -message "Layer <$id> is not T#, M# or B#" -type ok
	    return 0
	}
    }
    set limit $n
    if { $type == "destination" } { incr limit -1 }
    if { ![layer_in_section $s $limit] } {
	tk_messageBox -message "Layer <$id> is not present" -type ok
	return 0
    }
    switch $s {
	L -
	T { set layer_num $n }
	M { set layer_num [ expr $n + $::ntl ] }
	B { set layer_num [ expr $n + $::ntl + $::nml ] }
    }
    set idx [ expr $::layer_offset + $layer_num*$::num_fields ]
    return 1
}

# Usage: section_decr s
# Decrement the number of layers in section $s or report an error if
# that would make the section empty. Return 1 on success, 0 on failure
proc section_decr { s } {
    if { $::MAGNETIC } {
	if { $::num_layers <= 2 } {
	    tk_messageBox -message "Need at least one layer" -type ok
	    return 0
	}
    } else {
	switch $s {
	    T { set pars_idx 1; set var ::ntl }
	    M { set pars_idx 2; set var ::nml }
	    B { set pars_idx 3; set var ::nbl }
	}
	if { [set $var] <= 1 } {
	    tk_messageBox -message "Section $s would be empty" -type ok
	    return 0
	}
	set ::pars($pars_idx) [ incr $var -1 ]
    }
    set ::pars(0) [ incr ::num_layers -1 ]
    layer_renumber
    return 1
}


# Usage: section_incr s
# Increment the number of layers in section $s or report an error if
# that would make the section full. Return 1 on success, 0 on failure
proc section_incr { s } {
    if { $::MAGNETIC } {
	if { $::num_layers >= $::MAX_LAYERS } {
	    tk_messageBox -message "Too many layers" -type ok
	}
    } else {
	switch $s {
	    T { set pars_idx 1; set var ::ntl }
	    M { set pars_idx 2; set var ::nml }
	    B { set pars_idx 3; set var ::nbl }
	}
	if { [set $var] >= 9 } {
	    tk_messageBox -message "Section $s is full" -type ok
	    return 0
	}
	set ::pars($pars_idx) [ incr $var ]
    }
    set ::pars(0) [incr ::num_layers]
    layer_renumber
    return 1
}

# copy the contents of layer $id to layer $dest, overwriting what
# was there before
proc layer_overwrite { id dest } {
    if { ![ layer_index $id s n sidx source ] } { return 0 }
    if { ![ layer_index $dest t m tidx destination ] } { return 0 }
    if { ![ layer_in_section $t $m ] } { return [ layer_copy $id $dest ] }
    for { set i 0 } { $i < $::num_fields } { incr i } {
	set ::pars([expr $tidx+$i]) $::pars([expr $sidx+$i])
    }
    return 1
}

# Usage: layer_move source dest
# Remove the layer at $source and insert it before $dest.  To append
# it to a section, use the next layer number in the section.
proc layer_move { id dest } {
    if { ![ layer_index $id s n sidx source ] } { return 0 }
    if { ![ layer_index $dest t m tidx destination ] } { return 0 }

    # ick! if moving within a section the rules are different.  To get
    # least surprise the contents of the layer $id before the move
    # should become the contents of layer $dest after the move.  If we
    # are moving a layer up within a section (e.g., from T3 to T1) then
    # we do the usual move, sliding the old T2 down to T3 and the old
    # T1 down to T2.  If on the other hand we are moving a layer down
    # (e.g., from T1 to T3), then we have to move T1 AFTER T3, sliding
    # the old T2 down to T1 and the old T3 down to T2.  A corollary is
    # that we cannot move to a destination after the end of the current
    # section since there is no way to make the section longer by
    # moving the layers within it.
    if { $s == $t } {
	if { [ layer_in_section $t $m] } {
	    if { $tidx > $sidx } { incr tidx $::num_fields }
	} else {
	    tk_messageBox -type ok \
		    -message "Cannot move $id beyond the end of the section"
	    return 0;
	}
    }

    # if moving between sections, then we need to adjust the sizes
    # of the two sections
    if { $s != $t } {
	if { ![ section_decr $s ] } { return 0 }
	if { ![ section_incr $t ] } {
	    # ick! since incr/decr are state changing, must undo the
	    # decr for s if the incr t fails
	    section_incr $s
	    return 0
	}
    }

    set block $::pars($sidx:[expr $sidx+$::num_fields-1])
    if { $sidx+$::num_fields < $tidx } {
	set head "$::pars(:[expr $sidx-1])"
	if { $tidx < [ ::pars length ] } {
	    set tail "$::pars([expr $tidx]:)"
	} else {
	    set tail {}
	}
	set shift "$::pars([expr $sidx+$::num_fields]:[expr $tidx-1])"
	::pars set "$head $shift $block $tail"
    } elseif { $tidx+$::num_fields <= $sidx } {
	set head "$::pars(:[expr $tidx-1])"
	if { $sidx < [ ::pars length ] } {
	    set tail "$::pars([expr $sidx]:)"
	} else {
	    set tail {}
	}
	set shift "$::pars([expr $tidx]:[expr $sidx-1])"
	::pars set "$head $block $shift $tail"
    }
    return 1
}

# Usage: layer_copy source dest
# Insert a copy of the layer at $source before $dest.
proc layer_copy { id dest } {
    if { ![ layer_index $id s n sidx source ] } { return 0 }
    if { ![ layer_index $dest t m tidx destination ] } { return 0 }
    if { ![ section_incr $t ] } { return 0 }

    set block $::pars($sidx:[expr $sidx+$::num_fields-1])
    if { $tidx >= [ ::pars length ] } {
	::pars append $block
    } else {
	::pars set "$::pars(:[expr $tidx-1]) $block $::pars($tidx:)"
    }
    return 1
}

# Usage: layer_delete source
# Remove the given layer and renumber all the layers
proc layer_delete { id } {
    if { ![ layer_index $id s n idx source ] } { return 0 }
    if { ![ section_decr $s ] } { return 0 }

    set tail [expr $idx + $::num_fields]
    set head [expr $idx - 1]
    if { $tail >= [ ::pars length ] } {
	# deleting the last layer so chop
	::pars set "$::pars(:$head)"
    } else {
	# deleting in the middle so rebuild the vector without the layer
	::pars set "$::pars(:$head) $::pars($tail:)"
    }
    return 1
}

# Usage: layer_check depth mu qcsq ro
# Helper function for layer_insert.  Verify that the parameters for
# the new layer make sense.
proc layer_check { depth mu qcsq ro } {
    if { ![ string is double $depth ] } {
	tk_messageBox -message "Depth <$depth> is not a number" -type ok
    } elseif { ![ string is double $mu ] } {
	tk_messageBox -message "Mu <$mu> is not a number"
    } elseif { ![ string is double $qcsq ] } {
	tk_messageBox -message "Qcsq <$qcsq> is not a number"
    } elseif { ![ string is double $ro ] } {
	tk_messageBox -message "Roughness <$ro> is not a number"
    } elseif { $depth < 1 } {
	tk_messageBox -message "Depth $depth must be more than 1" -type ok
    } elseif { $ro < 1 || $ro > $depth } {
	tk_messageBox -message "Roughness must be between 1 and depth" -type ok
    } elseif { $qcsq < 0 } {
	tk_messageBox -message "Qc^2 must be greater than 0" -type ok
    } else {
	return 1
    }
    return 0
}

# Usage: layer_magnetic mdepth theta mqcsq mro
# Helper function for layer_insert.  Verify that the parameters for
# the new magnetic layer make sense.
proc layer_magnetic { mdepth theta mqcsq mro } {
    if { ![ string is double $mdepth ] } {
	tk_messageBox -message "Magnetic depth <$mdepth> is not a number" -type ok
    } elseif { ![ string is double $theta ] } {
	tk_messageBox -message "Theta <$theta> is not a number"
    } elseif { ![ string is double $mqcsq ] } {
	tk_messageBox -message "Magnetic Qc^2 <$mqcsq> is not a number"
    } elseif { ![ string is double $mro ] } {
	tk_messageBox -message "Magnetic roughness <$mro> is not a number"
    } elseif { $mdepth < 1 } {
	tk_messageBox -message "Magnetic depth $mdepth must be more than 1" -type ok
    } elseif { $mro < 1 || $mro > $mdepth } {
	tk_messageBox -message "Magnetic roughness must be between 1 and magnetic depth" -type ok
    } elseif { $mqcsq < 0 } {
	tk_messageBox -message "Qm^2 must be greater than 0" -type ok
    } elseif { $theta <= -360 || $theta >= 360 } {
	tk_messageBox -message "Theta must be in [-360,360]" -type ok
    } else {
	return 1
    }
    return 0
}

# Usage: layer_lattice start end copies
# Repeat a number of layers many times
proc layer_lattice { start end copies } {
    if { ![ layer_index $start s n sidx source ] } { return 0 }
    if { ![ layer_index $end st m tidx source ] } { return 0 }
    if { $sidx >= $tidx } {
	tk_messageBox -message "Must have start < end" -type ok
	return 0
    }
    if { $::num_layers + ($end - $start)*$copies >= $::MAX_LAYERS } {
	tk_messageBox -message "Too many layers" -type ok
	return 0
    }
    incr $tidx $::num_fields
    vector create copy
    vector create tail
    copy set $::pars($sidx:[expr $tidx - 1])
    tail set $::pars($tidx:)
    ::pars set $::pars(:[expr $sidx - 1])
    for { set i 0 } { $i < copies } { incr i } { ::pars append copy }
    ::pars append tail
    copy delete
    tail delete
}


# Usage: layer_insert dest qcsq mu ro depth
# Insert a layer with the given parameters after $dest.
if { $::MAGNETIC } {
    proc layer_insert { id qcsq mu ro depth mqcsq theta mro mdepth } {
	if { ![ layer_check $depth $mu $qcsq $ro ] } { return 0 }
	if { ![ layer_magnetic $mdepth $theta $mqcsq $mro ] } { return 0 }
	if { ![ layer_index $id s n idx destination ] } { return 0 }
	if { ![ section_incr $s ] } { return 0 }

	if { $idx >= [ ::pars length ] } {
	    # inserting after the last layer so append
	    ::pars append $qcsq $mu $ro $depth $mqcsq $theta $mro $mdepth
	} else {
	    # inserting in the middle so rebuild the vector with the new layer
	    ::pars set "$::pars(:[expr $idx-1]) $qcsq $mu $ro $depth $mqcsq $theta $mro $mdepth $::pars($idx:)"
	}
	return 1
    }
} else {
    proc layer_insert { id qcsq mu ro depth } {
	if { ![ layer_check $depth $mu $qcsq $ro ] } { return 0 }
	if { ![ layer_index $id s n idx destination ] } { return 0 }
	if { ![ section_incr $s ] } { return 0 }

	if { $idx >= [ ::pars length ] } {
	    # inserting after the last layer so append
	    ::pars append $qcsq $mu $ro $depth
	} else {
	    # inserting in the middle so rebuild the vector with the new layer
	    ::pars set "$::pars(:[expr $idx-1]) $qcsq $mu $ro $depth $::pars($idx:)"
	}
	return 1
    }
}


# ==================== Interface to the mlayer program ==============

if { 0 } {
# XXX FIXME XXX make expect fail if already expecting.  Do this for
# all instances of expect in the program (of which there are too many).
# You will need something like the following, but be wary of the handling
# of expect out.  While we are at it, it would be nice if we could
# parameterize the patterns that expect is looking for.  A better
# approach, though, is to do away with expect entirely.
    set ::expecting 0
    proc syncexpect { args } {
	if { $::expecting } {
	error "Already expecting.  Wait and try again."
	}
	set ::expecting 1
	eval "expect $args"
	set ::expecting 0
    }
}


## Usage: send_layer number code position
## Helper function for send_layout.
## Sends details for a particular layer. E.g.,
##   send_layer 3 T 2
## sets Tro2 to [layer 3 ro], and so forth for ro, mu, qcsq and depth
proc send_layer {number code position} {
    # puts "sending layer $number as $code$position"
    gmlayer ${code}ro${position} [makereal [layer ${number} ro]]
    gmlayer ${code}mu${position} [makereal [layer ${number} mu]]
    gmlayer ${code}qc${position} [expr {$::sld_scale*[layer ${number} qcsq]}]
    gmlayer ${code}d${position}  [makereal [layer ${number} depth]]
    if { $::MAGNETIC } {
	gmlayer ${code}rm${position} [makereal [layer ${number} mro]]
	gmlayer ${code}th${position} [makereal [layer ${number} theta]]
	gmlayer ${code}qm${position} [expr {$::sld_scale*[layer ${number} mqcsq]}]
	gmlayer ${code}dm${position} [makereal [layer ${number} mdepth]]
    }
}

## Usage: send_fresnel
## Sets the model to a sharp substrate layer.
proc send_fresnel {} {
    if { $::use_sld } { set ::sld_scale $::sixteenpi } { set ::sld_scale 1.0 }
    if { $::MAGNETIC } {
	gmlayer vqm [makereal [expr {$::sld_scale*[layer 0 mqcsq]}]]
        gmlayer nl 1
    } else {
        gmlayer ntl 1
        gmlayer nml 1
        gmlayer nbl 1
        gmlayer nmr 1
    }
    gmlayer bi [makereal $::bi]
    gmlayer bk [makereal $::bk]
    gmlayer dt [makereal $::dt]
    gmlayer dl [makereal $::dl]
    gmlayer wl [makereal $::wl]
    gmlayer vqc [makereal [expr {$::sld_scale*[layer 0 qcsq]}]]
    gmlayer vmu [makereal [layer 0 mu]]
    gmlayer nr $::nrough
    gmlayer pr e

    set n [expr {$::num_layers-1}]
    if { $::MAGNETIC } {
        gmlayer ro1 0.
        gmlayer mu1 [makereal [layer $n mu]]
        gmlayer qc1 [expr {$::sld_scale*[layer $n qcsq]}]
        gmlayer d1 [makereal [layer $n depth]]
	gmlayer rm1 0.
	gmlayer th1 [makereal [layer $n theta]]
	gmlayer qm1 [expr {$::sld_scale*[layer $n mqcsq]}]
	gmlayer dm1 [makereal [layer $n mdepth]]
    } else {
        gmlayer td1  1.
        gmlayer tro1 1.
        gmlayer tmu1 [makereal [layer $n mu]]
        gmlayer tqc1 [expr {$::sld_scale*[layer $n qcsq]}]
        gmlayer md1  1.
        gmlayer mro1 1.
        gmlayer mmu1 [makereal [layer $n mu]]
        gmlayer mqc1 [expr {$::sld_scale*[layer $n qcsq]}]
        gmlayer bd1  1.
        gmlayer bro1 1.
        gmlayer bmu1 [makereal [layer $n mu]]
        gmlayer bqc1 [expr {$::sld_scale*[layer $n qcsq]}]
    }
}

## Usage: send_layout
## Send details for all layers to the gmlayer process.
proc send_layout {} {
    if { $::use_sld } { set ::sld_scale $::sixteenpi } { set ::sld_scale 1.0 }
    if { $::MAGNETIC } {
	gmlayer vqm [makereal [expr {$::sld_scale*[layer 0 mqcsq]}]]
	gmlayer nl [expr $::num_layers - 1] ;# num_layers includes vacuum layer
    } else {
	gmlayer ntl $::ntl
	gmlayer nml $::nml
	gmlayer nbl $::nbl
	gmlayer nmr $::nrepeat
    }
    gmlayer bi  [makereal $::bi]
    gmlayer bk  [makereal $::bk]
    gmlayer dt  [makereal $::dt]
    gmlayer dl  [makereal $::dl]
    gmlayer wl  [makereal $::wl]
    gmlayer vqc [makereal [expr {$::sld_scale*[layer 0 qcsq]}]]
    gmlayer vmu [makereal [layer 0 mu]]
    # XXX FIXME XXX do we really want to force erf() profile?
    gmlayer nr  $::nrough
    gmlayer pr  e

    if { $::MAGNETIC } {
	for { set i 1 } { $i < $::num_layers } { incr i } {
	    send_layer $i {} $i
	}
    } else {
	for { set i 1 } { $i < $::num_layers } { incr i } {
	    set code [ layer $i name ]
	    send_layer $i [string index $code 0] [string index $code 1]
	}
    }
}

## Close communication with gmlayer
proc close_gmlayer {} {
    # gmlayer quit
}

## Ask gmlayer for the current parameters
proc read_pars { } {
    # XXX FIXME XXX maybe use files in /tmp and remove them afterwards
    # similarly for the reset of the ipc files; better yet make gmlayer
    # a loadable command
    clean_temps
    ::pars set [gmlayer send pars]
    clean_temps
    set_vars_from_pars
}

## Ask gmlayer for the current data
proc read_data { } {
    clean_temps
    foreach v $::active_slices {
	foreach {q r dr } [gmlayer send data$v] break
	::data_q$v set $q
	::data_r$v set $r
	::data_e$v set $dr
        if { $::use_Q4 } {
            ::data_r$v expr ::data_r$v*data_q^4
            ::data_e$v expr ::data_e$v*data_q^4
        }
    }
    clean_temps
}

## Ask gmlayer for the current profile. You must use send_layout to
## update the parameters first.
proc read_profile {} {
    clean_temps
    foreach {d mu qcsq theta mqcsq} [gmlayer send prof step] break
    ::prof_depth set $d
    ::prof_mu set $mu
    ::prof_qcsq set $qcsq
    if { $::MAGNETIC } {
	::prof_theat set $theta
	::prof_mqcsq set $mqcsq
    }
    # convert to sld units
    if { $::use_sld } {
	::prof_qcsq expr "::prof_qcsq/$::sixteenpi"
	if { $::MAGNETIC } {
	    ::prof_mqcsq expr "::prof_mqcsq/$::sixteenpi"
	}
    }
    clean_temps
}

## Ask gmlayer for the current reflectivity signal.  You must use
## send_layout to update the parameters first.
proc read_reflectivity {} {
    if { $::MAGNETIC } {
	foreach {q ra rb rc rd} [gmlayer send refl] break
    } else {
	foreach {q r} [gmlayer send refl] break
	# puts "q:$q"
	# puts "r:$r"
    }

    ::reflect_q set $q
    foreach v $::active_slices {
	::reflect_r$v set [set r$v]
        if { $::use_Q4 } {
            ::reflect_r$v expr ::reflect_r$v*reflect_q^4
        }
    }
    set_chisq [gmlayer send chisq]
}

if 0 {
    after cancel { refine_reflectivity }
    set ::refinement 1
    after idle { refine_reflectivity }
    proc refine_reflectivity {} {
	set chisq [gmlayer send refl $::refinement]
	if { ![string equal {} $chisq] } {
	    set_chisq $chisq
	} else {
	    incr ::refinement
	    after idle { refine_reflectivity }
	}
	foreach {q ra rb rc rd} [gmlayer send refl] break
	::reflect_q set $q
	foreach v $::active_slices {
	    reflect_r$v set [set r$v]
	}
    }
}

## Ask gmlayer for the current working files.
proc working_files {} {
    set datafile [gmlayer send datafile]
    set parfile [gmlayer send parfile]

    if { $datafile ne "" } { set datafile " ([file tail [file normalize $datafile]])" }
    if { $parfile ne "" } { set parfile " [file tail [file normalize $parfile]]" }
    if { "$parfile$datafile" ne "" } {
	wm title . "$::title -$parfile$datafile"
    } else {
	wm title . "$::title"
    }
}

## Usage: update_gmlayer
##
## Signal that the layer configuration is changed and that
## a new profile and reflectivity signature should be read.
## Because recalculating the curves is a slow process, and
## because there are likely to be many requests in sequence
## as the controls are dragged around, the update is only
## processed when the request rate has slowed down.
proc update_gmlayer {} {
    if { $::profile_id != "" } { after cancel $::profile_id }
    set ::profile_id [ after $::profile_delay { do_profile } ]
    if { $::reflectivity_id != "" } { after cancel $::reflectivity_id }
    set ::reflectivity_id [ after $::reflectivity_delay { do_reflect } ]
}

set ::profile_id ""        ;# pending do_profile request
set ::reflectivity_id ""   ;# pending do_reflect request
set ::update_is_running 0  ;# true if do_profile or do_reflect are running

## helper function to send the layout and read the profile
proc do_profile { } {
    # if currently running an update, then reschedule
    if { $::update_is_running } {
	set ::profile_id [ after $::profile_delay { do_profile } ]
	return
    }
    set ::update_is_running 1
    set ::profile_id ""
    send_layout
    read_profile
    set ::update_is_running 0
}

## helper function to read the theoretical reflectivity signal.  This
## assumes that the layout has already been sent (by the do_profile
## request presumably)
proc do_reflect { } {
    # XXX FIXME XXX - can we make expect block?
    # reschedule if another update is currently running (which
    # can happen because the event loop is running while expect
    # is waiting. blech
    if { $::update_is_running } {
	set ::reflectivity_id [ after $::reflectivity_delay { do_reflect }]
	return
    }
    set ::update_is_running 1
    set ::reflectivity_id ""
    read_reflectivity
    set ::update_is_running 0
}

## Usage: update_gmlayer
##
## Signal that the layer configuration is changed and that
## a new profile and reflectivity signature should be read.
## Because recalculating the curves is a slow process, and
## because there are likely to be many requests in sequence
## as the controls are dragged around, the update is only
## processed when the request rate has slowed down.
proc update_gmlayer {} {
    if { $::profile_id != "" } { after cancel $::profile_id }
    set ::profile_id [ after $::profile_delay { do_profile } ]
    if { $::reflectivity_id != "" } { after cancel $::reflectivity_id }
    set ::reflectivity_id [ after $::reflectivity_delay { do_reflect } ]
}

set ::profile_id ""        ;# pending do_profile request
set ::reflectivity_id ""   ;# pending do_reflect request
set ::update_is_running 0  ;# true if do_profile or do_reflect are running

## helper function to send the layout and read the profile
proc do_profile { } {
    send_layout
    read_profile
    return

    # if currently running an update, then reschedule
    if { $::update_is_running } {
	set ::profile_id [ after $::profile_delay { do_profile } ]
	return
    }
    set ::update_is_running 1
    set ::profile_id ""
    send_layout
    read_profile
    set ::update_is_running 0
}

## helper function to read the theoretical reflectivity signal.  This
## assumes that the layout has already been sent (by the do_profile
## request presumably)
proc do_reflect { } {
    # XXX FIXME XXX - can we make expect block?
    # reschedule if another update is currently running (which
    # can happen because the event loop is running while expect
    # is waiting. blech
    if { $::update_is_running } {
	set ::reflectivity_id [ after $::reflectivity_delay { do_reflect }]
	return
    }
    set ::update_is_running 1
    set ::reflectivity_id ""
    read_reflectivity
    set ::update_is_running 0
}

# ====================== Command box ===========================
## Allow the user to type commands directly to the underlying
## gmlayer process and display the results.

set ::command_in $::commandbox.command_in
set ::command_out $::commandbox.command_out
frame $commandbox.entry
label $commandbox.entry.label -text "Command"
set ::command_text {}
entry $::command_in -textvariable ::command_text
bind $::command_in <Escape> { set ::command_text {} }
bind $::command_in <Return> { command_exec $::command_text }
pack $commandbox.entry.label -side left
pack $::command_in -in $commandbox.entry -side right -fill x -expand yes
pack $commandbox.entry -fill x
text $::command_out -wrap no -state disabled -height 8
pack [scroll $::command_out] -in $commandbox -fill both -expand yes
proc command_exec { command } {
    if { "" == $command } { return }
    set ::command_text {}
    send_layout
    eval "gmlayer $command"
if 0 {
    $::command_out see end
    text_append $::command_out "> [gmlayer ?]\n"
    $::command_out see end
}
    read_pars
    reset_all
}

# ==================== Constraints box =========================
## Suck in the current constraints if there are any and display
## them in the contraints box.  Show the code in program window.
## Disable the update button.
## XXX FIXME XXX is the old constraints file being destroyed if there
## are no new constraints?
proc reset_constraints {} {
    set ::constraints_script [gmlayer send constraints]
    text_replace $::constraints $::constraints_script
    constraints_modified 1
}

## Clear the constraints box and unload the constraints module
proc clear_constraints {} {
    # unload the constraints module
    # gmlayer ulc
    gmlayer send constraints {}
    # clear the constraints text
    text_clear $::constraints
    # don't reload constraints before next fit
    constraints_modified 0
}


## If the constraints text has been modified, save it to the
## constraints file and recompile it.  Let gmlayer know that
## the constraints file has been updated.  Update the program
## window with the newly generated C code and any compiler output.
proc update_constraints {} {
    # XXX FIXME XXX why was this commented out?
    if { [constraints_modified] } {
        set text [ $::constraints get 0.0 end ]
        if { [string length [string trim [string map { \n " " } $text]]] == 0 } {
            set text {}
            gmlayer constraints {}
        } else {
            proc fit_constraints {} $text
            gmlayer constraints fit_constraints
        }
        gmlayer send constraints $text
    }
    return 1
}

## Update the constraints and apply them to the current layout.
## Update all widgets with the new constraints.
proc apply_constraints {} {
    update_constraints
    send_layout
    gmlayer uc
    read_pars
    reset_all
}

## Don't apply the constraints during the fit
## XXX FIXME XXX this is never called
proc unload_constraints {} {
    gmlayer unc
}

proc constraints_modified {args} {
    if { [llength $args] } {
	$::constraints edit modified $args
    } else {
	# XXX FIXME XXX ctext doesn't return the correct value
	# when undo is used.
	return [$::constraints edit modified]
    }
}

## hide/show the translated constraints code and compiler output.
proc showprogram { newstate } {
    if { $newstate == 1 } {
	$::cbb.showprogram conf -text "Hide program" \
		-command { showprogram 0 }
	wm deiconify .compiler
	raise .compiler
    } else {
	$::cbb.showprogram conf -text "Show program" \
		-command { showprogram 1 }
	wm withdraw .compiler
    }
}

## Scrollable text widget for editting the constraints
set constraints $::constraintbox.constraints
#ScrolledWindow $::constraintbox.scroll -scrollbar vertical
ctext $::constraints
#$::constraintbox.scroll setwidget $::constraints
$::constraints.l conf -relief [option get $::constraints.l relief Relief]
bind $::constraints <<Modified>> {
    if {[constraints_modified]} {
	$::cbb.update conf -state normal
    } else {
	$::cbb.update conf -state disabled
    }
}

## Buttons for manipulating constraints
# XXX FIXME XXX Apply should be disabled if there are no constraints
set cbb $constraintbox.b
frame $cbb
button $cbb.update -text "Update" -command { update_constraints } \
	-state disabled
button $cbb.apply -text "Apply" -command { apply_constraints }
# button $cbb.showprogram -text "Show program" -command { showprogram 1 }
grid $cbb.update $cbb.apply -sticky ew -padx 3
grid columnconfigure $cbb {0 1} -weight 1 -uniform a

grid $::constraints -sticky news -padx 3
grid $cbb -sticky e
grid rowconfig $::constraintbox 0 -weight 1
grid columnconfig $::constraintbox 0 -weight 1

## Top-level window containing the C source generated from the constraints
## and showing the output from the constraint compiler.  Use show_program 1
## to display the window or show_program 0 to hide it.
toplevel .compiler
wm withdraw .compiler
wm protocol .compiler WM_DELETE_WINDOW {
    showprogram 0
}
text .compiler.out -wrap no -height 6 -state disabled
text .compiler.code -wrap no -height 18 -state disabled
PanedWindow .compiler.panes -side right
pack [scroll .compiler.out] -in [ .compiler.panes add -weight 1 ] -fill both -expand yes
pack [scroll .compiler.code] -in [ .compiler.panes add -weight 3 ] -fill both -expand yes
sashconf .compiler.panes
pack .compiler.panes -fill both -expand yes


# ==================== Fit box ==========================

# let gmlayer know what parameters are selected for varying; return
# the number of selected parameters
proc send_varying {} {
    gmlayer vanone
    set num_sent 0
    foreach item [ $::varying curselection ] {
	set field [$::varying get $item]
	if { $field != {} } {
	    gmlayer va$field
	    incr num_sent
	}
    }
    # XXX FIXME XXX silently fails if given an invalid parameter;
    # the following revert_varying mitigates this, but it is not
    # elegant
    foreach field $::varying_extra {
	gmlayer va$field
	incr num_sent
    }
    revert_varying
    return $num_sent
}

# Reset the layers shown in the fit variable selection table.
# Since the actual parameters are calculated rather than
# stored, clear the table cache so that any renumbered layers
# will be updated.
proc reset_varying {} {
    $::varying clear cache
    $::varying conf -rows $::num_layers
}

# Ask gmlayer what parameters are selected for varying
proc revert_varying {} {
    set ::varying_extra {}
    foreach item [gmlayer send varying] {
	if { ![set_parameter $item] } {
	    set ::varying_extra "$::varying_extra $item"
	}
    }
}

# prepare the results box to show intermediate results during the fit
proc init_results {} {
    set result_idx 1
    foreach item [ $::varying curselection ] {
	set par [$::varying get $item]
	# XXX FIXME XXX - can't show intermediate values on
	# artificial fit parameters
	if { [ parse_par $par field number ] } {
	    set ::results($result_idx,0) $par
	    set ::results($result_idx,1) {}
	    set ::results($result_idx,2) {}
	    set ::results($result_idx,field) $field
	    set ::results($result_idx,number) $number
	    incr result_idx
	}
    }
    set ::results(length) $result_idx
    text_clear .fitresults
    #! .fitresults conf -rows $::results(length)
}

# Interrupt the gmlayer fit process.  This restores the "Fit" button
# back to the usual "Fit" label instead of the "Stop fit" label.
proc stop_fit {} {
    gmlayer halt
    $::fitbox.b.fit conf -text "Stop fit" -command { do_fit } -state disabled
#    update idletasks
}

proc try_fit {} {
    # don't do anything if no fit parameters are selected
    if { [send_varying] == 0 } {
	set ::message "Select fit parameters first"
	bell
	return
    }

    # clear any error notification from the previous fit
    set ::message {}

    # We want immediate feedback that the fit button was pressed, so
    # we change its text to "Stop fit".  Since the fit has not really
    # started, we want to avoid sending SIGINT to mlayer, so we say
    # that we are not yet fitting.
    set ::fitting 0
    $::fitbox.b.fit conf -text "Stop fit" -command { stop_fit }
    $::fitbox.b.revert conf -state disabled
    update idletasks

    # Need to catch any errors in do_fit since this thread must run to
    # completion before the fit button is re-enabled.
    push_pars
     if { [catch { do_fit } msg ] } {
	tk_messageBox -message "Internal error - do_fit\n$msg" -type ok
    }

    # reset the fit button
    set ::fitting 0
    $::fitbox.b.fit conf -text "Fit" -command { try_fit } -state normal
    $::fitbox.b.revert conf -state normal
}

proc fit_update {} {
    read_pars
    read_profile
    read_reflectivity
    # XXX FIXME XXX should update positions, not redraw all markers
    draw_layers
    reset_table

    # update the results box
    text_clear .fitresults
    text_append .fitresults "\t$::results(0,1)\n"
    for { set i 1 } { $i < $::results(length) } { incr i } {
	set val [ layer $::results($i,number) $::results($i,field) ]
	set ::results($i,1) [ fix $val 0 [expr abs($val)] $::digits ]
	text_append .fitresults "$::results($i,0)\t$::results($i,1)\n"
    }

#    update idletasks
}

# Start the fit process and collect the fit results.
proc do_fit {} {
    # setup the results table to display the selected variables
    init_results

    # make sure the constraints are up-to-date
    if { ![update_constraints] } { stop_fit }

    # send the current parameters
    send_layout

    # start the fit
    set output [gmlayer fit fit_update]
    set result_idx 1
    foreach var $output {
	foreach {name value err} $var break
	set ::results($result_idx,0) $name
	set ::results($result_idx,1) $value
	set ::results($result_idx,2) $err
	incr result_idx
    }


    #! # update the results table size (since hidden parameters will
    #! # be displayed in the final results, but not during the
    #! # intermediate fit).
    #! .fitresults conf -rows $result_idx
    text_clear .fitresults
    text_append .fitresults "\t$::results(0,1)\t$::results(0,2)\n"
    for { set i 1 } { $i < $result_idx } { incr i } {
	set min [expr {$::results($i,1)-$::results($i,2)}]
	set max [expr {$::results($i,1)+$::results($i,2)}]
	set val [fix $::results($i,1) $min $max]
	set err [fix $::results($i,2) {} {} 2]
	text_append .fitresults "$::results($i,0)\t$val\t$err\n"
    }

    return

    # wait for fit results
    set result_idx 1
    set singular 0
    set timed_out 0
    expect {
	timeout {
	    # XXX FIXME XXX don't need to print this
	    set ::message "[lindex [info level 0] 0] timeout --- trying again"
	    set timed_out 1
	    exp_continue
	}
	"/** Singular matrix **/" {
	    if { $timed_out } {
		set timed_out 0
		puts "continuing with singular matrix"
	    }
	    # fit matrix is singular so label it as such
	    set ::message "Fit matrix is singular!!"
	    # since we don't get a message if the matrix is
	    # not singular, we have to automatically clear the
	    # message each fit cycle unless we receive notice
	    # that the fit matrix is singular.
	    set singular 1

	    exp_continue
	}
	-re "chisq=*(\[^ \n]*) *\n" {
	    if { $timed_out } {
		set timed_out 0
		puts "continuing with Chi-squared"
	    }
	    ## XXX FIXME XXX chisq=... calculated in ipc.c is
	    ## is different from Chi-squared:... calculated in mqrmin.

	    # update the reflectivity graph
	    set_chisq $expect_out(1,string)
	    # tk_messageBox -type ok -message "about to read mltmp.q"
	    read_vec mltmp.q reflect_q
	    foreach v $::active_slices { read_vec mltmp.r$v reflect_r$v }
	    # read the try values
	    read_vec mltmp.pars pars
	    set_vars_from_pars
	    # update the layer profile
	    draw_layers
	    # tk_messageBox -type ok -message "about to read mltmp.d"
	    read_vec mltmp.d prof_depth
	    read_vec mltmp.mu prof_mu
	    read_vec mltmp.qcsq prof_qcsq
	    if { $::MAGNETIC} {
		read_vec mltmp.mqcsq prof_mqcsq
		read_vec mltmp.theta prof_theta
	    }
	    # update the layer table
	    reset_table
	    # update the results box
	    text_clear .fitresults
	    text_append .fitresults "\t$::results(0,1)\n"
	    for { set i 1 } { $i < $::results(length) } { incr i } {
	    	set val [ layer $::results($i,number) $::results($i,field) ]
		set ::results($i,1) [ fix $val 0 [expr abs($val)] $::digits ]
		text_append .fitresults "$::results($i,0)\t$::results($i,1)\n"
	    }
	    #! .fitresults clear cache

	    # clear the singular message unless the current fit
	    # cycle yields a singular matrix
	    if { $singular } {
		set singular 0
	    } else {
		set ::message {}
	    }
	    update

	    exp_continue
	}
	-re " (\[A-Z0-9]+): *(\[^ ]*) \[+]/- *(\[^ ]*) *\n" {
	    if { $timed_out } {
		set timed_out 0
		puts "continuing with final output"
	    }
	    # XXX FIXME XXX this may reorder the parameters --- is there
	    # a better way to get the error values from the fit?
	    set ::fitting 0
	    set ::results($result_idx,0) $expect_out(1,string)
	    set val $expect_out(2,string)
	    set ::results($result_idx,1) [ fix $val 0 [expr abs($val)] $::digits ]
	    set val $expect_out(3,string)
	    set ::results($result_idx,2) [ fix $val 0 [expr abs($val)] $::digits ]
	    incr result_idx

	    exp_continue
	}
	"magblocks4%" { }
	"mlayer%" { }
    }
    if { $timed_out } {
	set timed_out 0
	puts "returning to prompt"
    }

    # spit out a new prompt since you've eaten the current one
    exp_send \r

    #! # update the results table size (since hidden parameters will
    #! # be displayed in the final results, but not during the
    #! # intermediate fit).
    #! .fitresults conf -rows $result_idx
    text_clear .fitresults
    text_append .fitresults "\t$::results(0,1)\t$::results(0,2)\n"
    for { set i 1 } { $i < $result_idx } { incr i } {
	text_append .fitresults "$::results($i,0)\t$::results($i,1)\t$::results($i,2)\n"
    }

    clean_temps
}

# restore parameters to how they were before the fit
proc revert_fit {} {
    pop_pars
    if { $::pars_stack == 0 } {
        $::fitbox.b.revert conf -state disabled
    }
    reset_all
}

# clear all the fit parameters
proc clear_fit {} {
    gmlayer vanone
    $::varying selection clear all
    set ::varying_extra {}
}


# Initialize the parameter selection table
# The parameter selection table entries are
# computed by show_parameter rather than being
# stored in a tcl array. Individual parameters
# may be selected by calling set_parameter with
# the string name of the parameter.
array set par_from_col {0 QC 1 MU 2 RO 3 D 4 QM 5 TH 6 RM 7 DM }
foreach { col field } [ array get par_from_col ] {
    set col_from_par($field) $col
}
array set extrapars  {0 VQC 1 VMU 2 BK 3 BI 4 "" 5 "" 6 "" 7 "" }
if { $::MAGNETIC } {
    proc show_parameter { row col } {
	if { $row == 0 } {
	    return $::extrapars($col)
	} else {
	    return $::par_from_col($col)$row
	}
    }
    # FIXME XXX this is similar to parse_par --- maybe combine them?
    proc set_parameter { string } {
	set string [ string toupper $string ]
	switch -glob -- $string {
	    BK { $::varying selection set 0,0; return 1 }
	    BI { $::varying selection set 0,1; return 1 }
	    DM* { set idx 2 }
	    D* { set idx 1 }
	    default { set idx 2 }
	}
	set field [ string range $string 0 [expr $idx - 1] ]
	set number [ string range $string $idx end ]
	if {![string is integer $number] \
		|| "$field" != [array names ::col_from_par $field] } {
	    error "attempting to vary $field$number, but gj2 won't recognize it."
	    return 0
	}
	if { $number <= $::num_layers } {
	    $::varying selection set $number,$::col_from_par($field)
	    return 1
	}
	return 0
    }
} else {
    proc show_parameter { row col } {
	if { $row == 0 } {
	    return $::extrapars($col)
	} else {
	    if { $row <= $::ntl } { return T$::par_from_col($col)$row }
	    incr row -$::ntl
	    if { $row <= $::nml } { return M$::par_from_col($col)$row }
	    incr row -$::nml
	    return B$::par_from_col($col)$row
	}
    }
    # FIXME XXX this is very similar to parse_par --- maybe combine them?
    proc set_parameter { string } {
	set string [ string toupper $string ]
	switch -glob -- $string {
	    BK { $::varying selection set 0,2; return 1 }
	    BI { $::varying selection set 0,3; return 1 }
	    VQC { $::varying selection set 0,0; return 1 }
	    VMU { $::varying selection set 0,1; return 1 }
	    ?D* { set idx 2 }
	    default { set idx 3 }
	}
	set section [ string range $string 0 0 ]
	set field [ string range $string 1 [expr $idx - 1] ]
	set number [ string range $string $idx end ]
	if {![string is integer $number] \
		|| "$field" != [array names ::col_from_par $field] } {
	    error "attempting to vary $item, but mlayer.tcl doesn't recognize it."
	    return 0
	}
	if { [layer_in_section $section $number ] } {
	    if { $section == "M" || $section == "B" } { incr number $::ntl }
	    if { $section == "B" } { incr number $::nml }
	    $::varying selection set $number,$::col_from_par($field)
	    return 1
	}
	return 0
    }
}



# define parameter selection table
set varying $::fitbox.varying
# ScrolledWindow $fitbox.varying_scroll
table $::varying -rows $::MAX_LAYERS -cols $::num_fields \
	-selectmode extended -selecttype cell \
	-colwidth 6 -state disabled -height 7 -anchor w \
	-command { show_parameter %r %c } -usecommand 1
# $fitbox.varying_scroll setwidget $::varying

# use mu and qcsq colours for mu and qcsq parameters
$::varying tag col qcsq $::col_from_par(QC)
$::varying tag col mu $::col_from_par(MU)
$::varying tag conf qcsq -fg $::color(qcsq)
$::varying tag conf mu -fg $::color(mu)
if { $::MAGNETIC } {
    $::varying tag col mqcsq $::col_from_par(QM)
    $::varying tag col theta $::col_from_par(TH)
    $::varying tag conf mqcsq -fg $::color(mqcsq)
    $::varying tag conf theta -fg $::color(theta)
}

# don't change the parameter colour when the parameter is selected
$::varying tag conf sel -fg {}

# don't use mu or qcsq colours for parameters which
# happen to be in mu or qcsq columns
#$::varying tag row normal 0
#$::varying tag conf normal -fg black
#$::varying tag raise normal

# ignore the empty cells
if { $::MAGNETIC } {
    $::varying tag cell unused 0,4 0,5 0,6 0,7
    $::varying tag conf unused -relief flat
    $::varying tag raise unused
}

# define an input box for the extra parameters which are not part
# of the layer structure but are instead used by constraints to
# calculate parts of the layer structure
frame $fitbox.varying_extra
label $fitbox.varying_extra.label -text "Extras"
entry $fitbox.varying_extra.entry -textvariable ::varying_extra
pack $fitbox.varying_extra.label -side left
pack $fitbox.varying_extra.entry -side left -fill x -expand y

# define parameter results table
array set ::results { 0,0 "Parameter" 0,1 "Fit value" 0,2 "Fit error" }
#! table .fitresults -titlerows 1 -selectmode extended -state disabled \
#!	-colwidth 13 -variable ::results -rows 1 -cols 3
#! .fitresults width 0 8
text .fitresults -wrap no -state disabled -relief flat -width 40
# ScrolledWindow $fitbox.results
# $fitbox.results setwidget .fitresults

# define fit control buttons
frame $fitbox.b
button $fitbox.b.fit -underline 3 -text "Fit" -command { try_fit }
# button $fitbox.b.replay -text "Replay" -command { replay_fit }
button $fitbox.b.snap -underline 0 -text "Snapshot" -command { snapshot }
button $fitbox.b.revert -underline 0 -text "Undo" -command { revert_fit } -state disabled
#button $fitbox.b.clear -text "Clear" -command { clear_fit }
# XXX FIXME XXX add a print button
pack $fitbox.b.fit $fitbox.b.revert $fitbox.b.snap -side top -fill x

bind $fitbox <Alt-t> [list $fitbox.b.fit invoke ]
bind $fitbox <Alt-s> [list $fitbox.b.snap invoke ]
bind $fitbox <Alt-u> [list $fitbox.b.revert invoke ]

# realize the fit control box
label $fitbox.varying_label -text "Fit parameters"
#! label $fitbox.results_label -text "Fit results"
grid $fitbox.varying_label    x     [scroll .fitresults] -sticky n
grid [scroll $::varying]   $fitbox.b        ^            -sticky news
grid $fitbox.varying_extra    -             -            -sticky ew
grid columnconfigure $fitbox 0 -weight 1
grid columnconfigure $fitbox 1 -weight 0
grid columnconfigure $fitbox 2 -weight 1
grid rowconfigure $fitbox 0 -weight 0
grid rowconfigure $fitbox 1 -weight 1
grid rowconfigure $fitbox 2 -weight 0

## proc focusfit {args} { focus $::fitbox.b.fit }


# ==================== Beam box =========================

# input form for the various beam characteristics
addfields $beambox [subst {
    {real bi "intensity"             {} "$::field_help(bi)" }
    {real bk "background"            {} "$::field_help(bk)" }
    {real wl "wavelenth"             "Angstroms" "$::field_help(wl)" }
    {real dl "wavelength divergence" "Angstroms" "$::field_help(dl)" }
    {real dt "angular divergence"    "radians" "$::field_help(dt)" }}]
bind $beambox.bi <Return> update_gmlayer
bind $beambox.bk <Return> update_gmlayer
bind $beambox.wl <Return> update_gmlayer
bind $beambox.dl <Return> update_gmlayer
bind $beambox.dt <Return> update_gmlayer

bind $beambox.bi <FocusOut> update_gmlayer
bind $beambox.bk <FocusOut> update_gmlayer
bind $beambox.wl <FocusOut> update_gmlayer
bind $beambox.dl <FocusOut> update_gmlayer
bind $beambox.dt <FocusOut> update_gmlayer

proc focus_beambox {} {
    $::notebook raise Beam
}


## ============== Layer profile graph =====================

# show/hide field on the graph, including the profile curve, its
# corresponding axis and all the widget handles; the legend entry
# is always on since it is used to trigger the toggle.  If you want
# to completely suppress the field, then remove its entry from
# ::active_fields in defaults.tcl before starting the program.
proc toggle_field { w field hide } {
    set ::hidden($field) $hide

    $w axis conf $field -hide $hide

    # XXX FIXME XXX we shouldn't have to suppress the bindtags since the
    # markers are hidden when the associated element is hidden.  This
    # is a bug in BLT
    if { $hide } { set tags {} } else { set tags handle }
    foreach marker [ .layers marker name ${field}* ] {
	.layers marker conf $marker -bindtags $tags -hide $hide
    }

    # XXX FIXME XX it might be amusing to allow [toggle_field depth]
}

## Graph for the layer profile
graph .layers -height 2i -width 4i -halo 2

active_legend .layers toggle_field

# define different y axes for the various curves
## XXX FIXME XXX put all field labels (short, medium, long, printable) and
## units in one table
.layers axis create mu -color $::color(mu)
.layers axis create qcsq -color $::color(qcsq)
if {$::MAGNETIC} {
    .layers axis create mqcsq -color $::color(mqcsq)
    .layers axis create theta -color $::color(theta)
    .layers yaxis use { qcsq mqcsq }
    .layers y2axis use { mu theta }
} else {
    .layers yaxis use qcsq
    .layers y2axis use mu
}

# all curves share a common x axis
.layers axis conf x -title "z (Angstroms)"

# The layer interface bars and layer labels are mapped via a hidden
# y axis normalized to the range [0,1].  In the magnetic case, with
# its duplicate layer structure, the magnetic layers/labels are
# represented in the range [1,2].
if {$::MAGNETIC} {
    .layers axis conf y -hide 1 -min 0 -max 2
} else {
    .layers axis conf y -hide 1 -min 0 -max 1
}

# decorate the graph with a legend and scroll bars
scrollbar $layerbox.xbar -command { .layers axis view x } -orient horizontal
.layers axis conf x -scrollcommand { $layerbox.xbar set } -loose no
# pack $layerbox.xbar -fill x -side top
##Don't want y-scroll
#scrollbar $layerbox.ybar -command { .layers axis view y } -orient vertical
#.graph axis configure y -scrollcommand { $layerbox.ybar set } -logscale no
# pack .layers -in $layerbox -fill both -expand yes -side top

# add the graph control buttons
frame $layerbox.b
button $layerbox.b.rescale -underline 0 -text Rescale -command { rescale }
button $layerbox.b.print -underline 0 -text Print -command { print .layers }
button $layerbox.b.snap -underline 0 -text Snapshot -command { snapshot }
grid $layerbox.b.rescale $layerbox.b.print $layerbox.b.snap -sticky ew -padx 3
grid columnconfigure $layerbox.b {0 1 2} -uniform a
bind $layerbox <Alt-r> [list $layerbox.b.rescale invoke ]
bind $layerbox <Alt-p> [list $layerbox.b.print invoke ]
bind $layerbox <Alt-s> [list $layerbox.b.snap invoke ]

grid $layerbox.xbar -sticky ew
grid .layers -in $layerbox -sticky news
grid $layerbox.b -sticky e
grid rowconfigure $layerbox 1 -weight 1
grid columnconfigure $layerbox 0 -weight 1
pack $layerbox -fill both -expand yes

# data vectors to hold the curves; all profiles share the same x-axis
vector create prof_depth
vector create prof_qcsq
vector create prof_mu
if {$::MAGNETIC} {
    vector create prof_mqcsq
    vector create prof_theta
}

# add layer profile lineshapes
# XXX FIXME XXX consider storing the hidden state either in the
# parameter file or in a resource file in the home directory so that
# it will be preserved across invocations of the program
foreach field $::active_fields {
    .layers elem create $field -xdata ::prof_depth -ydata ::prof_$field \
	    -mapy $field -symbol {} -label $field -color $::color($field)
    if { $::use_dashes_on_screen } {
	.layers elem conf $field -dashes $::dashes($field)
    }
    legend_set .layers $field [string is false $::hidden($field)]
}


# respond to a mouse action request on a layer graph marker
set ::hover {} ;# variable to hold the hover request
set ::current_field {}
proc handle { x y action args } {
    ## determine which field of which layer is being acted on
    set element [ .layers marker get current ]
    switch -glob -- $element {
	mu* { set field mu }
	qcsq* { set field qcsq }
	depth* { set field depth }
	mqcsq* { set field mqcsq }
	theta* { set field theta }
	mdepth* { set field mdepth }
	default { return }
    }
    set number [ string range $element [string length $field] end ]

    set ::current_field $field
    set ::current_number $number

    # process the action
    switch $action {
	"show_coords" {
	    # Pop up marker coordinates after a short delay.  If the
	    # mouse moves in the meantime, then clear_coords will
	    # cancel the popup request.
	    catch { after cancel $::hover }
	    set $::hover [ after 500 [ list show_handle $x $y $field $number ] ]
	}
	"clear_coords" {
	    # Remove the marker coordinates and cancel any outstanding
	    # popup requests.
	    catch { after cancel $::hover }
	    .layers marker conf coords -hide 1 -text {}
	}
	"drag_start" {
	    # clear the previous cached values
	    catch { unset start }
	    # remember the current field and its associated interface boundary
	    set ::start($field) [ layer $number $field ]
	    if { $number > 0 } {
		switch $field {
		    mu -
		    qcsq -
		    depth {set ::start(last) [layer [expr $number-1] offset] }
		    theta -
		    mqcsq -
		    mdepth {set ::start(last) [layer [expr $number-1] moffset]}
		}
	    } else {
		set ::start(last) 0
	    }
	    # remember the "complementary field", which for curves is
	    # ro/mro and for depth is the next depth/mdepth
	    switch $field {
		mu - qcsq - depth { set ro ro }
		theta - mqcsq - mdepth { set ro mro }
	    }
	    set ::start(ro) [layer $number $ro]
	    switch $field {
		depth - mdepth {
		    if { $number < $::num_layers-1 } {
			set ::start(next) [ layer [expr $number+1] $field ]
			set ::start(nextro) [ layer [expr $number+1] $ro ]
		    }
		    if { $number < $::num_layers-2 } {
			set ::start(nextnextro) [ layer [expr $number+2] $ro ]
		    }
		}
	    }
	    # Start showing the current marker coordinates.
	    show_handle $x $y $field $number
	}
	"drag_end" {
	    # Stopped dragging, so hide the marker coordinates.
	    .layers marker conf coords -hide 1 -text {}
	    # XXX FIXME XXX can I put a trace on the relevant parameter
	    # so that the table stays up to date?
	    reset_table
	}
	"drag_special" -
	"drag" {
	    # Process mouse movement requests.
	    if { $field == "depth" || $field == "mdepth" } {
		drag_depth $x $y $action $field $number
	    } else {
		drag_ro $x $y $action $field $number
	    }
	}
	default {
	    error "unknown action $action.  Use handle x y {drag|drag_special|drag_start|drag_end|show_coords|clear|coords}"
	}
    }
}

proc reset_handle {} {
    # Determine which marker we are working on.
    # Silently do nothing if no marker is selected
    if { [string equal {} $::current_field] } return
    set field $::current_field
    set number $::current_number

    layer $number $field $::start($field)
    switch $field {
	mu - qcsq - depth { set ro ro }
	theta - mqcsq - mdepth { set ro mro }
    }
    layer $number $ro $::start(ro)
    switch $field {
	depth - mdepth {
	    if { $number < $::num_layers-1 } {
		layer [expr $number+1] $field $::start(next)
		layer [expr $number+1] $ro $::start(nextro)
	    }
	    if { $number < $::num_layers-2 } {
		layer [expr $number+2] $ro $::start(nextnextro)
	    }
	    set update_field $field
	}
	default { set update_field $ro }
    }

    # update the view
    update_widgets $number $update_field
    update_gmlayer
}

proc nudge_handle { size orient } {
    # Determine which marker we are working on.
    # Silently do nothing if no marker is selected
    if { [string equal {} $::current_field] } { return }
    set field $::current_field
    set number $::current_number

    # choose field on the basis of direction
    set field $field
    if { [string equal "$orient" h] } {
	switch -- $field {
	    mu - qcsq { set field ro }
	    theta - mqcsq { set field mro }
	}
    }
    set move_interface 0
    switch -- $field {
	depth - mdepth {
	    if { $number < $::num_layers - 1 } {
		set move_interface [string equal "$orient" v]
	    }
	}
    }

    # compute the step size for a single pixel
    switch -- $field {
	depth - mdepth - ro - mro {
	    set step [expr [ .layers axis invtransform x 1 ] - \
		    [.layers axis invtransform x 0 ]]
	}
	default {
	    set step [expr [ .layers axis invtransform $field 0 ] - \
		    [.layers axis invtransform $field 1]]
	}
    }

    # Take a scaled step
    set step [expr $step * $size]
    if { $move_interface } {
	set next [expr $number+1]
	set thisd [layer $number $field]
	set nextd [layer $next $field]
	set joint [expr $thisd + $nextd]
	set pos [expr $thisd + $step]
	# XXX FIXME XXX don't hardcode 1 for minimum depth
	# here and elsewhere
	if { $pos < 1 } {
	    set pos 1
	} elseif { $pos > $joint-1 } {
	    set pos [expr $joint-1]
	}
	layer $number $field $pos
	layer $next $field [expr $joint-$pos]
    } else {
	layer $number $field [expr [layer $number $field] + $step]
    }

    # show the new coordinates
    .layers marker conf coords \
	    -coords [lrange [.layers marker cget $::current_field$number -coords] 0 1] \
	    -mapy [.layers marker cget $::current_field$number -mapy] \
	    -text "$field [layer $number $field]" -hide 0 \
 	    -outline $::color($::current_field) -fill {} -under 1


    # update the view
    update_widgets $number $field
    update_gmlayer
}

# display the current coordinates of the given field
# XXX FIXME XXX similar code exists in drag_ro and drag_depth
proc show_handle { x y field number } {

    set yaxis $field
    if { $field == "depth" || $field == "mdepth" } {
	set yaxis y
    }
    set height [ .layers axis invtransform $yaxis $y ]
    set offset [ .layers axis invtransform x $x ]
    set text "$field [layer $number $field]"
    if { $number != 0 } {
	if { $field == "mu" || $field == "qcsq" } {
	    set text "$text\nro [layer $number ro]"
	} elseif { $field == "theta" || $field == "mqcsq" } {
	    set text "$text\nmro [layer $number mro]"
	}
    }
    .layers marker conf coords -coords {$offset $height} -mapy $yaxis \
	    -text $text -hide 0 -outline $::color($field) -fill white

    # XXX FIXME XXX after isn't working !?
    after 500 { .layers marker conf coords -hide 1 -text {} }
}

# respond to a drag action on a roughness/value handle
proc drag_ro {x y action field number} {

    # decide if we should use nuclear or magnetic layers
    # for roughness
    if { $field == "mqcsq" || $field == "theta" } {
	set which_ro mro
    } else {
	set which_ro ro
    }

    # determine which things are being dragged based on the distance from
    # from the original in x and y
    switch $action {
	"drag" {
	    # need to recalculate the assumed starting position in case
	    # the graph automagically shifted or rescaled itself while
	    # dragging the widget handle
	    if { $number == 0 } {
		# don't update vacuum layer roughness
		set update_ro 0
		set update_field 1
	    } else {
		set ro_offset [expr $::start(ro) + $::start(last) ]
		set startx [.layers axis transform x $ro_offset ]
		set starty [.layers axis transform $field $::start($field) ]

		if { abs($x-$startx) < abs($y-$starty) } {
		    set update_ro 0
		    set update_field 1
		} else {
		    set update_ro 1
		    set update_field 0
		}
	    }
	}
	"drag_special" {
	    set update_ro [ expr $number != 0 ] ;# don't update vacuum layer ro
	    set update_field 1
	}
	default {
	    error "{drag_special|drag}"
	}
    }

    # update the value
    if { $update_field } {
	# determine the new field magnitude by converting screen
	# coordinates for value into graph coordinates clipped by
	# the boundary of the graph
	set val [ .layers axis invtransform $field $y ]
	set min [ .layers axis cget $field -min ]
	set max [ .layers axis cget $field -max ]
	if { $val < $min } { set val $min }
	if { $val > $max } { set val $max }
	set val [ fix $val $min $max ] ;# don't use excess precision
    } else {
	set val $::start($field)
    }

    # if not vacuum layer, update the roughness
    if { $update_ro && $number != 0 } {
	# determine the new roughness as distance from the
	# interface boundary position of the previous layer,
	# but restrict it to positive values
	set ro [expr [ .layers axis invtransform x $x ] - $::start(last) ]
	if { $ro < 1 } { set ro 1 }
	set ro [ fix $ro 0 $ro ] ;# don't use excess precision
    } else {
	set ro $::start(ro)
    }

    # update gmlayer with our new values, or with the old values in
    # case the user is playing with the drag_special buttons.
    layer $number $field $val
    if { $number > 0 } {
	layer $number $which_ro $ro
	# reread ro after constraints are applied
	set ro [ layer $number $which_ro ]
    }

    # show updated value and/or roughness
    # don't show roughness value for vacuum layer
    if { $update_ro && $update_field } {
	set display "$field $val\n$which_ro $ro"
    } elseif { $update_ro } {
	set display "$which_ro $ro"
    } else {
	set display "$field $val"
    }
    .layers marker conf coords \
	    -coords [list [expr $ro + $::start(last)] $val] \
	    -mapy $field -text $display -hide 0 \
 	    -outline $::color($field) -fill {}

    # update the layer profile widgets and the graphs
    update_widgets $number $which_ro
    update_gmlayer
}

# respond to a drag action on a layer interface handle
proc drag_depth {x y action field number} {

    # determine the new position of the bar
    set offset [ .layers axis invtransform x $x ]
    set height [ .layers axis invtransform y $y ]

    # translate offset=last_offset+depth to depth
    set value [expr $offset - $::start(last)]

    # make sure there is still some depth
    if { $value < 1 } { set value 1 }

    # don't include meaningless precision
    set value [ fix $value 0 $value ]

    switch $action {
	"drag" {
	    # update with new depth
	    layer $number $field $value
	    if { $number < $::num_layers - 1 } {
		layer [expr $number+1] $field $::start(next)
	    }
	}
	"drag_special" {
	    if { $number < $::num_layers - 1 } {
		if { $value > $::start($field)+$::start(next)-1 } {
		    set value [expr $::start($field)+$::start(next) - 1]
		}
		layer $number $field $value
		layer [expr $number+1] $field \
			[expr $::start($field)+$::start(next)-$value]
	    } else {
		layer $number $field $value
	    }
	}
	default {
	    error "{drag_special|drag}"
	}
    }

    # display depth
    .layers marker conf coords -mapy y \
	    -coords [list [expr $::start(last)+$value] $height] \
	    -text "$field $value" -hide 0 -outline $::color($field) -fill {}

    # update the layer profile widgets and the graphs
    update_widgets $number $field
    update_gmlayer
}


# recompute the positions of all the markers for the nuclear layers
proc reset_offsets {} {
    if { $::MAGNETIC } {
	set repeat_at -1
    } else {
	set repeat_at [ expr $::ntl + $::nml + 1 ]
	set repeat_depth 0
	for {set i [expr $::ntl + 1]} { $i < $repeat_at } { incr i } {
	    set repeat_depth [ expr $repeat_depth + [ layer $i depth ] ]
	}
	set repeat_skip [expr $repeat_depth * ($::nrepeat - 1)]

	## XXX FIXME XXX if you want the middle layers grayed when
	## they are not repeating then comment out the following line:
	if { $::nrepeat == 1 } { set repeat_at -1 }
    }
    set offset 0
    for {set i 0} { $i < $::num_layers } { incr i} {
	set qcsq [ layer $i qcsq ]
	set mu [ layer $i mu ]
	set depth [ layer $i depth ]
	set ro [ layer $i ro ]
	set ro_offset [expr $offset + $ro]
	set offset [expr $offset + $depth]
	if { $i == $repeat_at } { set offset [expr $offset + $repeat_skip] }
	layer $i offset $offset

	.layers marker conf depth${i} -coords [ list $offset 0 $offset 1 ]
	.layers marker conf layer${i} -coords { $offset 0 }
	.layers marker conf mu${i} -coords { $ro_offset $mu }
	.layers marker conf qcsq${i} -coords { $ro_offset $qcsq }

    }
    if { $repeat_at > 0 } {
	set left [ layer $::ntl offset ]
	set right [ expr $left + $repeat_skip + $repeat_depth ]
	.layers marker conf repeat -hide 0 \
		-coords [list $left -Inf $left Inf $right Inf $right -Inf ]
        .layers marker conf repeatcount -hide 0 -coords [list $right Inf] \
                -text "x$::nrepeat" -anchor ne

    }
}

# recompute the positions of all the markers for the magnetic layers
proc reset_moffsets {} {
    set moffset 0
    for {set i 0} { $i < $::num_layers } { incr i} {
	set mqcsq [ layer $i mqcsq ]
	set theta [ layer $i theta ]
	set mdepth [ layer $i mdepth ]
	set mro [ layer $i mro ]
	set mro_offset [expr $moffset + $mro]
	set moffset [expr $moffset + $mdepth]
	layer $i moffset $moffset

	.layers marker conf mdepth${i} -coords [ list $moffset 1 $moffset 2 ]
	.layers marker conf mlayer${i} -coords { $moffset 2 }
	.layers marker conf theta${i} -coords { $mro_offset $theta }
	.layers marker conf mqcsq${i} -coords { $mro_offset $mqcsq }

    }
}

# update the marker positions to reflect a change in a layer value.
proc update_widgets { number field } {
    switch $field {
	qcsq -
	mu {
	    ## update the height of the appropriate tool
	    if { $number > 0 } {
		set ro_offset [expr [layer [expr $number - 1] offset] \
			+ [layer $number ro]]
	    } else {
		set ro_offset 0
	    }
	    .layers marker conf ${field}${number} \
		    -coords [list $ro_offset [layer $number $field] ]
	}
	depth {
	    # need to update all widgets from the current
	    # to the end, so just reset them all
	    reset_offsets
	}
	ro {
	    # reposition the handles for mu and qcsq
	    if { $number >= 1  } {
		set ro_offset [expr [layer [expr $number - 1] offset]\
			+ [layer $number ro]]
		.layers marker conf qcsq${number} \
			-coords [list $ro_offset [layer $number qcsq] ]
		.layers marker conf mu${number} \
			-coords [list $ro_offset [layer $number mu] ]
	    } else {
		.layers marker conf qcsq0 -coords "0 [layer 0 qcsq]"
		.layers marker conf mu0 -coords "0 [layer 0 mu]"
	    }
	}
	mqcsq -
	theta {
	    ## update the height of the appropriate tool
	    if { $number > 0 } {
		set ro_offset [expr [layer [expr $number - 1] moffset] \
			+ [layer $number mro]]
	    } else {
		set ro_offset 0
	    }
	    .layers marker conf ${field}${number} \
		    -coords [list $ro_offset [layer $number $field] ]
	}
	mdepth {
	    # need to update all widgets from the current
	    # to the end, so just reset them all
	    reset_moffsets
	}
	mro {
	    # reposition the handles for mu and qcsq
	    if { $number >= 1  } {
		set ro_offset [expr [layer [expr $number - 1] moffset]\
			+ [layer $number mro]]
		.layers marker conf mqcsq${number} \
			-coords [list $ro_offset [layer $number mqcsq] ]
		.layers marker conf theta${number} \
			-coords [list $ro_offset [layer $number theta] ]
	    } else {
		.layers marker conf qcsq0 -coords "0 [layer 0 mqcsq]"
		.layers marker conf mu0 -coords "0 [layer 0 theta]"
	    }

#	    # if repositioning the handle beside the vacuum layer,
#	    # move the vacuum layer roughness handle as well.
#	    if { $number == 1 } {
#		set ro [layer 1 ro]
#		.layers marker conf qcsq0 \
#			-coords [list -$ro [layer 0 qcsq] ]
#		.layers marker conf mu0  \
#			-coords [list -$ro [layer 0 mu] ]
#	    }

	}
    }
}


# rescale the axes so that the profile curves all fit, but leaving room
# to drag the controls to larger values.
proc rescale {} {
    foreach field $::active_fields {
	# determine limits of data
	set min 0
	set max 0
	for {set i 0} { $i < $::num_layers } {incr i} {
	    set val [ layer $i $field ]
	    if { $val < $min } { set min $val }
	    if { $val > $max } { set max $val }
	}

	# set axis limits
	if { $max == 0 } { set max 1e-4 }
	set max [fix [expr 2*$max] 0 $max 1]
	if { $min < 0 } { set min [fix [expr 2*$min] $min 0 1] }
	.layers axis conf $field -min $min -max $max
    }


    # set reasonable limits on the x-axis
    .layers axis conf x -min 0 \
	    -max [expr 1.5 * [ layer [expr $::num_layers - 1 ] offset ] ]

    if {0} {
	# move the rescale button to the correct place
	.layers marker conf $::rescale_marker -coords { 0 $maxqcsq }
    }
}


# create and position all widgets for the layer profile graph
proc draw_layers {} {
    # clear existing layers
    eval .layers marker delete [ .layers marker names ]

    # gmlayer has a repeat area which we represent with a filled rectangle
    if { !$::MAGNETIC } {
	.layers marker create polygon -name repeat \
		-fill $::color(repeat) -outline $::color(repeat) \
		-mapy y -under 1
        .layers marker create text -name repeatcount -mapy y -under 0
    }

    # Cycle through the layers, creating interfaces and control handles
    for {set i 0} { $i < $::num_layers } {incr i} {

	# layer name
	if { $::MAGNETIC } {
	    .layers marker create text -name mlayer${i} -anchor ne -mapy y \
		    -text M[ layer ${i} name ] -rotate 90 -under 1 -outline red
	    .layers marker create text -name layer${i} -anchor se -mapy y \
		    -text N[ layer ${i} name ] -rotate 90 -under 1 -outline red
	} else {
	    .layers marker create text -name layer${i} -anchor se -mapy y \
		    -text [ layer ${i} name ] -rotate 90 -under 1 -outline red
	}
	# interface bar
	foreach field $::active_depths {
	    .layers marker create line -name $field$i -linewidth 2 -mapy y \
		    -dashes {5 3} -under 0 -bindtags handle \
		    -outline $::color($field)
	}
	# control widget
	foreach field $::active_fields {
	    if { $::hidden($field) } { set tags {} } else { set tags handle }
	    .layers marker create bitmap -name $field$i -mapy $field \
		    -fill $::color($field) -outline black -bitmap box \
		    -bindtags $tags -element $field -hide $::hidden($field)
	}
    }

    # special handling for the first and last interface
    foreach field $::active_depths {
	# doesn't matter what the depth is on the bottom layer
	# .layers marker conf $field[expr $::num_layers - 1] -hide 1

	# don't allow user to drag the first depth marker
	.layers marker conf ${field}0 -bindtags {}
    }

    # fill in the coordinates for the markers
    reset_offsets
    if { $::MAGNETIC } { reset_moffsets }

    # set the scales on the axes
    rescale

    # define a place to display the current value while dragging widgets
    .layers marker create text -name coords -anchor s -outline green
}

# set up zoom stack
active_graph .layers
# Blt_ZoomStack .layers

bind .layers <Motion> { %W crosshairs conf -position @%x,%y }

# Define the nudging keys
bind .layers <Up>    { nudge_handle  1 v }
bind .layers <Down>  { nudge_handle -1 v }
bind .layers <Right> { nudge_handle  1 h }
bind .layers <Left>  { nudge_handle -1 h }
bind .layers <Control-Up>    { nudge_handle  0.2 v }
bind .layers <Control-Down>  { nudge_handle -0.2 v }
bind .layers <Control-Right> { nudge_handle  0.2 h }
bind .layers <Control-Left>  { nudge_handle -0.2 h }
# Defining Shift Right/Left here is a little hokey, but
# it means that Shift+Drag to move the interface corresponds
# to Shift+Arrow to move the interface.  The fact that this
# behaviour is strange for the qcsq/mu controls I don't think
# will be a problem.
bind .layers <Shift-Right> { nudge_handle  1 v }
bind .layers <Shift-Left>  { nudge_handle -1 v }
bind .layers <Shift-Control-Right> { nudge_handle  0.2 v }
bind .layers <Shift-Control-Left>  { nudge_handle -0.2 v }

# Use the escape key to restore the parameters.
bind .layers <Escape> { reset_handle }

## Bind actions to the graph controls
.layers marker bind handle <B1-Motion> { handle %x %y drag }
# XXX FIXME XXX reset is attached to the Escape key now
.layers marker bind handle <Control-B1-Motion> { reset_handle }
set CtrlNotPressed 1
set ShiftNotPressed 1
foreach side { L R } {
    bind .layers <KeyPress-Control_$side> {
	if {$CtrlNotPressed} {
	  if {$B1pressed} { reset_handle }
	  set CtrlNotPressed 0
        }
    }
    bind .layers <KeyRelease-Control_$side> {
	set CtrlNotPressed 1
	if {$B1pressed} { handle %x %y drag }
    }
    bind .layers <KeyPress-Shift_$side> {
	if {$ShiftNotPressed} {
	  if {$B1pressed} { handle %x %y drag_special }
	  set ShiftNotPressed 0
        }
    }
    bind .layers <KeyRelease-Shift_$side> {
	set ShiftNotPressed 1
	if {$B1pressed} { handle %x %y drag }
    }
}
.layers marker bind handle <Shift-B1-Motion> { handle %x %y drag_special }
.layers marker bind handle <Button-1> {
    set B1pressed 1;
    focus .layers; zoom %W off;
    handle %x %y drag_start
}
.layers marker bind handle <ButtonRelease-1> {
    set B1pressed 0;
    zoom %W on;
    handle %x %y drag_end
}
if { $do_hover } {
    # XXX FIXME XXX why doesn't BLT generate all leave events?
    .layers marker bind handle <Enter> { handle %x %y show_coords }
    .layers marker bind handle <Leave> { handle %x %y clear_coords }
}

# use print button rather than clicking the graph to print.  Clicking the
# graph was obscure, plus it conflicts with the unzoom click
# bind .layers <Shift-ButtonPress-3> { print %W }
proc print { widget } {
    # XXX FIXME XXX we maybe want to redraw graph more suitable for printing
    PrintDialog $widget
}


# ===================== Reflectivity graph =============================

# display the reflectivity graph
option add reflectivity.Width 6i startupFile
option add reflectivity.Height 3i startupFile
graph .reflectivity
active_legend .reflectivity
active_axis .reflectivity y

# add curves for each data and theory line; all theory lines share a common Q
vector create reflect_q
foreach v $::active_slices {
    vector create reflect_r$v
    vector create data_q$v
    vector create data_r$v
    vector create data_e$v
    .reflectivity elem create reflect$v -xdata reflect_q -ydata reflect_r$v
    .reflectivity elem create data$v -xdata data_q$v -ydata data_r$v
    if [blt_errorbars] { .reflectivity elem conf data$v -yerror data_e$v }
    if { $::use_dashes_on_screen } {
	.reflectivity elem conf reflect$v -dashes $::dashes(r$v)
    }
    legend_set .reflectivity reflect$v [string is false $::hidden(reflect$v)]
    legend_set .reflectivity data$v [string is false $::hidden(data$v)]
}

# add a fresnel curve
# vector create fresnel_q
# vector create fresnel_r
# .reflectivity elem create fresnel -xdata fresnel_q -ydata fresnel_r

# add axis labels
.reflectivity axis conf x -title "Q (inverse Angstroms)"
.reflectivity axis conf y -title "Reflectivity" -logscale 1

# add zoom capability.  No particular reason to scroll the zoomed graph
#Blt_ZoomStack    .reflectivity
active_graph .reflectivity

# add print capability
# XXX FIXME XXX this should be controlled with a button rather than
# a mouse click on the graph.
# bind .reflectivity <Shift-ButtonPress-3> { PrintDialog %W }

bind .reflectivity <Motion> { %W crosshairs conf -position @%x,%y }


# display chi^2 on the graph
.reflectivity axis conf x2 -min 0 -max 1
.reflectivity axis conf y2 -min 0 -max 1
.reflectivity marker create text -name chisq \
	-mapx x2 -mapy y2 -coords { 0 0 } -anchor sw
#	-fill $::color(legend) -outline black \

# update the chisq meter with the apropriate value
# XXX FIXME XXX should be displaying chisq for each line as well
proc set_chisq { { value {} } } {
    if {![string is double $value]} {
	error "chisq value is not valid <$value>"
    }
    if { [string equal {} $value] || $value < 0. } {
	set text {}
    } else {
	set text "$::symbol(chi)$::symbol(squared) = [ fix $value ]"
    }
    .reflectivity marker conf chisq -text $text
}


# display the graph
pack .reflectivity -in $reflectivitybox -fill both -expand yes -side left

set ::colorlist [option get . lineColors LineColors]
set ::linecolor -1
set snapnum 0
proc snapshot { } {
    set_pars_from_vars ::snap_[incr ::snapnum]
    if { [incr ::linecolor] >= [llength $::colorlist] } {
        set ::linecolor 0
    }
    set c [lindex $::colorlist $::linecolor]
    foreach v $::active_slices {
        set p ${v}_$::snapnum
        ::reflect_q dup ::snapq$p
        ::reflect_r dup ::snapr$p
        .reflectivity elem create snap$p \
            -xdata ::snapq$p -ydata ::snapr$p -color $c \
            -label "snap $::snapnum"
    }
}
proc snapto {w} {
    set el [active_graph $w element]
    if { [string match snap* $el] } {
        set offset [string first _ $el]
        set elnum [string range $el [incr offset] end]
        ::snap_$elnum dup ::pars
        set_vars_from_pars
        send_layout
        read_profile
        draw_layers
        reset_table
        foreach v $::active_slices {
            set p ${v}_$elnum
            ::snapq$p dup ::reflect_q
            ::snapr$p dup ::reflect_r
        }
    }
}
proc snapclear {w} {
    set el [active_graph $w element]
    if { [string match snap* $el] } {
        set offset [string first _ $el]
        set elnum [string range $el [incr offset] end]
        eval vector delete [vector names ::snap*_$elnum]
        eval .reflectivity elem delete [.reflectivity element names snap*_$elnum]
    }
}
.reflectivity.menu add separator
.reflectivity.menu add command -label "Snapshot" -underline 0 -command { snapshot }
.reflectivity.menu add command -label "Revert" -underline 0 -command { snapto .reflectivity }
.reflectivity.menu add command -label "Clear" -underline 0 -command { snapclear .reflectivity }

# ===================== Layer table ===================================

# Translate field name to column title
array set table_titles [list \
	name "Layer" \
	qcsq "QC" depth "D $::symbol(angstrom)" \
	ro "RO $::symbol(angstrom)" mu "MU $::symbol(invangstrom)" \
        mqcsq "QM" mdepth "DM $::symbol(angstrom)" \
	mro "RM $::symbol(angstrom)" theta "TH degrees" \
]

## Which order do you want the fields in the table?
array set field_from_col {
    0 name
    1 qcsq 2 depth 3 ro 4 mu
    5 mqcsq 6 mdepth 7 mro 8 theta
}

## Reverse index the field order to retrieve the column
## number that contains a given field
foreach { col field } [array get field_from_col] {
    set col_from_field($field) $col
}

## Construct a table frame complete with scroll bars
option add *layertable.title.relief raised widgetDefault
set ::layertable $::tablebox.layertable
table $::layertable -titlerows 1 -titlecols 1 -rows 1 \
	-selectmode extended -selecttype row \
	-command { show_entry %r %c %i %s } -usecommand yes \
	-resizeborders col -roworigin -1 -colwidth 15 -colstretch unset
$::layertable tag configure title -relief raised

if {$::MAGNETIC} {
    $::layertable conf -cols 9
    set helpfields { qcsq depth ro mu mqcsq mdepth mro theta }
} else {
    $::layertable conf -cols 5
    set helpfields { qcsq depth ro mu }
}
$::layertable width 0 6
pack [scroll $::layertable] -in $::tablebox -fill both -expand yes
# proc focustable {args} { focus $::layertable }

## Set the column titles and associated help
foreach field $helpfields {
    set col $::col_from_field($field)
    label $::layertable.$field -text $::table_titles($field) \
	-fg [$::layertable tag cget title -fg] \
	-bg [$::layertable tag cget title -bg] \
	-relief [$::layertable tag cget title -relief] \
	-bd [$::layertable cget -bd] \
	-font [$::layertable cget -font]
    balloonhelp $::layertable.$field $::field_help($field)
    $::layertable window configure -1,$col \
	-window $::layertable.$field -sticky news
}
if {$::MAGNETIC} {
    image create photo orient \
	-file [file join $::MLAYER_HOME reflpolorient.gif]
    balloonhelp $::layertable.theta -compound bottom \
	-image orient $::field_help(theta)
}

## Set the colours for columns to the colours used on the graph
foreach field $::active_fields {
    $::layertable tag col $field $::col_from_field($field)
    $::layertable tag conf $field -fg $::color($field)
}

$::layertable tag conf disabled -state disabled -relief flat
$::layertable tag raise disabled


# called when the size or contents of the table may have changed
proc reset_table {} {
    if { [ $::layertable cget -rows ] != 1+$::num_layers } {
	$::layertable conf -rows [ expr 1+$::num_layers ]
    }
    # Make sure the layertable is not using cached values
    $::layertable clear cache
    # Reset the value that the user is editting
    tableentry::reset $::layertable
    ## Disable input for vacuum depth/roughness and substrate depth
    $::layertable tag cell disabled 0,$::col_from_field(depth) 0,$::col_from_field(ro)
}

# called to display a value in the table
proc show_entry { row col set value } {
    if {$set} {
	## XXX FIXME XXX should we be doing something with the value that
	## somebody is trying to set?  It seems to work if though ignore it...
	# puts "ignoring set $row,$col = <$value>"
    } else {
	if { $row < 0 } {
	    return $::table_titles($::field_from_col($col))
	} else {
	    set val [ layer $row $::field_from_col($col) ]
	    if { $col > 0 } {
		return [ fix $val 0 [expr abs($val)] $::digits ]
	    } else {
		return $val
	    }
	}
    }
}

# use an entry widget to edit the table cells
tableentry $::layertable { if { %i } { set_entry %r %c %S } else { get_entry %r %c } }

proc get_entry { row col } {
    # get the original value from the field since the entry in the table
    # may have been truncated
    return [ layer $row $::field_from_col($col) ]
}

proc set_entry { row col val } {
    # if it is an expression, then evaluate that expression
    if { [ parse_par $val from_field from_number ] } {
	set val [ layer $from_number $from_field ]
    }

    # determine which field is being updated
    set field $::field_from_col($col)

    # check that the value is good
    switch $field {
	mdepth -
	theta -
	mro -
	depth -
	ro {
	    if {![string is double $val]} {
		set ::message "number expected"
		return 0
	    } elseif {$val < 0} {
		set ::message "must be non-negative"
		return 0
	    }
	}
	mqcsq -
	qcsq -
	mu {
	    if {![string is double $val]} {
		set ::message "number expected"
		return 0
	    }
	}
	default {
	    set ::message "trying to edit a non-existant field"
	    return 0
	}
    }

    # the new value is good so save it and update things which depend on it
    set val [ layer $row $field $val ]
    update_widgets $row $field
    update_gmlayer

    set ::message {}
    return 1
}


## ================ table-based layer ops ===================
# mouse operations in the layer table need to use the new layer_{op}
# functions defined in the layer section near the top of this file.
if { 0 } {
    # find the start of the currently selected range
    proc selection_start { } {
	global table

	set stop [ $table.t cget -rows ]
	for { set i 1 } { $i < $stop } { incr i } {
	    if {[$table.t selection includes $i,1]} { return $i }
	}
	return 0
    }

    # find the end of the currently selected range
    proc selection_end { } {
	global table

	for { set i [expr [ $table.t cget -rows ]-1 ] } { $i > 0 } { incr i -1 } {
	    if {[$table.t selection includes $i,1]} { return $i }
	}
	return 0
    }

    # insert as many layers as there are rows selected
    proc insert_layers {} {
	global table

	set start [ selection_start ]
	set count [ expr [ selection_end ] - $start + 1 ]
	if { $start == 0 } {
	    set ::message "Select a layer first"
	} else {
	    ## insert after substrate
	    if { $start == 1 } { incr start }
	    $table.t insert rows -holdselection $start -$count
	    global layer_table
	    set depth [ col_from_field depth ]
	    set qcsq [ col_from_field qcsq ]
	    set mu [ col_from_field mu ]
	    set ro [ col_from_field ro ]
	    incr count $start
	    for { set i $start} { $i < $count } { incr i } {
		set layer_table($i,$depth) 10
		set layer_table($i,$qcsq) 0
		set layer_table($i,$mu) 0
		set layer_table($i,$ro) 1
	    }
	    renumber_layers
	    draw_layers
	    update_gmlayer
	}
    }

    # delete the selected rows
    proc delete_layers {} {
	global table

	set start [ selection_start ]
	set stop [ selection_end ]
	if { $start == 0 } {
	    set ::message "Select a layer first"
	} elseif { $start == 1 } {
	    set ::message "Cannot delete substrate"
	} elseif { $stop == [expr [ $table.t cget -rows ] - 1 ] } {
	    set ::message "Cannot delete vacuum"
	} else {
	    $table.t delete rows $start [expr $stop - $start + 1]
	    renumber_layers
	    draw_layers
	    update_gmlayer
	}
    }

    # copy/move the selected rows to another row
    proc move_layers {action} {
	set ::message "$action not yet implemented"
	return

	global table

	set start [ selection_start ]
	set stop [ selection_end ]
	set count [ expr $stop - $start + 1 ]
	set last [ expr [ $table.t cget -rows ] - 1 ]
	set cols [ expr [ $table.t cget -cols ] - 1 ]
	if { $start == 0 } {
	    set ::message "Select a layer first"
	} elseif { $start == 1 } {
	    set ::message "Cannot $action substrate"
	} elseif { $stop == $last } {
	    set ::message "Cannot $action vacuum"
	} else {
	    set target [ Dialog_Prompt \
		    "Destination layer number (use 0 for substrate)" ]
	    if { [ string length $target ] > 0 && $target >=0 && $target < $last } {
		set copy [ $table.t get $start,1 $stop,$cols ]
		if { $action == "move" } {
		    $table.t delete rows $start $count
		    if { $target > $stop } {
			incr target -$count
		    } elseif { $target > $start } {
			set target $start
		    }
		}
		$table.t insert rows $target $count
		tk_tablePasteHandler $table.t $target,1 $copy
		renumber_layers
	    }
	}
    }

    frame .b
    button .b.quit -text "Quit" -command exit
    button .b.insert -text "Insert" -command insert_layers
    button .b.remove -text "Remove" -command delete_layers
    button .b.move -text "Move" -command { move_layers move }
    button .b.copy -text "Copy" -command { move_layers copy }
    pack .b.quit .b.insert .b.remove .b.move .b.copy \
	    	-side left -expand true -fill x
}

# ===================== data export ======================

proc export_profile {file} {
    if { [catch [list open $file w] fid] } {
	tk_messageBox -type ok -icon error -message $fid
    } else {
	puts "# Depth"
    }
}

proc export_refl {file} {
}



# ======================= Fit/data file support =======================
# set initial layout

# XXX FIXME XXX Does datafile need to be shared? Conversely, shouldn't
# the name of the datafile be showing up on the graphs and on the screen?
set parfile $::defaultfile
set datafile ""
set directory [ pwd ]

# XXX FIXME XXX need to clean temps more often (or less).
proc clean_temps {} {
    if 0 {
	foreach file [glob -nocomplain mltmp.{e?,q?,r?,pars,d,mu,q,theta,qcsq,mqcsq,mu}] {
	    file delete $file
	}
    }
}

# open an existing parameter file
proc open_parfile {filename} {
    global parfile datafile directory
    set newdir [ file dirname $filename ]
    set newpar [ file tail $filename ]
    cd $newdir
    if { [catch {
	gmlayer pf $newpar
	gmlayer lp 
    } msg] } {
	tk_messageBox -type ok -icon error -message $msg
	return 0
    }

    set parfile $newpar
    set datafile ""
    read_pars
    clean_temps
    reset_constraints
    reset_all
    return 1
}

proc scanpar { text label name } {
    set pattern {(?:\s*[:=]\s*|\s+)["']?([-0-9.]+)['"]?[^-0-9.]}
    if {[regexp -nocase "\\W($label)$pattern" $text {} label value]} {
	if {[string is double $value]} {
	    uplevel [list set $name $value]
	    return 1
	}
    }
    return 0
}

proc scanparstr { text label name } {
    set pattern {(?:\s*[:=]\s*|\s+)["']?([^\n\r]*)['"]?\s*[\n\r]}
    if {[regexp -nocase "\\W($label)$pattern" $text {} label value]} {
	uplevel [list set $name $value]
	return 1
    }
    return 0
}

proc guess_beam_characteristics { filename } {
    # Load beam characteristics from the datafile if we can
    if { ![catch [list open $filename r] fid] } {
	# suck in data
	set data [read $fid]
	close $fid


	# Look for keywords/phrase in the header.  Words may be stuck
	# together or spaced apart.  The search is case insensitive.
	# Keyword is separated from value by spaces and possibly = or :
	# Values may be wrapped in quotes.
	# ::wl comes from "wavelength", "lambda" or "L"
	# ::dl comes from <wavelength> divergence or dispersion,
	#      delta <wavelength> or d<wavelength> where <wavelength>
	#      is any of the forms of wavelength above.
	# ::dt comes from angular or theta divergence or dispersion,
	#      delta theta or dtheta
	set wlpat "(?:wavelength|lambda|L)"
	set dlpat "(?:$wlpat\\s*di\\w*|d(?:elta)?\\s*$wlpat)"
	set dtpat "(?:(?:angular|theta)\\s*di\\w*|d(?:elta)?\\s*theta)"
	set havewl [scanpar $data $wlpat ::wl]
	set havedl [scanpar $data $dlpat ::dl]
	set havedt [scanpar $data $dtpat ::dt]

	# If these are not specified then they are defaulted from the
	# instrument, which is NG1 by default, or XRAY if wavelength<4.
	if { ![scanparstr $data {inst\w*} instrument] } {
	    if { $havewl } {
		if { $::wl < 4. } {
		    set instrument XRAY
		} else {
		    set instrument NG1
		}
	    } else {
		set instrument {}
	    }
	}
	switch -glob -- [string toupper $instrument] {
	    NG7 {
		if { !$havewl } { set ::wl 4.768 }
		if { !$havedl } { set ::dl 0.18 }
		if { !$havedt } { set ::dt 0.00001 }
	    }
	    XRAY {
		if { !$havewl } { set ::wl 1.54 }
		if { !$havedl } { set ::dl 0.001 }
		if { !$havedt } { set ::dt 0.00035 }
	    }
	    NG1* - default {
		if { !$havewl } { set ::wl 4.75 }
		if { !$havedl } { set ::dl 0.05 }
		if { !$havedt } { set ::dt 0.00001 }
	    }
	}

    }
}

# load in a new parameter file
proc new_parfile {filename} {
    # XXX FIXME XXX what if the old parameters have changed?  Should
    # we keep a change flag and warn the user?  Such a flag would allow
    # us to make sure the parameters are saved before exit.
    if { ![set_datafile $filename] } { return 0 }
    set parfile [file rootname [file tail $filename]]$::fitext
    if { [ file exists $parfile ] } {
	tk_messageBox -type ok -icon warning -message \
		"File $parfile exists; use Save as... to choose a different name"
    }
    gmlayer pf $parfile
    gmlayer of ""

    default_pars
    guess_beam_characteristics $filename
    clear_constraints
    clean_temps
    reset_all
    return 1
}

# save the current parameters to the current parameter file
proc save_parfile {} {
    if {0} {
	if { [constraints_modified] } {
	    set answer [tk_messageBox -type yesno -icon question \
		    -message "Constraints not saved. Continue?" ]
	    if { $answer == "no" } { return 0 }
	}
    }

    # XXX FIXME XXX what if constraints fail to compile?  Maybe we should
    # just save constraints to the script file and not try to compile them.
    update_constraints
    send_varying
    send_layout
    gmlayer sp
    return 1
}

# set filename as the new parameter file, and save the current parameters to it
proc rename_parfile {filename} {
    # XXX FIXME XXX - make sure that the directory didn't change
    set ::parfile [ file tail $filename ]
    gmlayer pf $::parfile
    save_parfile
}

# set filename as the new datafile
proc set_datafile {filename} {
    set newdir [ file dirname $filename ]
    cd $newdir
    set base [ file tail $filename ]
    if { $::MAGNETIC } {
	set tail [string index $base end]
	set base [string range $base 0 end-1]
	set files [glob -nocomplain "$base\[abcd]"]
	if { [llength $files] == 0 } {
	    set files [glob -nocomplain "$base\[ABCD]"]
	    if { [llength $files] == 0 } {
		set files [glob -nocomplain "$base$tail\[abcd]"]
		if { [llength $files] == 0 } {
		    set files [glob -nocomplain "$base$tail\[ABCD]"]
		    if { [llength $files] == 0 } {
			tk_messageBox -type ok -icon error -message \
				"Could not open $filename for [abcd] or [ABCD]"
			return 0
		    }
		}
	    }
	}
	set ps {}
	foreach f $files { set ps $ps[string tolower [string index $f end]] }
	gmlayer ps $ps
    }

    set oldfile [gmlayer send datafile]
    gmlayer if $base
    if { [catch { gmlayer gd } msg] } {
	# restore old file
	gmlayer if $oldfile
	if { $oldfile ne "" } { gmlayer gd }
	tk_messageBox -type ok -icon error -message $msg
	return 0
    }

    cd $newdir
    focus_beambox
    return 1
}

# =========================== Menu ===============================

menu .menu
. config -menu .menu

menu .menu.file
menu .menu.file.export
.menu add cascade -underline 0 -label File -menu .menu.file
.menu.file add command -underline 0 -label "New..."        \
    -command { request_new }
.menu.file add command -underline 0 -label "Open..."       \
    -command { request_open }
.menu.file add command -underline 0 -label "Save"          \
    -command { save_parfile }
.menu.file add command -underline 5 -label "Save as..."    \
    -command { request_saveas }
.menu.file add command -underline 0 -label "Data..."       \
    -command { request_data }
.menu.file add cascade -underline 0 -label "Export..." \
    -menu .menu.file.export
.menu.file add command -underline 10 -label "Save and exit" \
    -command { if { [ save_parfile ] } { gmlayer quit; exit } }
.menu.file add command -underline 0 -label "Quit without saving" \
    -command { exit }
.menu.file.export add command -underline 0 -label "Profile..." \
    -command { request_export_profile }
.menu.file.export add command -underline 0 -label "Reflectivity..." \
    -command { request_export_refl }


menu .menu.layer
.menu add cascade -underline 0 -label Layer -menu .menu.layer
.menu.layer add command -underline 0 -label "Insert..."    \
    -command { raise .insert; .insert draw }
.menu.layer add command -underline 0 -label "Delete..."    \
    -command { raise .delete; .delete draw }
.menu.layer add command -underline 0 -label "Copy..."      \
    -command { raise .copy; .copy draw }
.menu.layer add command -underline 0 -label "Move..."      \
    -command { raise .move; .move draw }
.menu.layer add command -underline 0 -label "Overwrite..." \
    -command { raise .overwrite; .overwrite draw }
.menu.layer add separator
.menu.layer add command -underline 0 -label "Repeat..." \
    -command {
	if { !$::MAGNETIC } { set ::layerop_repeat $::nrepeat }
	raise .repeat; .repeat draw
    }
.menu.layer add separator
.menu.layer add command -underline 3 -label "Roughness..." \
    -command {
	set ::layerop_repeat $::nrough
	raise .roughness; .roughness draw
    }

menu .menu.options
.menu add cascade -underline 0 -label Options -menu .menu.options
.menu.options add radiobutton -underline 0 -label "Nb units" \
    -variable ::use_sld -value 1 -command set_sld
.menu.options add radiobutton -underline 0 -label "16$::symbol(pi) Nb units" \
    -variable ::use_sld -value 0 -command set_sld
.menu.options add separator
.menu.options add radiobutton -underline 2 -label "R*Q^4" \
    -variable ::use_Q4 -value 1 -command set_Q4
.menu.options add radiobutton -underline 0 -label "R" \
    -variable ::use_Q4 -value 0 -command set_Q4
.menu.options add separator
.menu.options add command -underline 0 -label "Tcl console" \
    -command { start_tkcon }
if { [package_available tablelist] } {
    .menu.options add command -underline 0 -label "Browse widgets" \
	-command { start_widget_browser }
}

helpmenu .menu introduction

proc set_sld_labels {} {
    if { $::use_sld } {
	if { $::MAGNETIC} {
	    .layers axis conf mqcsq -title "QM Nb"
	    .layers axis conf qcsq -title "QC Nb"
	} else {
	    .layers axis conf qcsq -title "Nb"
	}
	array set ::table_titles { qcsq "QC Nb" mqcsq "QM Nb" }
    } else {
	if { $::MAGNETIC} {
	    .layers axis conf mqcsq -title "QM 16$::symbol(pi) Nb"
	    .layers axis conf qcsq -title "QC 16$::symbol(pi) Nb"
	} else {
	    .layers axis conf qcsq -title "16$::symbol(pi) Nb"
	}
	array set ::table_titles [list qcsq "QC 16$::symbol(pi) Nb" mqcsq "QM 16$::symbol(pi) Nb" ]
    }
}
set_sld_labels

proc set_sld {} {
    set_sld_labels
    read_pars
    reset_all
}

proc set_Q4 {} {
    # XXX FIXME XXX This doesn't update the snapshots
    if { $::use_Q4 } {
        .reflectivity axis conf y -title "reflectivity * Q^4"
    } else {
        .reflectivity axis conf y -title "reflectivity"
    }
    read_data
    read_reflectivity
}

#=== File menu
proc request_new {} {
    default_pars
    set filename [ tk_getOpenFile -title "Reflectivity data" \
	    -filetypes [list [list {Data Files} $::dataglob] \
		             [list {All Files} *]] ]
    if { $filename != "" } { new_parfile $filename }
}

proc request_open {} {
    set filename [ tk_getOpenFile -title "Reflectivity fit" \
	    -filetypes [list $::fitfiles $::allfiles] ]
    if { $filename != "" } { open_parfile $filename }
}

proc request_saveas {} {
    set filename [ tk_getSaveFile -defaultextension $::fitext \
	    -title "Reflectivity fit" ]
##	    -filetypes [list $::fitfiles $::allfiles] ]
    if { $filename != "" } { rename_parfile $filename }
}

proc request_data {} {
    set filename [ tk_getOpenFile -title "Reflectivity data" \
	    -filetypes [list $::datafiles $::allfiles] ]
    if { $filename != "" } {
	if { [set_datafile $filename] } { read_data; working_files }
    }
}

proc request_export_profile {} {
    tk_messageBox -type ok -icon error -message "Not yet implemented --- use the SLP command directly"
    return
    set filename [ tk_getSaveFile -defaultextension .pro \
	    -title "Export layer profile"]
    if { $filename != "" } { export_profile $filename }
}

proc request_export_refl {} {
    tk_messageBox -type ok -icon error -message "Not yet implemented --- use the SRF command directly"
    return
    set filename [ tk_getSaveFile -defaultextension .fit \
	    -title "Export reflectivity"]
    if { $filename != "" } { export_refl $filename }
}



#=== Layer menu

# XXX FIXME XXX Can we replace the layer operations dialogs with
# mouse clicks in the layer table notebook?  E.g.,
#    Left click and drag to select a region
#    Right click to clear a selection
#    Left click and drag on a selection to move the selection
#    Insert button to open blank lines under the selection
#    Delete button to remove the lines under the selection
#    Copy button to duplicate the lines under the selection
#    Repeat button to flag the lines in the selection as repeating
#    Repeat count input field.

# process the Roughness layers... menu dialog
proc layer_roughness { v } {
    if { [ string is integer $v ] } {
	if { $v > 2 } { set ::nrough $v; return 1 }
    }
    tk_messageBox -message "Roughness steps must be > 2" -type ok
    return 0
}

# process the Repeat... menu dialog
proc layer_repeat { v } {
    if { [ string is integer $v ] } {
	if { $v > 0 } { set ::nrepeat $v; return 1 }
    }
    tk_messageBox -message "Repeats must be a positive integer" -type ok
    return 0
}

# variables for the various layer forms
set layerop_id {}
set layerop_dest {}
set layerop_d 10.0
set layerop_mu 0.0
set layerop_qcsq 0.0
set layerop_ro 1.0
set layerop_md 10.0
set layerop_theta 0.0
set layerop_mqcsq 0.0
set layerop_mro 1.0
set layerop_repeat 1

# command to build the layer forms
proc make_layerops {} {
    # Table driven input form with Ok/Cancel buttons
    #    form ::= { name { field field ... } }
    #    field ::= { type variable label [units] }
    # "$Name Layer" is the label on top of the form.
    # When the Ok button is pressed the command
    #    layer_$name v1 v2 v3 ...
    # is evaluated, where v1, v2, v3, etc., are the variables
    # associated with the fields in the field list.
    # WARNING!!! This means the order of the fields on the form
    # must match the order of the arguments to the function.
    set from [list string layerop_id "From layer" ]
    set to   [list string layerop_dest "To layer" ]
    set delete [list delete [list \
	    { string layerop_id "Delete layer" } ] ]
    set copy   [list copy   [list $from $to ] ]
    set move   [list move   [list $from $to ] ]
    set overwrite [list overwrite [list $from $to ] ]
    set insert [list insert [list \
	    { string layerop_id "Insert layer" } \
	    { real layerop_qcsq "Qc^2" "inv Angstroms^2" } \
	    { real layerop_mu "Mu" "inv Angstroms^2" } \
	    { real layerop_ro "Roughness" "Angstroms" } \
	    { real layerop_d "layer depth" "Angstroms" } ]]
    if { $::MAGNETIC } {
	set insert [ list insert [concat [lindex $insert 1] [ list \
		{ real layerop_mqcsq "Qm^2" "inv Angstroms^2" } \
		{ real layerop_theta "Theta" "degrees" } \
		{ real layerop_mro "Magnetic roughness" "Angstroms" } \
		{ real layerop_md "Magnetic layer depth" "Angstroms" } ]]]
    }
    if { $::MAGNETIC } {
	set repeat [list lattice [list \
		{ real layerop_id "Start layer" } \
		{ real layerop_dest "End layer" } \
		{ real layerop_repeat "Number of copies" } ]]
    } else {
	set repeat [list repeat [list \
		{ real layerop_repeat "Number of middle section repeats" } ]]
    }
    set roughness [list roughness [list \
	    { real layerop_repeat "Number of roughness steps" "must be >2" } ]]

    # Build the forms and attach the controls
    foreach op [list $insert $delete $copy $move $overwrite $repeat $roughness ] {
	foreach { name fieldlist } $op {}
# XXX FIXME XXX Don't want modal dialogs if we are doing a bunch of ops
	Dialog .$name -default 0 -cancel 1 -anchor c -modal local \
	    -separator 1 -side bottom -title "[string toupper $name 0 0] Layer"
	addfields [ .$name getframe ] $fieldlist
	set command layer_$name
	foreach f $fieldlist { set command "$command $[lindex $f 1]" }
# XXX FIXME XXX Disable the action button until reset_all is complete since
# it takes a while on busy layouts; better yet don't do reset until the
# dialog is finished closing.
	set command "if { \[ $command ] } { .$name enddialog 0; reset_all }"
	.$name add -text Ok -command $command
	.$name add -text Cancel
	# Hide rather than destroy the dialog when user closes the window
	wm protocol .$name WM_DELETE_WINDOW ".$name withdraw"
    }
}
make_layerops

# ========================= screen layout ===========================

# pack the toplevel widgets
$notebook compute_size
$notebook raise [$notebook page 0]
pack $notebook -fill both -expand yes

# status message dialog
set ::message {}
label .message -relief ridge -anchor w -textvariable ::message

# Can't register the geometry in the resource database
# directly so use a fake resource instead.  I'm sure
# some will be unhappy.  Use ++ to open maximized.
# XXX FIXME XXX maximize doesn't work on unix
set geom [option get . mainGeometry MainGeometry]
if { $geom eq "++" } {
    if { [catch { wm state . zoomed }] } {
	wm geometry . [join [wm maxsize .] x]+0+0
    }
} else {
    wm geometry . $geom
}

grid $panes -sticky news
grid .message -sticky ew
grid rowconf . 0 -weight 1
grid columnconf . 0 -weight 1

# add the window title
wm title . $::title

# close interface to gmlayer when application exits
bind . <Destroy> { if {"%W" == "."} { close_gmlayer } }


# ========================= console controls ==========================

# movie field min max frames
#     - display a movie showing field varying from min to max in n steps
#
# Use the underlying field name as shown on the fit page rather than
# the GUI field names.
proc movie {field min max frames} {
    set step [expr ($max - $min)/($frames-1)]
    for {set i 0} { $i < $frames } { incr i } {
	gmlayer $field $min
	read_profile
	read_reflectivity
	set min [expr $min + $step]
        update
    }
}


# e.g. 
#  chisqplot d2 100 150 20
# 
proc chisqplot {field min max frames} {
    vector create ::scan_p
    vector create ::scan_chi
    ::scan_p delete :
    ::scan_chi delete :
    if { [winfo exists .scan] } {
	raise .scan
    } else {
	toplevel .scan
	pack [graph .scan.graph] -fill both -expand yes
	active_graph .scan.graph
	.scan.graph elem create scan -xdata ::scan_p -ydata ::scan_chi
	.scan.graph legend conf -hide 1
	blt::ClosestPoint .scan.graph
    }
    .scan.graph conf -title "Scan of parameter $field"
    .scan.graph axis conf y -title "Chi^2"
    .scan.graph axis conf x -title $field

    set step [vector expr "($max - $min)/($frames-1)"]
    for {set i 0} { $i < $frames } { incr i } {
	gmlayer $field $min
	# XXX FIXME XXX shouldn't need to read reflectivity
	# instead, the send chisq command should recognize
	# that the parameters have changed, and recalculate
	# the reflectivity as appropriate.
	read_reflectivity
	::scan_p append $min
	::scan_chi append [gmlayer send chisq]
	set min [expr $min + $step]
        update
    }
    
}


# ========================= startup/refresh ===========================

# respond to a significant change (e.g., add/delete/move layer,
# grab new data set/parameter file)
proc reset_all {} {
    # XXX FIXME XXX check all uses of reset_all; not everything is being
    # reset that may need it, and somethings are being reset that don't
    # need to be
    read_data
    # send_fresnel
    # read_reflectivity
    # ::reflect_q dup ::fresnel_q
    # ::reflect_r dup ::fresnel_r
    draw_layers
    send_layout
    read_profile
    read_reflectivity
    reset_table
    reset_varying
    working_files
}

## open the initial file
proc drop_file { file } {
    if { $file == "" } { return }

    ## Trim uri indicator if any
    ## XXX FIXME XXX maybe allow drag/drop links from browser?
    regsub {^file:} [lindex $file 0] {} file

    ## Try to guess if it is a staj file.  To be a staj file, it must
    ## exist and it must contain something other than numbers and comments.
    if { [catch [list open $file r] fid] } { 
	tk_messageBox -type ok -icon error -message $fid
	return
    }

    # suck in data
    set data [read $fid]
    close $fid
    # strip comment lines
    regsub -all -line "\[#].*$" $data {} data
    # see if the rest is only numbers by reading it into a blt vector
    set data [string map { "\n" " " } $data]
    blt::vector dummy
    if { [catch { dummy set $data } valuelist] } {
	open_parfile $file
    } else {
	if { [set_datafile $file] } {
            read_data
            working_files
        }
    }
    blt::vector destroy dummy
}

catch { dnd bindtarget .reflectivity Files <Drop> {drop_file  %D} }

# XXX FIXME XXX context sensitive help may not
# be defined correctly if the help pages are
# attached to widgets named in variables whose
# variables haven't been defined yet.
# XXX FIXME XXX no help for the initial file
# selection dialog.
if {$::MAGNETIC} {
    help $::MLAYER_HOME reflfit help gj2
} else {
    help $::MLAYER_HOME reflfit help mlayer
}

# ====================== Initial file dialog ======================
# if just asking how to use the program, then tell them.
# if they actually supply a parameter file, then grab its
# name, otherwise ask for the parameter file, defaulting
# to $::defaultfile if it exists.  Don't worry if the file is
# incorrect at this point: let the expect program deal with
# that when it starts up mlayer.
proc start_file {} {
    if { $::argc == 1 } {
        set arg [lindex $::argv 0]
        if { [file exists $arg] } {
            set initfile $arg
        } elseif { [file exists $arg$fitext] } {
            set initfile $arg$fitext
        } elseif { !$::MAGNETIC && [file exists $arg.refl] } {
            set initfile $arg.refl
        } elseif { $::MAGNETIC && \
                [llength [set f [glob -nocomplain "$arg\[abcdABCD]"]]] > 0 } {
            set initfile [lindex [lsort $f] 0]
        } else {
            # We could fail here, or we can let guess_init take care of it.
            set initfile $arg
            # app_fail "file $argv does not exist"
        }
    } elseif { $::argc == 0 } {
	return {} ;# For now, lets try starting empty
        if { [file exists [set initfile $::defaultfile]] } {
            # mlayer.staj exists"
            set filetypes [list $::fitfiles $::datafiles $::allfiles]
        } elseif { [llength [set initfile [glob -nocomplain $::fitglob]]] > 0 } {
            # mlayer.staj doesn't exist, but there are other .staj files
            set filetypes [list $::fitfiles $::datafiles $::allfiles]
        } elseif { [llength [set initfile [glob -nocomplain $::dataglob]]] > 0 } {
            # no .staj files, but there are some data files
            set filetypes [list $::datafiles $::fitfiles $::allfiles]
        } else {
            # neither .staj nor .log, so start without any file
            # (user might change to another directory though)
            set initfile ""
            set filetypes [list $::allfiles $::fitfiles $::datafiles]
        }
        if { [llength $initfile] != 1 } { set initfile "" }
        set initfile [ tk_getOpenFile -initialfile $initfile \
		       -title "$::title open" \
		       -filetypes $filetypes]

        ## if no input file, might just want to play with lineshapes
        # if { $initfile == "" } { exit }
    } else {
	# XXX FIXME XXX what shall we do with too many start args?
        return {}
    }
    return [list $initfile]
}

# generate a default layout
default_pars
gmlayer ql "0 0.35"
gmlayer np 100
reset_all

drop_file [start_file]
focus .

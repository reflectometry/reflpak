
namespace eval ::Choose:: {
    variable Path ""
    variable Index
    variable Callback puts
}

proc ::Choose::Sort_contents { w column } {
    set old [$w sort cget -column]
    set decreasing 0
    if { "$column" == "$old" } {
	set decreasing [$w sort cget -decreasing]
	set decreasing [expr !$decreasing]
    }
    $w sort configure -decreasing $decreasing -column $column -mode integer
    $w configure -flat yes
    $w sort auto yes

    blt::busy hold $w
    update
    blt::busy release $w
}

proc ::Choose::Fill_contents { w path } {

#    puts "Content fill $::Choose::Path $path"

    set n 0
    if { "$path" == ".." } {
	set dirs [list [incr n] -data { Dataset Parent Comment directory}]
    } else {
	set dirs ""
    }

    # Scan the current directory, recording all data sets
    set other 0
    set all 0
    foreach f [glob -nocomplain [file join $::Choose::Path $path *]] {
	if { [file isdirectory $f] } {
	    if { $path ne "." && $path ne ".." } {
		lappend dirs [incr n] \
		    -data [list Dataset [file tail $f]/ Comment directory]
	    }
	    continue
	}

	incr all

	# XXX FIXME XXX need to be able to add new types 
	# XXX FIXME XXX should use pattern matching
	switch [string tolower [file extension $f]] {
	    .ng1 { set type CG-1 }
	    .ng1 { set type NG-1 }
	    .xr0 { set type XRAY }
	    .ng7 { set type NG-7 }
	    .na1 -
	    .nb1 -
	    .nc1 -
	    .nd1 { set type NG-1p }
	    default { 
	        incr other
		continue
		# XXX FIXME XXX perhaps we only want dataset###.ext files?
	    }
	}

	set item "[string range $f 0 end-7],$type"
	if { ![info exists count($item)] } {
	    set count($item) 1
	    set tmin($item) $f
	    set tmax($item) $f
	} else {
	    incr count($item)
	    if { "$f" > "$tmax($item)" } {
		set tmax($item) $f
	    } elseif { "$f" < "$tmin($item)" } {
		set tmin($item) $f
	    }
	}

    }

    # Construct the selection table
    foreach item [lsort [array names count]] {
	foreach {dataset type} [split $item ,] {}
	if [catch {open $tmin($item)} fid] {
	    set start ????
	    set comment ????
	} else {
	    if [catch {clock format [clock_scan [lindex [split [gets $fid] "'"] 3]] -format %Y-%m-%d } start] {
		set start ????
	    }
	    # icp stores the comment as the second line of the file
	    gets $fid
	    set comment [gets $fid]
	    close $fid
	}
	if [catch {open $tmax($item)} fid] {
	    set end ????
	} else {
	    if [catch {clock format [clock_scan [lindex [split [gets $fid] "'"] 3]] -format %Y-%m-%d } end] {
		set end ????
	    }
	    close $fid
	}
	lappend dirs [incr n] -data [list \
	    Dataset [file tail $dataset] Inst $type #Runs $count($item) \
	    Start $start End $end Path $path Comment $comment]
    }
    lappend dirs [incr n] -data [list \
	    Dataset All Inst {} #Runs $all Start {} End {} \
	    Path $path Comment "$other unrecognized files"]

    # Display the selection table
    $w delete 0 0 end
    eval $w insert end $dirs


    # "sort auto" appears to be broken
    .choose.contents sort conf -decreasing [.choose.contents sort cget -decreasing]
}

proc ::Choose::Fill_path { path } {
    # make pathname absolute
    # XXX FIXME XXX need to simulate bash-like cd/pwd so that
    # cd symlink ; cd .. returns to the current directory, not
    # to the hardlink parent of the 
    set old [pwd]
    cd [file join $::Choose::Path $path]
    set path [pwd]
    cd $old

    # remember what path we are using
    set ::Choose::Path $path

    if {0} {
	# Check if path is already in the menu
	set last [.choose.parent.menu index end]
	if { "$last" == "none" } { set last -1 }
	set found 0
	for {set idx 0} {$idx <= $last} { incr idx} {
	    if { "[.choose.parent.menu entrycget $idx -label]" == "$path" } {
		set found 1
		break
	    }
	}

	# Build leading directories portion
	if { $found == 0 } {
	    set parts [file split $path]
	    set whole ""
	    .choose.parent.menu delete 0 end
	    foreach part [file split $path] {
		set whole [file join $whole $part]
		.choose.parent.menu add command -label $whole \
			-command [list ::Choose::Fill_path $whole]
	    }
	}
	.choose.parent conf -text $path
    }

    # find all subdirectories
    set dirs [list . ..]
    foreach item [lsort -dictionary [ glob -nocomplain [file join $path *] ]] {
	if { [file isdirectory $item] } {
	    lappend dirs [file tail $item]
	}
    }

    # refill the listbox
    .choose.children delete 0 end
    eval .choose.children insert end $dirs

    # set the selection
    # XXX FIXME XXX it would be nice if going into the parent would
    # leave you on the entry for the child.
    if { ![info exists ::Choose::Index($path)] } {
#	if { [.choose.children size] < 3  } {
	    set ::Choose::Index($path) 0
#	} else {
#	    set ::Choose::Index($path) 2
#	}
    }
    .choose.children selection set $::Choose::Index($path)
    .choose.children activate $::Choose::Index($path)
    .choose.children see $::Choose::Index($path)
    ::Choose::Fill_contents .choose.contents [::Choose::Selected_dir]
}

proc ::Choose::Selected_dir {} {
    return [.choose.children get [.choose.children curselection]]
}

proc ::Choose::Selected_set {} {
    # XXX FIXME XXX allow multiple selection --- I believe the returned
    set patternset {}
    foreach item [.choose.contents curselection] {
	array set rec [.choose.contents entry cget $item -data]
	# XXX FIXME XXX use a mapper so that we can add new extensions
	# on the fly
        switch $rec(Inst) {
	    NG-1 { lappend patternset $rec(Dataset)*.\[nN]\[gG]1 }
	    XRAY { lappend patternset $rec(Dataset)*.\[xX]\[rR]0 }
	    NG-7 { lappend patternset $rec(Dataset)*.\[nN]\[gG]7 }
	    NG-1p { lappend patternset $rec(Dataset)*.\[nN]\[aAbBcCdD]1 }
	    default { return * ;# All, so return all }
	}
    }
    return $patternset
}


proc ::Choose::Update {} {
    set dir [file join $::Choose::Path [Selected_dir]]
    set patternset {}
    foreach pattern [Selected_set] {
	lappend patternset [file join $dir $pattern]
    }
    if ![llength $patternset] { file join $dir * }
    $::Choose::Callback $patternset
}

proc  choose_dataset { callback } {
    set ::Choose::Callback $callback

    # If we've already have a window we don't need another
    if { [winfo exists .choose] } {
	wm deiconify .choose
	raise .choose
	focus .choose.children
	return
    }

    # Create a new toplevel window
    toplevel .choose
    wm geometry .choose 600x400
    set panes [ PanedWindow .choose.panes -side top ]
    set pathbox [ $panes add -weight 0 -minsize 80 ]
    set contentbox [ $panes add -weight 1 ]
    sashconf $panes

    # multicolumn sortable table to show the contents of a data directory
    hiertable .choose.contents
    .choose.contents configure -selectmode multiple
    .choose.contents column insert end Path Dataset Inst #Runs Start End Comment
    .choose.contents column configure treeView -hide 1
    .choose.contents column configure Path -hide 1
    foreach column [.choose.contents column names] {
	.choose.contents column configure $column -justify left -width 0 \
		-relief raised \
		-command [list ::Choose::Sort_contents .choose.contents $column]
    }
    .choose.contents column conf #Runs -justify right

    # pack the contents in a able window
    pack [scroll .choose.contents] -in $contentbox -fill both -expand yes

    if { 0 } {
	# fixed list choice menu for ancestors of current directory
	# filled by Fill_path
	menubutton .choose.parent -indicatoron 1 -menu .choose.parent.menu -bd 2 \
		-relief raised -highlightthickness 1 -anchor c -direction flush
	menu .choose.parent.menu -tearoff 0
	pack .choose.parent -in $pathbox -anchor w
    }

    # children of current directory
    # label $pathbox.childrenlabel -text Directory
#    pack $pathbox.childrenlabel -side bottom

    listbox .choose.children -selectmode browse -exportselection no


    pack [scroll .choose.children] -in $pathbox -fill both -expand yes

    if { $::have_archive } {
	button $pathbox.archive -text Archive -command { ::Choose::Fill_path /archive }
	grid $pathbox.archive -
    }

    ::Choose::Fill_path .

    # XXX FIXME XXX do we want { wm withdraw .choose } or { destroy .choose }

    # button controls
    frame .choose.b
    button .choose.b.apply -text Apply -command ::Choose::Update
    button .choose.b.okay -text Ok \
	    -command { wm withdraw .choose; ::Choose::Update; destroy .choose }
    button .choose.b.cancel -text Cancel -command { destroy .choose }
    grid .choose.b.apply .choose.b.okay .choose.b.cancel -padx 3 -sticky ew
    grid columnconfigure .choose.b { 0 1 2 } -uniform a

    # keyboard control
    foreach w .choose  {
	bind $w <Escape> { destroy .choose }
	bind $w <Return> { ::Choose::Update }
    }

    bind .choose.children <Double-1> {
	::Choose::Fill_path [::Choose::Selected_dir]
    }
    bind .choose.children <Right> {
	::Choose::Fill_path [.choose.children get active]
    }
    bind .choose.children <Left> {
	::Choose::Fill_path ..
    }
    bind .choose.children <<ListboxSelect>> {
	::Choose::Fill_contents .choose.contents [::Choose::Selected_dir]
	focus .choose.children
	set ::Choose::Index($::Choose::Path) [.choose.children curselection]
    }

    # Place to enter the entire path directly
    set entrybox [frame .choose.entrybox]
    button $entrybox.browse -image [Bitmap::get open] -command {
	set dir [tk_chooseDirectory -initialdir $::Choose::Path \
		     -parent .choose -title Directory -mustexist true ]
	if { $dir ne "" } { ::Choose::Fill_path $dir }
    }
    entry $entrybox.entry -textvariable ::Choose::Path
    bind $entrybox.entry <Return> { ::Choose::Fill_path $::Choose::Path ; break }
    label $entrybox.label -text "Directory"
    grid $entrybox.label $entrybox.entry $entrybox.browse -sticky ew
    grid columnconf $entrybox 1 -weight 1

    # final packing
    grid $entrybox -sticky ew -pady {3 10}
    grid .choose.panes - -sticky news
    grid .choose.b - -sticky e
    grid rowconf .choose 1 -weight 1
    grid columnconf .choose 0 -weight 1
    if { 0 } {
	grid .choose.parent -sticky w
    }

    # put the cursor in the right place
    focus .choose.children
}


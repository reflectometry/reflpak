# Based on code from http://mini.net/tcl/ALittleHypertextSystem
# by Richard Suchenwirth
#
# From http://mini.net/tcl/4381 on 2003-01-22:
#
#    All code marked with RS or Richard Suchenwirth is definitely 
#    free as can be - do what you wish, just don't blame me ;-)
#
# Here's a simple hypertext system that you might use for online 
# help. It exports two commands: 
#
#  hpage (title) (widgetlist) (text) 
#     Register a hypertext page's title and text body, attaching it to
#     the possibly empty list of widgets
#  htext (widget) ?title? ?rest?
#     Bring up a toplevel showing the specified page, or an alphabetic
#     list of titles if not specified.  
#
# Hypertext pages are in a subset of Wiki format: 
#
#      indented lines come in fixed font without evaluation; 
#      blank lines break paragraphs 
#      all lines without leading blanks are displayed as a paragraph
#      if the first character of the paragraph is >, quote the paragraph
#      if the first character of the paragraph is #, it is a comment
#      a link is the title of another page in brackets (see examples at end). 
#
# Links are displayed underlined and blue (or purple if they have been 
# visited before), and change the cursor to a pointing hand. Clicking on 
# a link of course brings up that page. In addition, you get "Index", 
# "Search" (case-insensitive regexp in titles and full text), "History", 
# and "Back" links at the bottom of pages. In a nutshell, you get a tiny 
# browser, an information server, and a search engine ;-) 
#
# Support for context sensitive help.  If title is a widget then search 
# up the widget heirarchy for the first attached page.  That way you can 
# "bind all <F1> { htext .htext %W}" to get help on each widget, 
# defaulting to the closest containing widget if there is no specific
# help for the widget.
#
# Support for different types of context sensitive help.  If title is a
# widget and further parameters are specified, it again searches for the
# page attached to the closest containing widget.  Before displaying that
# page, it first checks for the page name followed by the remaining
# arguments, returning the attached page if the extended name does not
# exist.  E.g., you can "bind all <Shift-F1> {htext .htext %W controls}" 
# to raise "profile controls" rather than "profile", assuming you attach
# .profile to the "profile" page and supply a "profile controls" page.
# If there is no specific controls info for this page, then the normal
# page help is displayed even if you press Shift-F1 to get it.

# Extended by Paul Kienzle to support context sensitive help, as well as
# links within preformatted text, and miscellaneous other changes.

# XXX FIXME XXX consider shifting the attachments code out of hpage/htext
# so that code is closer to the original.

# XXX FIXME XXX need to drop grabs when entering the help window and
# release them on leaving.

namespace eval htext {
    namespace export hpage htext

    variable texttagoptions
    set texttagoptions {
	background Background
	bgstipple Bgstipple
	borderWidth BorderWidth
	elide Elide
	fgstipple Fgstipple
	font Font
	foreground Foreground
	justify Justify
	lMargin1 Margin
	lMargin2 Margin
	offset Offset
	overstrike Overstrike
	relief Relief
	rMargin Margin
	spacing1 Spacing
	spacing2 Spacing
	spacing3 Spacing
	tabs Tabs
	underline Underline
	wrap Wrap
    }

    # Labouriously check the resource file for tag options
    proc texttagoption { w tag } {
	variable texttagoptions
	foreach { name class } $texttagoptions {
	    set opt [option get $w $tag-$name $tag-$class]
	    if { [llength $opt] == 0 } { 
		set opt [option get $w Tag-$name Tag-$class ] 
	    }
	    if { [llength $opt] > 0 } {
		$w tag configure $tag -[string tolower $name] $opt
	    }
	}
    }

    variable pages
    variable attachments
    variable history {} seen {}
    proc hpage {title widget {body {}}} {
        variable pages 
	variable attachments
	if [string length $body] {
	    set pages($title) $body
	    foreach w $widget {	set attachments($w) $title }
	} else {
	    set pages($title) $widget
	}
    }
    proc htext {w args} {
        if ![winfo exists $w] {
            wm title [toplevel $w] Help

            text $w.t -border 5 -relief flat -wrap word -state disabled \
                      -yscrollcommand "$w.s set"
            scrollbar $w.s -orient vert -command "$w.t yview"
	    grid $w.t $w.s -sticky news
	    grid columnconf $w 0 -weight 1
	    grid rowconf $w 0 -weight 1
            $w.t tag config link -foreground blue -underline 1
            $w.t tag config seen -foreground purple4 -underline 1
            $w.t tag bind link <Enter> "$w.t config -cursor hand2"
            $w.t tag bind link <Leave> "$w.t config -cursor {}"
            $w.t tag bind link <1> "[namespace current]::click $w.t %x %y"
            $w.t tag config hdr -font {Times -16}
            $w.t tag config fix -font {Courier -12} -wrap none
	    $w.t tag config quote -lmargin1 5m -lmargin2 5m -rmargin 5
	    texttagoption $w.t link
	    texttagoption $w.t seen
	    texttagoption $w.t hdr
	    texttagoption $w.t fix
	    texttagoption $w.t quote
	    bind $w <Escape> "wm withdraw $w"
	    wm protocol $w WM_DELETE_WINDOW "wm withdraw $w"
	    bind $w <Destroy> { }
        }
	wm deiconify $w
        raise $w
	focus $w.t
	# XXX FIXME XXX ugly hack to allow us to get help while dialogs are displayed
	# unfortunately, this releases the grab; I tried restore the grab when done
	# but it got messy fast --- best solution is don't grab.
	grab release [grab current $w]
        variable pages 
	variable attachments
	# load page immediately if it is recognized
	if {[info exists pages($args)] || $args eq "Search"} {
	    show $w.t $args
	    return
	}

	# assume we have {widget options}, and look up the
	# corresponding page title for widget
	set at [lindex $args 0]
	set rest [lrange $args 1 end]
	while [winfo exists $at] {
	    if [info exists attachments($at)] {
		set page "$attachments($at) $rest"
		if [info exists pages($page)] {
		    show $w.t $page
		} else {
		    show $w.t $attachments($at)
		}
		return
	    } else {
		set at [winfo parent $at]
	    }
	}

	# no page of that name so use Index
        show $w.t Index
    }
    proc click {w x y} {
	set range [$w tag prevrange link "[$w index @$x,$y] + 1 char"]
        if [llength $range] {show $w [eval $w get $range]}
    }
    proc back w {
        variable history
        set l [llength $history]
        set last [lindex $history [expr $l-2]]
        set history [lrange $history 0 [expr $l-3]]
        show $w $last
    }
    proc listpage {w list} {
        foreach i $list {$w insert end \n; showlink $w $i}
    }
    proc search w {
        $w insert end "\nSearch phrase:  "
        entry $w.e -textvar [namespace current]::search
        $w window create end -window $w.e
#        focus $w.e
        $w.e select range 0 end
        bind $w.e <Return> "htext::dosearch $w"
        button $w.b -text Search! -command "htext::dosearch $w" -pady 0
        $w window create end -window $w.b
    }
    proc dosearch w {
        variable search
        variable pages
        $w config -state normal
        $w insert end "\n\nSearch results for '$search':\n"
        foreach i [lsort -dictionary [array names pages]] {
            if [regexp -nocase $search $i] {
                $w insert end \n; showlink $w $i ;# found in title
            } elseif [regexp -nocase -indices -- $search $pages($i) pos] {
                regsub -all \n [string range $pages($i) \
                    [expr [lindex $pos 0]-20] [expr [lindex $pos 1]+20]] \
                        " " context
                $w insert end \n
                showlink $w $i
                $w insert end " - ...$context..."
            }
        }
        $w config -state disabled
    }
    proc showlink {w link} {
	if {[string match img::* $link]} {
	    # XXX FIXME XXX turn photodir into photopath
	    # XXX FIXME XXX catch image create errors and
	    # replace them with broken link symbols.
	    variable photodir
	    variable photo
	    set file [string range $link 5 end]
	    if { ![info exists photo($file)] } {
		set photo($file) \
			[image create photo -file [file join $photodir $file]]
	    }
	    $w image create end -image $photo($file)
	} else {
	    variable seen
	    set tag link
	    if {[lsearch -exact $seen $link]>-1} {
		lappend tag seen
	    }
	    $w insert end $link $tag
	}
    }
    proc map_escaped_brackets { s } { string map { \\[ \001 \\] \002 } $s }
    proc unmap_escaped_brackets { s } { string map { \001 [ \002 ] } $s }
    proc formattext { w title } {
        variable pages
	set var 1
	set tag {}
	
	foreach i [split $pages($title) \n] {
	    if [regexp {^[ \t]+[^ \t]} $i] {
		if $var {$w insert end \n}
		set var 0
		## uncomment the following if brackets in
		## preformatted text do not need to be escaped
		# $w insert end $i\n fix
		# continue
		set tag fix
	    } else {
		set i [string trim $i]
		if ![string length $i] {
		    if $var {
			$w insert end \n\n
		    } else {
			$w insert end \n
		    }
		    set var 0
		    continue
		}
		if { !$var } {
		    set var 1
		    if {[string match \#* $i]} {
			set tag comment
			set i [string range $i 1 end]
		    } elseif {[string match >* $i] } {
			set tag quote
			set i [string range $i 1 end]
		    } else {
			set tag {}
		    }
		}
	    }

	    if { "$tag" == "comment" } continue
	    
	    # expand links
	    set i [map_escaped_brackets $i]
	    while {[regexp {([^[]*)[[]([^]]+)[]](.*)} $i \
		    -> before link after]} {
		$w insert end [unmap_escaped_brackets $before] $tag
		showlink $w [unmap_escaped_brackets $link]
		set i $after
	    }
	    switch -- $tag {
		fix { $w insert end "[unmap_escaped_brackets $i]\n" $tag }
		default { $w insert end "[unmap_escaped_brackets $i] " $tag }
	    }
	}
    }
    proc show {w title} {
        variable pages
        variable history
        variable seen
        if {[lsearch -exact $seen $title]==-1} {lappend seen $title}
        $w config -state normal
        $w delete 1.0 end
	$w insert end Index link " - " {} Search link
	if [llength $history] {
	    $w insert end " - " {} History link " - " {} Back link
	}
	$w insert end \n\n
        $w insert end $title hdr \n
        switch -- $title {
	    Back    {back $w; return}
	    History {listpage $w $history}
	    Index   {listpage $w [lsort -dictionary [array names pages]]}
	    Search  {search $w}
	    default {
		if [info exists pages($title)] {
		    formattext $w $title
		}
	    }
	}
	$w insert end \n------\n {} Index link " - " {} Search link
	if [llength $history] {
	    $w insert end " - " {} History link " - " {} Back link
	}
	$w insert end \n
	lappend history $title
	$w config -state disabled
    }

}


# Example test code (please ignore the links below): 
#
# namespace import htext::*
# hpage Test {
#
#This is a help page with a [Reference]. Before this sentence came a hard linebreak. 
#
#This is after an empty line. } 
#
# hpage Reference {
#
#This is another page which points back to Test and to [Index]. It also shows a
#
# code example [which should come in Courier]
# and has two lines that should stay close together
#
#and back in normal text. } 
#
# hpage Foo {Frequent but undefined word. See also [Bar]}
# hpage Bar {Place to drink, for example. Have you checked [Foo]?}
# hpage "Two words" {Just checking - [Foo] and [Bar].}
# htext .h

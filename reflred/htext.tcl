# Code from http://mini.net/tcl/ALittleHypertextSystem
# A little hypertext system
#
# An updated version of this is at htext which also allows embedded 
# help windows and documentation in advance-- 
#
# Richard Suchenwirth - Here's a simple hypertext system that you 
# might use for online help. It exports two commands: 
#
#  hpage (title) (text)    ;# register a hypertext page's title and text body
#  htext (widget) ?title?  ;# bring up a toplevel showing the specified page
# 
# (or an alphabetic index of titles, if not specified). Thus you can use it 
# for context-sensitive help. Hypertext pages are in a subset of Wiki format: 
#
#      indented lines come in fixed font without evaluation; 
#      blank lines break paragraphs 
#      all lines without leading blanks are displayed without explicit 
#            linebreak (but possibly word-wrapped) 
#      a link is the title of another page in brackets (see examples at end). 
#
# Links are displayed underlined and blue (or purple if they have been 
# visited before), and change the cursor to a pointing hand. Clicking on 
# a link of course brings up that page. In addition, you get "Index", 
# "Search" (case-insensitive regexp in titles and full text), "History", 
# and "Back" links at the bottom of pages. In a nutshell, you get a tiny 
# browser, an information server, and a search engine ;-) 


namespace eval htext {
    namespace export hpage htext
    variable pages
    variable attachments
    variable history {} seen {}
    proc hpage {title widget {body {}}} {
        variable pages 
	variable attachments
	if [string length $body] {
	    set pages($title) $body
	    set attachments($widget) $title
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
            pack $w.t -fill both -expand 1 -side left
            pack $w.s -fill y -side left

            $w.t tag config link -foreground blue -underline 1
            $w.t tag config seen -foreground purple4 -underline 1
            $w.t tag bind link <Enter> "$w.t config -cursor hand2"
            $w.t tag bind link <Leave> "$w.t config -cursor {}"
            $w.t tag bind link <1> "[namespace current]::click $w.t %x %y"
            $w.t tag config hdr -font {Times 16}
            $w.t tag config fix -font {Courier 12}
	    texttagoption $w.t link
	    texttagoption $w.t seen
	    texttagoption $w.t hdr
	    texttagoption $w.t fix
	    bind $w.t <Escape> "destroy $w"
        }
        raise $w
	focus $w.t
        variable pages 
	variable attachments
	# load page immediately if it is recognized
	if [info exists pages($args)] {
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
        focus $w.e
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
        foreach i [lsort [array names pages]] {
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
        variable seen
        set tag link
        if {[lsearch -exact $seen $link]>-1} {
            lappend tag seen
        }
        $w insert end $link $tag
    }
    proc map_escaped_brackets { s } { string map { \\[ \001 \\] \002 } $s }
    proc unmap_escaped_brackets { s } { string map { \001 [ \002 ] } $s }
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
	    Index   {listpage $w [lsort [array names pages]]}
	    Search  {search $w}
	    default {
		if [info exists pages($title)] {
		    set var 1

		    foreach i [split $pages($title) \n] {
			if [regexp {^[ \t]+} $i] {
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
			    set var 1
			    set tag {}
			}

			# expand links
			set i [map_escaped_brackets $i]
			while {[regexp {([^[]*)[[]([^]]+)[]](.*)} $i \
				-> before link after]} {
			    $w insert end [unmap_escaped_brackets $before] $tag
			    showlink $w [unmap_escaped_brackets $link]
			    set i $after
			}
			switch -- $tag {
			    fix { $w insert end "$i\n" $tag }
			    default { $w insert end "$i " $tag }
			}
		    }
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

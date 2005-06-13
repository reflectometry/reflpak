# Gaussian fits of individual lines in the current psd image.
#
# Usage: 
#   source Gfit.tcl
#   gfit n w        ;# fit line n with a width w window
#   gfit {a b} w    ;# fit lines a to b with a width w window
#   gfit ... file   ;# save the fit parameters to a file
#
#   Line numbers can be expressions involving 'end'.
#
# To work with the data in octave:
#
#   r = load_gfit('file');
#   fieldnames(r)

octave mfile [file dir [info script]]/Gfitpkg.m
vector create Gx Gy Gdy Gfx Gfy
proc gplot {} {
    set w .gauss
    if { [winfo exists $w] } { return }
    toplevel $w
    graph $w.g
    pack $w.g -fill both -expand yes
    active_graph $w.g
    $w.g element create data -xdata Gx -ydata Gy -yerror Gdy -showerrorbars y \
	-pixels 2 -linewidth 0
    $w.g element create theory -xdata Gfx -ydata Gfy -linewidth 1 -pixels 0
}

proc gfit {slice width {file {}}} {
    if {"$file" == ""} {
	set fid stdout
    } else {
	set fid [open $file w]
    }
    puts $fid "#idx  center  height  width  area   chisq"
    upvar \#0 rec rec
    if {![info exists rec(points)]} { set rec(points) $rec(pts) }
    set start [expr [string map [list end $rec(points)] [lindex $slice 0]]]
    if {[llength $slice] > 1} {
	set stop [expr [string map [list end $rec(points)] [lindex $slice 1]]]
	#puts "Traversing $start to $stop"
	for {set i $start} {$i <= $stop} {incr i} { 
	    #puts "Looking at $i"
	    gfit1 $i $width $fid 
	    if { $i%50 == 0 } { octave sync }
	}
    } else {
	gfit1 $start $width $fid
    }
    if {"$fid" != "stdout"} { octave eval "send('close $fid')" }
}

proc gfit1 {slice width {fid {}}} {
    gplot
    octave eval "slice=$slice; width=$width; fileid='$fid';"
    
    octave eval {
	idx = [-width:width]';
	[peakval,center] = max(psd(slice,:));
	val = psd(slice,idx+center)';
	std = psderr(slice,idx+center)';
    }
    octave eval {
	[p,chisq] = gfit(idx,val,std);
	theory_x = linspace(min(idx),max(idx),200);
	theory_y = G(theory_x,p);
	send(sprintf('puts %s "%3d %f %f %f %f %g"',fileid,slice,center+p(2),p(1),p(3),sum(val),chisq));
	# send(['puts "   ',sprintf("%.3g ",1000*val),'"']);
    }
    octave recv Gx idx
    octave recv Gy val
    octave recv Gdy std
    octave recv Gfx theory_x
    octave recv Gfy theory_y
}

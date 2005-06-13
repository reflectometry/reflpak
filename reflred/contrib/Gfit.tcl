octave mfile [file dir [info script]]/Gfitpkg.m
vector create Gx Gy Gdy Gfx Gfy
proc Gplot {} {
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

proc Gfit {slice width {file {}}} {
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
	Gfit1 $i $width $fid 
        if { $i%50 == 0 } { octave sync }
     }
  } else {
    Gfit1 $start $width $fid
  }
  if {"$fid" != "stdout"} { octave eval "send('close $fid')" }
}

proc Gfit1 {slice width {fid {}}} {
  Gplot
  octave eval "slice=$slice; width=$width; fileid='$fid';"
  
  octave eval {
    idx = [-width:width]';
    [peakval,center] = max(psd(slice,:));
    val = psd(slice,idx+center)';
    std = psderr(slice,idx+center)';
  }
  octave eval {
    [f,p] = Gfit(idx,val,std);
    theory_x = linspace(min(idx),max(idx),200);
    theory_y = G(theory_x,p);
    chisq = sumsq(f-val)/length(val);
    send(sprintf('puts %s "%3d %f %f %f %f %g"',fileid,slice,center+p(2),p(1),p(3),sum(val),chisq));
    # send(['puts "   ',sprintf("%.3g ",1000*val),'"']);
  }
  octave recv Gx idx
  octave recv Gy val
  octave recv Gdy std
  octave recv Gfx theory_x
  octave recv Gfy theory_y
}

# for {set i 1} {$i<=101} {incr i} { Gfit $i [expr {$i*0.78+256}] 10 }

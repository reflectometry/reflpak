
proc write_psd_sum {file} {
  set fid [open $file w]
  foreach x $::vidx(:) y $::vsum(:) {
    puts $fid "$x $y"
  }
  close $fid
}

proc psd_hsum {} {
  psd_sum_plot
  octave eval { vsum=sum(psd') }
  octave recv vsum vsum
  octave sync
  vidx seq 1 [vsum length]
}

proc psd_vsum {} {
  psd_sum_plot
  octave eval { vsum=sum(psd) }
  vector create ::vsum
  octave recv vsum vsum
  octave sync
  vidx seq 1 [vsum length]
}

proc psd_sum_plot {} {
  if { ![winfo exist .vsum] } {
    toplevel .vsum
    graph .vsum.g
    active_graph .vsum.g
    pack .vsum.g -fill both -expand yes
    vector create ::vsum
    vector create ::vidx
    .vsum.g elem create vsum -xdata vidx -ydata vsum
  }
}


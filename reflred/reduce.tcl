
# XXX FIXME XXX turn these into resources
set ::errreduce y

# ======================================================
proc reduce_init {} {
    toplevel .reduce
    wm withdraw .reduce
    wm protocol .reduce WM_DELETE_WINDOW { wm withdraw .reduce }
    bind .reduce <Destroy> { }

    PanedWindow .reduce.panes -side left
    set listbox [.reduce.panes add -weight 1 -minsize 10]
    set graphbox [.reduce.panes add -weight 5 -minsize 10]
    sashconf .reduce.panes

    # Popup menu for performing scan operations
    menu .reduce.scanmenu -tearoff 0
    .reduce.scanmenu add command -label Convert \
	    -command { convertscan $::scanmenu_id }
    .reduce.scanmenu add command -label Edit \
	    -command { editscan $::scanmenu_id }
    .reduce.scanmenu add command -label Delete \
	    -command { clearscan $::scanmenu_id }
    .reduce.scanmenu add separator
    .reduce.scanmenu add command -label "Clear selection" \
	    -command { reduce_clear }
    .reduce.scanmenu add command -label "Delete all" \
	    -command { clearscan -all }


    set colidx 0
    foreach type { spec back slit } label { Specular Background {Slit Scan} } {
	# list box for the scan type
	set ::available_$type {}
	listbox .reduce.$type -selectmode multiple -exportselection no \
		-listvariable ::available_$type
	bind .reduce.$type <<ListboxSelect>> { reduce_selection }
	bind .reduce.$type <3> {
	    set ::scanmenu_id [Listindex_to_scanid %W @%x,%y]
	    tk_popup .reduce.scanmenu %X %Y 
	}

	## XXX FIXME XXX we could display the scan comment in a popup
	## box instead of in the list itself, which would save us some
	## screen real estate.  Probably not an issue.
	# bind .reduce.$type <Motion> { reduce_listinfo %W %x %y }

	# glue for the listbox
	label $listbox.label$type -text $label
	ScrolledWindow $listbox.box$type
	$listbox.box$type setwidget .reduce.$type
	grid $listbox.label$type -row 0 -column $colidx
	grid $listbox.box$type -sticky news -row 1 -column $colidx
	incr colidx
    }

    # resize options
    grid rowconf $listbox 0 -weight 0
    grid rowconf $listbox 1 -weight 1
    grid rowconf $listbox 2 -weight 0
    grid columnconf $listbox 0 -weight 1
    grid columnconf $listbox 1 -weight 1
    grid columnconf $listbox 2 -weight 1

    # reduction graph
    graph .reduce.graph
    set ::reduce_colorlist [option get .reduce.graph lineColors LineColors]

    # need separate y axes for the counts vs. the reflectivity
    .reduce.graph axis conf y -title "Background/Specular/Slit counts"
    .reduce.graph axis conf y2 -title "Reflectivity" -hide no
    # need separate x axes for slit scans until the proper Q correction
    # is applied
    .reduce.graph axis conf x2 -title "slit 1 opening" -hide no

    # let the graph be zoomed
    Blt_ZoomStack .reduce.graph

    active_axis .reduce.graph y
    active_axis .reduce.graph y2

    #set idx 1
    array set ::reduce_names { 
	refl "Reflectivity"
	foot "Footprint"
	div  "Divided"
	sub  "Subtracted"
	slit "Slit scan"
	spec "Specular"
	back "Background"
    }
    foreach {el mapy} {
	refl  y2
	footp y2
	foot  y2
	footm y2
	div   y2
	slit  y
	sub   y
	spec  y
	back  y
    } {
	vector create ::${el}_x ::${el}_y ::${el}_dy
	# pen for negative values
	# XXX FIXME XXX make Graph.negativePoints.* a resource and
	# process it by hand
	.reduce.graph pen create neg$el
	# -pixels 4 -fill red -color red \
#	incr idx -1
#	if { $idx < 0 } { set idx [expr [llength $::reduce_colorlist]-1] }
#	set color [lindex $::reduce_colorlist $idx]
	.reduce.graph element create $el -pixels 4 -fill {} -linewidth 0 \
		-xdata ::${el}_x -ydata ::${el}_y \
		-label {} -mapy $mapy \
		-styles [list [list neg$el -1000000000 0]] -weight ::${el}_y
	if [blt_errorbars] {.reduce.graph element conf $el -yerror ::${el}_dy}
	legend_set .reduce.graph $el on
    }

    # highlight the final reduction
    set color [lindex $::reduce_colorlist 0]
    .reduce.graph elem conf refl -linewidth 2 -color $color

    # footprint needs lines; color and dashes are set in the resource file
    foreach el { foot footp footm } {
	.reduce.graph elem conf $el -linewidth 1
	if [blt_errorbars] {.reduce.graph elem conf $el -yerror {}}
    }
    # remove unused x vectors for footprint +/-
    foreach r {p m} {
	.reduce.graph elem conf foot$r -xdata ::foot_x
	vector destroy ::foot${r}_x ::foot${r}_dy
    }

    # Need the +/- footprint legend entries for BLT version 2.4x only
    # XXX FIXME XXX eventually remove this cruft
    if { [string equal $::blt_patchLevel 2.4x] } {
	.reduce.graph elem conf footp -label "Footprint +"
	.reduce.graph elem conf footm -label "Footprint -"
    }


    # add a legend so that clicking on the legend entry toggles the display
    # of the corresponding line
    active_legend .reduce.graph footprint_toggle
    active_graph .reduce.graph

    # show coordinates
    bind .reduce.graph <Leave> { message "" }
    bind .reduce.graph <Motion> { graph_motion %W %x %y }

    # crosshairs if the users wishes
    # XXX FIXME XXX do we really need to process this resource by hand?
    if { [string is true [option get .reduce.graph crosshairs Crosshairs]] } {
	.reduce.graph crosshairs on
    }

    # actions on the reduction set
    set b [frame $graphbox.b]
    button $b.save -text "Save" \
	    -command { reduce_save -query exists }
    button $b.saveas -text "Save as..." \
	    -command { reduce_save -query all }
    button $b.print -text "Print..." \
	    -command { PrintDialog .reduce.graph }
    button $b.clear -text "Clear" -command { reduce_clear }
    button $b.footprint -text "Footprint correction..." \
	    -command { reduce_footprint_parms }
    grid $b.save $b.saveas $b.print $b.clear

    # reduction formula
    label $graphbox.formula -text "Reduced data = (Specular - Background)/(Transmission coefficient * Slit scan)"

    # transmission coefficient
    set ::calc_transmission 0
    set ::transmission_coeff 1.0
    set ::dtransmission_coeff 0.0
    set trans [frame $graphbox.transframe]
    entry $trans.entry -textvariable ::transmission_coeff
    entry $trans.pmentry -textvariable ::dtransmission_coeff
    button $trans.guess -text "Guess" -command { reduce_normalize }
    checkbutton $trans.label -text "Incident medium transmission coefficient" \
	    -variable ::calc_transmission -command reduce_selection
    label $trans.pmlabel -text "$::symbol(plusminus)"
    grid $trans.label $trans.entry $trans.pmlabel $trans.pmentry $trans.guess \
	    -sticky ew
    grid columnconf $trans 1 -weight 1
    grid columnconf $trans 3 -weight 1
    foreach w [list $trans.entry $trans.pmentry] {
	bind $w <Return> { reduce_selection }
	bind $w <FocusOut> { reduce_selection }
    }

    # footprint correction
    set ::footprint_correction 0
    set fp [frame $graphbox.footprint]
    # XXX FIXME XXX don't display footprint lines on legend if they are
    # not used on the graph
    checkbutton $fp.use -variable ::footprint_correction \
	    -text "Footprint correction" -command reduce_selection
    button $fp.extra -text "Parameters..." -command reduce_footprint_parms
    grid $fp.use $fp.extra

    # pack the graph pane
    grid $b -sticky w
    grid .reduce.graph -in $graphbox -sticky news
    grid $graphbox.formula -sticky w
    grid $trans -sticky w
    grid $fp -sticky w
    # resize the graph only
    grid rowconf $graphbox 1 -weight 1
    grid columnconf $graphbox 0 -weight 1

    # messagebox is outside all the panes
    label .reduce.message -relief ridge -anchor w -textvariable ::message

    grid .reduce.panes -sticky news
    grid .reduce.message -sticky ew
    # resize the panes only
    grid rowconf .reduce 0 -weight 1
    grid columnconf .reduce 0 -weight 1

}

# Dead code unless we want to do something while mousing over the
# list items.
proc reduce_listinfo { w x y } {
    puts [Listindex_to_scanid $w @$x,$y]
}

proc footprint_toggle { w elem hide } {
    if { [string match foot* $elem] } {
	$w elem conf foot -hide $hide
	$w elem conf footp -hide $hide
	$w elem conf footm -hide $hide
    }
}

set ::footprint_line {}
set ::footprint_m {}
set ::footprint_b {}
set ::footprint_dm {}
set ::footprint_db {}
set ::footprint_Qmin {}
set ::footprint_Qmax {}
set ::footprint_correction 0
set ::fit_footprint_correction 0
set ::fit_footprint_thru_origin 0
set ::fit_footprint_Qmin {}
set ::fit_footprint_Qmax {}
set ::footprint_at_Qmax {}
set ::footprint_Q_at_one {}
proc reduce_footprint_parms {} {
    if { [winfo exists .footprint] } {
	raise .footprint
	return
    }
    set width 8

    set fp [toplevel .footprint]
    radiobutton $fp.auto -variable ::footprint_correction_type -value fit \
	    -text "Fit footprint correction"

    checkbutton $fp.origin -variable ::fit_footprint_thru_origin \
	    -text "Fit through origin"

    set fpfr [frame $fp.fitrange]
    entry $fpfr.min -textvariable ::fit_footprint_Qmin -width $width
    entry $fpfr.max -textvariable ::fit_footprint_Qmax -width $width
    label $fpfr.from -text "Fit from Qz"
    label $fpfr.to -text "$::symbol(invangstrom) to Qz"
    label $fpfr.units -text "$::symbol(invangstrom)"
    button $fpfr.click -text "From graph..." -command {
	graph_select .reduce.graph ::fit_footprint_Qmin ::fit_footprint_Qmax
    }
    pack $fpfr.from $fpfr.min $fpfr.to $fpfr.max $fpfr.units $fpfr.click \
	-side left

    radiobutton $fp.manual -variable ::footprint_correction_type -value fix \
	    -text "Enter footprint correction"
    entry $fp.m -textvariable ::footprint_m -width $width
    entry $fp.dm -textvariable ::footprint_dm -width $width
    entry $fp.b -textvariable ::footprint_b -width $width
    entry $fp.db -textvariable ::footprint_db -width $width
    label $fp.mlab -text "Slope"
    label $fp.dmlab -text "$::symbol(plusminus)"
    label $fp.blab -text "Intercept"
    label $fp.dblab -text "$::symbol(plusminus)"
    label $fp.bunits -text "$::symbol(invangstrom)"

    frame $fp.div
    radiobutton $fp.div.lab -variable ::footprint_correction_type -value div \
	    -text "Measured footprint correction"
    ComboBox $fp.div.spec -editable no \
	    -postcommand "$fp.div.spec configure -values \$::available_spec"
    $fp.div.spec configure -modifycmd "reduce_footprint_line \[$fp.div.spec cget -text]"
    pack $fp.div.lab $fp.div.spec -side left

    set fpar [frame $fp.applyrange]
    entry $fpar.min -textvariable ::footprint_Qmin -width $width
    entry $fpar.max -textvariable ::footprint_Qmax -width $width
    label $fpar.from -text "Correct from Qz"
    label $fpar.to -text "$::symbol(invangstrom) to Qz"
    label $fpar.units -text "$::symbol(invangstrom)"
    button $fpar.click -text "From graph..." -command {
	graph_select .reduce.graph ::footprint_Qmin ::footprint_Qmax
    }
    pack $fpar.from $fpar.min $fpar.to $fpar.max $fpar.units $fpar.click \
	-side left

    set fpcr [frame $fp.constrange]
    label $fpcr.const -textvariable ::footprint_at_Qmax
    label $fpcr.dconst -textvariable ::footprint_at_Qmax_err
    label $fpcr.from -text "Constant correction"
    label $fpcr.pm -textvariable "$::symbol(plusminus)"
    label $fpcr.to -text "beyond"
    pack $fpcr.from $fpcr.const $fpcr.pm $fpcr.dconst $fpcr.to -side left

    set fpone [frame $fp.one]
    label $fpone.qone -textvariable ::footprint_Q_at_one
    label $fpone.at -text "Correction is 1.0 at Qz ="
    label $fpone.units -text "$::symbol(invangstrom)"
    pack $fpone.at $fpone.qone $fpone.units -side left

    button $fp.apply -text Apply -command {
	set ::footprint_correction 1
	reduce_selection
    }

    grid $fp.auto - - - - - -sticky sw
    grid x $fp.origin - - - - -sticky w
    grid x $fpfr - - - - -sticky ew
    grid $fp.manual - - - - - -sticky sw
    grid x $fp.mlab $fp.m $fp.dmlab $fp.dm x -sticky ew
    grid x $fp.blab $fp.b $fp.dblab $fp.db $fp.bunits -sticky ew
    grid $fp.div - - - - -sticky ew
    grid $fpar - - - - - -sticky sew
    grid $fpcr - - - - - -sticky sew
    grid $fpone - - - - - -sticky sew
    grid $fp.apply - - - - -  -sticky e -pady 10

    # force indent relative to the radio buttons
    grid columnconfigure $fp 0 -minsize 20
    # force Slope/Intercept to be left justified
    grid configure $fp.mlab $fp.blab -sticky w
    # space between the sections
    grid rowconfigure $fp 0 -pad 10
    foreach row { 3 6 7 8 } { grid rowconfigure $fp $row -pad 15 }
    # column stretch
    foreach col { 2 4 } { grid columnconfigure $fp $col -weight 1 }
    pack conf $fpar.min $fpar.max $fpfr.min $fpfr.max -fill x -expand yes
}

proc reduce_footprint_line { name } {
    # prep the scan associated with the footprint line name
    set name [lindex [split $name] 0]
    if { [info exists ::scanindex($name)] } {
	set id $::scanindex($name)
	::${id}_y dup ${id}_ky
	::${id}_dy dup ${id}_kdy
    } else {
	message "Could not find line $name"
	set id {}
    }

    # update the graph with the footprint line
    # XXX FIXME XXX provide facility for users to add/remove lines under
    # console control (even if they don't enter into the reduction equation)
    set ::footprint_line $id
    set ::footprint_correction_type div
    Selection_to_scanids spec back slit
    reduce_graph $spec $back $slit
}

proc reduce_footprint_correction {} {
    # default to no footprint correction
    octave eval { foot = [] }
    foreach v { _x _y _dy p_y m_y } { ::foot$v delete : }

    if { !$::footprint_correction } { return }

    switch $::footprint_correction_type {
	fit {
	    if { ![string is double $::fit_footprint_Qmin] || \
		    ![string is double $::fit_footprint_Qmax] } {
		set ::message "Invalid footprint fit Q range"
		return
	    }
	    octave eval "idx = refl.x >= $::fit_footprint_Qmin & refl.x <= $::fit_footprint_Qmax"
	    if { $::fit_footprint_thru_origin } {
		octave eval { origin='origin' }
	    } else {
		octave eval { origin='' }
	    }
	    #octave eval {
  	    #    send(sprintf('puts {x=%s}',mat2str(refl.x(idx))));
	    #    send(sprintf('puts {y=%s}',mat2str(refl.y(idx))));
	    #    send(sprintf('puts {dy=%s}',mat2str(refl.dy(idx))));
	    #}
	    octave eval {
		[p,dp] = wpolyfit(refl.x(idx),refl.y(idx), ...
	                      refl.dy(idx),1,origin);
		send(sprintf('set ::footprint_m  %.15g', p(1)));
		send(sprintf('set ::footprint_dm %.15g',dp(1)));
		send(sprintf('set ::footprint_b  %.15g', p(2)));
		send(sprintf('set ::footprint_db %.15g',dp(2)));
	    }
	}
	fix {
	    if [string equal {} $::footprint_b] { set ::footprint_b 0.0 }
	    if [string equal {} $::footprint_db] { set ::footprint_db 0.0 }
	    if [string equal {} $::footprint_dm] { set ::footprint_dm 0.0 }
	    if { ![string is double $::footprint_m] || \
		    ![string is double $::footprint_dm] || \
		    ![string is double $::footprint_b] || \
		    ![string is double $::footprint_db] } {
		set ::message "Invalid footprint slope/intercept"
		return
	    }
	    octave eval "p = \[$::footprint_m $::footprint_b]"
	    octave eval "dp = \[$::footprint_dm $::footprint_db]"
	}
    }


    # Compute the footprint for all x
    switch -- $::footprint_correction_type {
	fit -
	fix {
	    if { ![string is double $::footprint_Qmin] || \
		    ![string is double $::footprint_Qmax] } {
		set ::message "Invalid footprint application Q range"
		return
	    }
	    
	    octave eval "Qmin = $::footprint_Qmin; Qmax = $::footprint_Qmax"

	    octave eval {
		# linear between Qmin and Qmax
		foot.x = refl.x;
		foot.y = polyval(p,refl.x);
		foot.dy = sqrt(polyval(dp.^2,refl.x.^2));
		fpQmax = polyval(p,Qmax);
		dfpQmax = sqrt(polyval(dp.^2,Qmax.^2));

		send(sprintf('set footprint_Q_at_one %.15g', (1-p(2))/p(1)));
		send(sprintf('set footprint_at_Qmax %.15g', fpQmax));
		send(sprintf('set footprint_at_Qmax_err %.15g', dfpQmax));

		# ignore values below Qmin
		foot.y(refl.x < Qmin) = 1;
		foot.dy(refl.x < Qmin) = 0;
		# stretch Qmax to the end of the range
		foot.y(refl.x > Qmax) = fpQmax;
		foot.dy(refl.x > Qmax) = dfpQmax;
	    }
	}
	div {
	    if { ![llength $::footprint_line]} {
		set ::message "No footprint line selected"
		return
	    }
	    set ::footprint_Q_at_one {}
	    octave eval "fd=$::footprint_line"
	    octave eval {
		# interpolated footprint curve
		foot = refl;
		[foot.y, foot.dy] = interp1err(fd.x,fd.y,fd.dy,refl.x);
		foot.y(isnan(foot.y)) = 1.0;
		foot.dy(isnan(foot.dy)) = 0.0;
		# [fpQmax,dfpQmax] = interp1err(fd.x,fd.y,fd.dy,Qmax);
	    }
	}
    }
    

    # divide by the footprint
    octave eval { refl = run_div(refl,foot); }

    # send results
    octave eval { 
	send_run('foot_%s', foot); 
    }
	
    octave recv footp_y { foot.y + foot.dy }
    octave recv footm_y { foot.y - foot.dy }
	
}


set ::reduce_coloridx 0
proc reduce_graph {spec back slit} {
    # clear the old lines which are no longer used
    # XXX FIXME XXX do we really want to rely on the fact that scanids start
    # with the word 'scan'?
    set lines [concat $spec $back $slit $::footprint_line]
    foreach elem [.reduce.graph elem names scan*] {
	if { [lsearch $lines $elem] < 0 } {
	    .reduce.graph elem delete $elem
	}
    }

    # add the lines that are not already displayed
    if { [string equal "" $::reduce_head] } {
	.reduce.graph axis conf y -title Counts
    } else {
	.reduce.graph axis conf y -title [set ::${::reduce_head}(ylab)]
    }
    foreach part { spec back slit ::footprint_line } \
	    op { + - / = } \
	    xaxis { x x x2 x } \
	    yaxis { y y y y2 } {
	foreach idx [set $part] {
	    if { [llength [.reduce.graph elem names $idx]] == 0 } {
		if {[incr ::reduce_coloridx]>=[llength $::reduce_colorlist]} {
		    # reserve color 0 for the reduced line
		    set ::reduce_coloridx 1
		}
		set color [lindex $::reduce_colorlist $::reduce_coloridx]

		.reduce.graph elem create $idx -mapx $xaxis -mapy $yaxis \
			-xdata ::${idx}_x -ydata ::${idx}_ky -pixels 1 \
			-label "$op [set ::${idx}(legend)]" -color $color
		if { [blt_errorbars] } {
		    .reduce.graph elem conf $idx -yerror ::${idx}_kdy \
			    -showerrorbar $::errreduce
		}

		# hide the raw slit scan but show everything else
		if { [string equal $xaxis x2] } {
		    legend_set .reduce.graph $idx off
		} else {
		    legend_set .reduce.graph $idx on
		}
	    }
	}
    }
}

# Choose a value for the transmission coefficient which yields a peak
# reflectivity of 1.0.
proc reduce_normalize {} {
    ## Run reduce with no transmission coefficient.
    ## In theory we don't have to do this because the reduced curve is
    ## kept up to date.  In practice, the user may have started typing
    ## in a new transmission coeffecient, or requested a new footprint
    ## correction or something which makes the current reduced curve or
    ## transmission coefficient unreliable.
    ## If you decide the current values are reliable and you just want
    ## to scale the current transmission coefficient, be careful when
    ## calculating the new error since the current error already
    ## contributes to the error in the peak.  You will need to include
    ## the covariance term in the error propogation equations.
    Selection_to_scanids spec back slit
    set ::transmission_coeff 1.0
    set ::dtransmission_coeff 0.0
    set ::calc_transmission 1
    reduce $spec $back $slit

    octave eval {
	up = find(diff(refl.y)>0);
	# if !isempty(up)
	[peak,idx] = max(refl.y(up(1):length(refl.y)));
	dpeak = refl.dy(up(1)+idx-1);
	send (sprintf('set ::transmission_coeff %g',peak));
	send (sprintf('set ::dtransmission_coeff %g',dpeak));
	div = refl = run_scale(refl, 1/peak, dpeak / peak^2);
	send_run("div_%s", div);
	send_run("refl_%s", refl);
    }
}

proc old_normalize_code {} {
    ## Wait for the reduced curve
    ## XXX FIXME XXX make sure there is only one "sync", either at the
    ## end of reduce or before its products are needed
    octave sync

    ## Find peak in reduced curve
    set ::transmission_coeff [vector expr max(::refl_y)]
    set ::dtransmission_coeff \
	    $::refl_dy([lindex [::refl_y search $::transmission_coeff] 0])

    ## Scale reduced curve by the peak value
    ## Note that ^ is exponentiation in vector expr, not XOR as in expr
    ## XXX FIXME XXX what about the covariance between v and the peak?
    set v [expr 1/$::transmission_coeff]
    set dv [vector expr "$::dtransmission_coeff / $::transmission_coeff ^ 2" ]
    ::refl_dy expr "sqrt( ($v * ::refl_dy)^2 + ($dv * ::refl_y)^2 )"
    ::refl_y expr "$v * ::refl_y"
}

proc reduce {spec back slit} {
    # average the lines in the individual parts
    set ::reduce_monitor 0
    set ::reduce_head ""
    foreach part { spec back slit } {
	octave eval $part=\[]
	foreach idx [ set $part ] {
	    set this_monitor [set ::${idx}(monitor)]
	    if { $::reduce_monitor == 0 } {
		set ::reduce_monitor $this_monitor
		set ::reduce_head $idx
	    }
	    set this_monitor [expr $::reduce_monitor/$this_monitor]
	    ::${idx}_ky expr "$this_monitor*::${idx}_y"
	    ::${idx}_kdy expr "$this_monitor*::${idx}_dy"
	    octave eval "$part = run_poisson_avg($part,run_scale($idx,$this_monitor))"
	}
    }

    # Combine the parts, creating sub if there is background subtraction
    # and div if there is slitscan division.  The result is in reduce.
    # XXX FIXME XXX older versions of octave fail to execute
    #   eval("\n  statement;\n   statement;");
    # the work-around belongs in listen, not here.
    octave eval {
        refl = sub = div = [];
	if !isempty(spec)
	   refl = spec;
	   if !isempty(back)
	      back = run_interp(back,refl.x);
	      refl = run_trunc(refl,back.x);
              refl = run_sub(refl,back);
	      sub = refl;
	   endif
	   if !isempty(slit)
	      if struct_contains(spec,'m')
	         if length(slit.x) > 1
                    # interpolate over slit scan region
                    [_y,_dy]=interp1err(slit.x,slit.y,slit.dy,spec.m);

                    # extrapolate with a constant
                    _y(spec.m<slit.x(1)) = slit.y(1);
                    _dy(spec.m<slit.x(1)) = slit.dy(1);
                    _y(spec.m>slit.x(length(slit.x))) = slit.y(length(slit.x));
                    _dy(spec.m>slit.x(length(slit.x))) = slit.dy(length(slit.x));
                    # replace the (s,y,dy) with interpolated (q,y,dy)
                    slit.x = spec.x;
                    slit.y = _y;
                    slit.dy = _dy;
                    clear _y _dy
	         elseif all(abs(slit.x-spec.m) < 100*eps)
                    # XXX FIXME XXX condition depends on slit.x less than 100
	            # Single point slit scan
	            slit.y = slit.y*ones(size(spec.m));
	            slit.dy = slit.dy*ones(size(spec.m));
	            slit.x = spec.x;
	         else
	            # XXX FIXME XXX this needs to be reduce_message
	            send('message "slit scan slit does not match specular slit"')
	            slit = [];
	         endif
	      else
                 # XXX FIXME XXX XXX FIXME XXX XXX FIXME XXX
                 # this slitscan reduction will not work in general!!!
	         send('message "no slit 1 info in specular --- using dumb heuristic for slits"');
	         slit.y = prepad(slit.y,length(slit.x),slit.y(1));
	         slit.dy = prepad(slit.dy,length(slit.x),slit.dy(1));
	         slit.x = spec.x;
	      endif
	      if !isempty(slit)
	         slit = run_interp(slit,refl.x);
	         refl = run_trunc(refl,slit.x);
	         refl = run_div(refl,slit);
                 div = refl;
	      endif
	   endif
        endif
    }

    # convert transmission coefficient to a scale factor
    if { $::calc_transmission } {
	if { ![string_is_double $::dtransmission_coeff] } {
	    set ::dtransmission_coeff 0.0
	}
	if { ![string_is_double $::transmission_coeff] } {
	    set ::transmission_coeff 1.0
	}
	set v [expr 1.0/$::transmission_coeff]
	# Note that ^ is exponentiation in vector expr, not XOR as in expr
	set dv [vector expr "$::dtransmission_coeff/$::transmission_coeff^2"]
	
	# scale by the transmission factor, if it is not 1
        octave eval "div = refl = run_scale(refl, $v, $dv);"
    }

    # footprint correction
    reduce_footprint_correction

    # send back the results
    # Note: send_run is defined above in proc reduce_init
    octave eval {
	send_run('spec_%s', spec);
	send_run('back_%s', back);
	send_run('slit_%s', slit);
	send_run('refl_%s', refl);
	send_run('sub_%s', sub);
	send_run('div_%s', div);
    }

    foreach line { spec back slit refl sub div foot } {
	octave eval [subst {
	    if !isempty($line)
	        send('.reduce.graph elem conf $line -label {$::reduce_names($line)}');
	    else
	        send('.reduce.graph elem conf $line -label {}');
	    endif
	}]
    }

    # XXX FIXME XXX - do we really need to sync?
    # puts "syncing"
    # octave sync


    # XXX FIXME XXX don't forget to log the what we have done when we
    # save the results!  Do we want to display the log in a text window?
}

# convert selections into scanids, setting the variables
# spec, back and slit in the parent
proc Listindex_to_scanid {w idx} {
    set scanname [lindex [split [$w get $idx]] 0]
    if { [llength $scanname] > 0 } {
	return $::scanindex($scanname)
    } else {
	return {}
    }
}

proc Selection_to_scanids {sp bk sl} {
    upvar $sp spec
    upvar $bk back
    upvar $sl slit
    foreach part { spec back slit } {
	set $part {}
	foreach idx [.reduce.$part curselection] {
	    lappend $part [Listindex_to_scanid .reduce.$part $idx]
	}
    }
}

proc reduce_selection {} {

    Selection_to_scanids spec back slit

    # recalculate the reduction
    reduce $spec $back $slit

    # update the graph with the new lines
    reduce_graph $spec $back $slit
}

proc reduce_clear {} {
    foreach part { spec back slit } {
	.reduce.$part selection clear 0 end
    }
    set ::reduce_coloridx 0
    reduce_selection
}

proc reduce_setpath { dir } {
    # change to the new working directory
    set cwd [pwd]
    cd $dir
    set ::scanpath [pwd]

    # clear all existing scans (including ones created this session)
    catch { unset [info names scan#*] }

    # load all scan files in the new directory
    foreach f [glob *.scan] {
	if [catch { scan_load $f } scanid] {
	    puts "scan_load: $scanid"
	} else {
	    reduce_add $scanid
	}
    }

    cd $cwd
}


# ======================================================

# This is just a macro for savescan.  It gets fid, log and rec
# from there
proc write_reduce { } {
    upvar spec spec
    upvar back back
    upvar slit slit
    upvar data data
    upvar rec rec
    upvar fid fid
    upvar log log
    puts $fid "# date [clock format $rec(date) -format %Y-%m-%d]"
    puts $fid "# title \"$rec(comment)\""
    puts $fid "# instrument $rec(instrument)"
    puts $fid "# monitor $rec(monitor)"
    puts $fid "# temperature $rec(T)"
    puts $fid "# field $rec(H)"
    puts $fid "# wavelength $rec(L)"
    # XXX FIXME XXX Hmmm... type might be Specular Background Slit scan ...
    # or it may be:
    #   Subtracted specular (if it includes spec and back) 
    #   Divided specular (if it includes spec and slit, and possibly back)
    #   Divided background (if it includes back and slit but not spec)
    #      this will require special processing during reduction in that
    #      subtraction will happen after slit scan rather than before.
    #   Reflectivity (if it includes footprint and polarization correction)
    #puts $fid "# type $rec(type)"
    #puts $fid "# xlabel $rec(xlab)"
    #puts $fid "# ylabel $rec(ylab)"

    # which runs make up the dataset?
    foreach type { spec back slit } {
	foreach id [set $type] {
	    upvar #0 $id scanrec
#	    puts "writing scan #$id"
#	    puts [array get scanrec]
	    puts $fid "# $type $scanrec(files)"
	}
    }

    # XXX FIXME XXX move these to where they are actually calculated.  This
    # is especially important for footprint correction since the output is
    # dependent on the kind of footprint correction that is needed.
    if {$::calc_transmission} {
	puts $fid "# transmission coefficient [fix $::transmission_coeff {} {} 5]([fix $::dtransmission_coeff {} {} 5])"
    }
    if {$::footprint_correction} {
	switch $::footprint_correction_type {
	    fit -
	    fix {
		puts $fid "# footprint [fix $::footprint_m {} {} 5]([fix $::footprint_dm {} {} 5]) + [fix $::footprint_b {} {} 5]([fix $::footprint_db {} {} 5]) from Qz=[fix $::footprint_Qmin {} {} 5] to Qz=[fix $::footprint_Qmax {} {} 5], [fix $::footprint_at_Qmax {} {} 5]([fix $::footprint_at_Qmax_err {} {} 5]) above"
	    }
	    div {
		puts $fid "# footprint divided by [set ::${::footprint_line}(file)]"
	    }
	}
    }
	    
    write_data $fid ::$data 
}


# reduce_save [-query all|existing|none] [-record id] [-vector id]
proc reduce_save { args } {
    array set opt [list \
	    -query none \
	    -record $::reduce_head \
	    -vector refl_ ]
    array set opt $args
    upvar #0 $opt(-record) rec

    # Determine the valid extensions.  These will depend on
    # the type since we need to distinguish between bg and avg bg for
    # some background runs and between spec, background subtraction,
    # slit corection and polarization correction), all with the same
    # prefix.
    Selection_to_scanids spec back slit
    set havespec [llength $spec]
    if { [info exists rec(psd)] } {
	set haveback [expr {[llength $back]>0 || $rec(psd)}]
    } else {
	set haveback [expr {[llength $back]>0}]
    }
    set needfoot [expr ![string equal $rec(instrument) NG7]]
    set haveslit [expr $::calc_transmission || [llength $slit]]
    set havefoot [expr $havespec && $::footprint_correction]

    if { $havefoot || ($havespec && $haveback && !$needfoot) } {
	set ext .refl
	set data refl
    } elseif {$havespec && $haveslit} {
	set ext .div
	set data div
    } elseif {$havespec && $haveback} {
	set ext .sub
	set data sub
    } elseif {$havespec} {
	set ext .addspec
	set data spec
    } elseif {$haveback} {
	set ext .addback
	set data back
    } elseif {$haveslit} {
	set ext .addslit
	set data slit
    }

    # XXX FIXME XXX do I really need to hardcode NG1p stuff here?
    if { [string equal $rec(instrument) "NG1p"] } {
	set ext "$ext[string toupper [string index $rec(file) end-1]]"
    }

    # Get the filename to use
    # XXX FIXME XXX will the user be surprised that the default format
    # is set by ::logaddrun?  Maybe we should add a log/linear option
    # for scripting control
    # XXX FIXME XXX need to be able to overwrite the title; the way to
    # do this is to move the title into a separate widget, but we will
    # have to add it to the graph before printing.  Maybe an EPS canvas?
    # Maybe nice to annotate the graphs as well.
#    if { $::logaddrun } {
#	set filename [file rootname $rec(file)]$logext
#    } else {
	set filename [file rootname $rec(file)]$ext
#    }
    if { [string equal $opt(-query) "all"] } {
	set filename [ tk_getSaveFile -defaultextension $ext \
		-title "Save scan data" -parent .reduce ]
#		-filetypes [list [list Log $logext] [list Linear $ext]] ]
	if { [string equal $filename ""] } { return }
    } elseif { [string equal $opt(-query) "exists"] } {
	if { [file exists $filename] } {
	    set ans [tk_messageBox -type okcancel -default ok \
		    -icon warning -parent .reduce \
		    -message "$filename exists. Do you want to overwrite it?" \
		    -title "Save scan data" ]
	    if { [string equal $ans cancel] } { return }
	}
    }

    # Linear or log?
    set log [string equal [file extension $filename] .log]

    # Write the file
    if { [catch { open $filename w } fid] } {
	message $fid; bell;
    } else {
	if { [catch { write_reduce } msg] } {
	    message $msg; bell
	} else {
	    message "Saving data in $filename"
	}
	close $fid
    }

}

# XXX FIXME XXX assumes the data is already in octave
# (which is a good assumption since that where the
# run was composed in the first place, except that it
# isn't yet)
#    octave eval "
#       $scanrec(id).x = \[ [set $scanrec(id)_x(:)] ];
#       $scanrec(id).y = \[ [set $scanrec(id)_y(:)] ];
#       $scanrec(id).dy = \[ [set $scanrec(id)_dy(:)] ];"
# XXX FIXME XXX includes code for checking if this is a new
# or existing scan, and if it is an existing scan, whether
# it is in use or not.  Is this appropriate for a function
# named "..._newscan"?
proc reduce_newscan { scanid } {
    upvar #0 $scanid scanrec
    if { ![info exists scanrec(exists)] } {
	#puts "creating new scan entry"
	set item "$scanrec(name) $scanrec(comment)"
	# XXX FIXME XXX if scan is not a known type then we
	# need a way to kill it
	switch -- $scanrec(type) {
	    spec -
	    slit -
	    back { listbox_ordered_insert .reduce.$scanrec(type) $item }
	}
	set scanrec(exists) 1
    } elseif { ![string equal {} [.reduce.graph elem names $scanid]] } {
	#puts "updating existing scan entry"
	reduce_selection
    } else {
	#puts "scan already entered"
    }
}

proc reduce_clearscan { scanid } {
    if { [string equal $scanid -all] } {
	foreach box { spec slit back } { .reduce.$box delete 0 end }
    } else {
	upvar #0 $scanid scanrec
    
	set item "$scanrec(name) $scanrec(comment)"
	switch -- $scanrec(type) {
	    spec -
	    slit -
	    back { listbox_delete_by_name .reduce.$scanrec(type) $item }
	}
    }
    reduce_selection
}

proc convertscan { scanid } {
    upvar \#0 $scanid scanrec
    switch -- $scanrec(type) {
	spec { set newtype back }
	back { set newtype spec }
	slit { message "Can't convert slitscans" }
    }
    # if changing from background, strip the +/- index
    if {[string match {*[-+]} $scanrec(index)]} {
	set newindex [string range $scanrec(index) 0 end-1]
    } else {
	set newindex $scanrec(index)
    }
    message "Converting $scanrec(type)$scanrec(index) to $newtype$newindex"
    set item "$scanrec(name) $scanrec(comment)"
    listbox_delete_by_name .reduce.$scanrec(type) $item
    set scanrec(type) $newtype
    set scanrec(index) $newindex
    listbox_ordered_insert .reduce.$scanrec(type) $item
    reduce_selection
}

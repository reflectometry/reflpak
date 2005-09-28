
# ======================================================
proc reduce_init {} {
    # XXX FIXME XXX turn these into resources
    set ::errreduce y
    set ::reduce_coloridx 0
    set ::reduce_polratio 0.5

    # Generate some dataset holders
    vector create ::polx ::polxraw
    foreach v { polf polr flipf flipr beta } { vector create ::${v} ::${v}raw }
    foreach pol { {} A B C D } {
	vector create ::slitfit${pol}
        foreach v { refl div sub slit spec back } {
            vector create ::${v}_x$pol ::${v}_y$pol ::${v}_dy$pol
        }
    }

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

    # let the graph be zoomed
    Blt_ZoomStack .reduce.graph

    active_axis .reduce.graph y
    active_axis .reduce.graph y2

    foreach {el mapy sym} {
        refl  y2 splus
        div   y2 square
        sub   y  circle
    } {
        foreach {pol color} { {} 0 A 0 B 1 C 2 D 3 } {
	    # pen for negative values
	    # XXX FIXME XXX make Graph.negativePoints.* a resource and
	    # process it by hand
            # XXX FIXME XXX pixel doesn't work for pens
            opt .reduce.graph.neg$el$pol color red \
                symbol none fill {} errorBarWidth 0 lineWidth 0
	    .reduce.graph pen create neg$el$pol
            opt .reduce.graph.$el$pol pixels 4 fill {} lineWidth 1 \
                color [lindex $::reduce_colorlist $color] symbol $sym
	    .reduce.graph element create $el$pol \
		-xdata ::${el}_x$pol -ydata ::${el}_y$pol \
		-label {} -mapy $mapy \
		-yerror ::${el}_dy$pol \
		-styles [list [list neg$el -100000 0]] -weight ::${el}_y$pol
	    # Note: BLT bug --- can't specify -styles {{neg -inf 0}}.
	    # Using -100000 isn't a good approximation, but as the that
	    # number grows smaller, and increasing number of spurious points
	    # are deemed to be negative.

	    legend_set .reduce.graph $el$pol on
	}
    }
    foreach {pol color} { {} 0 A 0 B 1 C 2 D 3 } {
	# highlight the final reduction
	.reduce.graph elem conf refl$pol -linewidth 2
    }
    opt .reduce.graph.Element pixels 0 symbol {} lineWidth 1

    # add a legend so that clicking on the legend entry toggles the display
    # of the corresponding line
    active_legend .reduce.graph
    active_graph .reduce.graph

    # add cross-section toggles
    pol_toggle_init .reduce.graph

    # show coordinates
    bind .reduce.graph <Leave> { message "" }
    bind .reduce.graph <Motion> { reduce_graph_motion %W %x %y }

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
    button $b.polcor -text "Show slits..." -command { reduce_slits }
    grid $b.save $b.saveas $b.print $b.clear $b.polcor

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
    button $fp.extra -text "Parameters..." -command footprint::draw
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
    label .reduce.message -relief ridge -anchor w

    grid .reduce.panes -sticky news
    grid .reduce.message -sticky ew
    # resize the panes only
    grid rowconf .reduce 0 -weight 1
    grid columnconf .reduce 0 -weight 1

}

# XXX FIXME XXX make this generic
# show the coordinates of the nearest point
proc reduce_graph_motion { w x y } {
    $w crosshairs conf -position @$x,$y
    $w element closest $x $y where -halo 1i
    if { [info exists where(x)] } {
	set ptid "[$w elem cget $where(name) -label]:[expr $where(index)+1]"
	set ptx [fix $where(x)]
	set pty [fix $where(y) {} {} 5]
	.reduce.message conf -text "$ptid  $ptx, $pty"
    } else {
	.reduce.message conf -text ""
    }
}

# This function is called with set/clear when a particular vector
# is updated; this in needed to hide/show individual labels on
# the graph.
#
# XXX FIXME XXX not nice --- run_send is pretty generic, and it
# seems silly to always have to check the reduce graph for the
# associated name.  Need to turn this into a registration mechanism.
proc run_send {action name} {
    set line [string map { _ {} } $name]
    set label [string map { _ { } } $name]
    set label "[string toupper [string index $label 0]][string range $label 1 end]"
    if { [.reduce.graph elem names $line] ne {} } {
	switch -- $action {
	    set { .reduce.graph elem conf $line -label $label }
	    clear { .reduce.graph elem conf $line -label {} }
	}
    }
}


proc reduce_show {} {
    wm deiconify .reduce
    raise .reduce
}

# Dead code unless we want to do something while mousing over the
# list items.
proc reduce_listinfo { w x y } {
    puts [Listindex_to_scanid $w @$x,$y]
}

# generate slit scan display window
proc reduce_slits {} {
    set w .slits
    if {[winfo exists $w]} { raise $w; return }
    toplevel $w
    set colors [option get $w lineColors LineColors]
    opt $w.Graph leftMargin 50 rightMargin 60
    opt $w.Graph.Element Label {} LineWidth 1 Symbol {} Pixels 0 Fill defcolor
    opt $w.intensity y.title "Counts" x.Hide 1
    opt $w.efficiency y.title "Efficiency (%)" \
        x.title "slit 1 values"
    foreach el {polf polr flipf flipr beta} c [lrange $colors 0 4] {
	opt $w.Graph.${el} color $c 
	opt $w.Graph.${el}raw color $c symbol diamond \
	    label [string totitle $el] pixels 4 fill $c
    }
    foreach pol {A B C D} c [lrange $colors 0 3] {
        opt $w.intensity.slit$pol lineWidth 0 fill $c \
            pixels 4 color $c label "Slit $pol" symbol circle
        opt $w.intensity.fit$pol color $c
    }
    opt $w.Graph.Element pixels 4 lineWidth 0 fill {}
    opt $w.efficiency.clip fill lightyellow under 1 \
	coords { 0 1 100 1 100 2 0 2 0 1 }
    opt $w.intensity.z lineWidth 3 outline darkgray under 1 coords { 0 0 0 1 }
    graph $w.intensity -height 150
    # XXX FIXME XXX if slit range goes beyond Q range, 
    # then graphs will not align properly
    graph $w.efficiency -height 150
    active_graph $w.intensity
    active_graph $w.efficiency
    active_legend $w.intensity
    active_legend $w.efficiency
    active_axis $w.intensity y
    active_axis $w.efficiency y
    foreach el beta {
	$w.intensity elem create beta -xdata ::polx -ydata ::beta \
	    -linewidth 1
	$w.intensity elem create betaraw -xdata ::polxraw -ydata ::betaraw \
	    -fill defcolor -pixels 4
    }
    foreach pol {A B C D} {
        $w.intensity elem create slit$pol -fill defcolor -pixels 4 \
            -xdata ::slit_x$pol -ydata ::slit_y$pol -yerror ::slit_dy$pol
        $w.intensity elem create fit$pol -xdata ::polx -ydata ::slitfit$pol \
	    -linewidth 1
    }
    foreach el {polf polr flipf flipr} {
        $w.efficiency elem create $el -xdata ::polx -ydata ::${el} \
	    -linewidth 1
        $w.efficiency elem create ${el}raw -xdata ::polxraw -ydata ::${el}raw \
	    -fill defcolor -pixels 4
    }
    $w.efficiency marker create polygon -name clip
    $w.intensity marker create line -name z
    # Display current z if it is defined
    reduce_slit_z
	
    grid $w.intensity -sticky news
    grid $w.efficiency -sticky news
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w {0 1} -weight 1
}

# z is the crossover between quadratic and linear models in the slit fit.
# reduce_slit_z indicates this value on the polarization correction plot.
proc reduce_slit_z {{z {}}} {
    variable reduce_slit_z
    if { $z != "" } { set reduce_slit_z $z }
    if { ![info exists reduce_slit_z] } { set reduce_slit_z 0. }
    set z $reduce_slit_z
    if {[winfo exists .slits]} {
	.slits.intensity marker conf z -coords [list $z -Inf $z Inf]
    }
}

proc reduce_graph {spec back slit} {
    # Convert scan sets to individual scan lines
    foreach part { spec back slit } {
        set l$part {}
        foreach l [set $part] {   
            set l$part [concat [set l$part] [reduce_lines $l]]
        }
    }
    
    # clear the old lines which are no longer used
    # XXX FIXME XXX do we really want to rely on the fact that scanids start
    # with the word 'scan'?
    set lines [concat $lspec $lback $lslit]
    foreach elem [.reduce.graph elem names $::scanpattern] {
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
    foreach part { lspec lback } \
	    op { + - } \
	    xaxis { x x } \
	    yaxis { y y } {
	foreach idx [set $part] {
	    if { [llength [.reduce.graph elem names $idx]] == 0 } {
		if {[incr ::reduce_coloridx]>=[llength $::reduce_colorlist]} {
		    # reserve color 0-3 for processed lines
		    set ::reduce_coloridx 4
		}
		set color [lindex $::reduce_colorlist $::reduce_coloridx]

		.reduce.graph elem create $idx -mapx $xaxis -mapy $yaxis \
		    -xdata ::${idx}_x -ydata ::${idx}_ky \
		    -label "$op [set ::${idx}(legend)]" -color $color \
		    -yerror ::${idx}_kdy -showerrorbar $::errreduce
		
		# hide the raw slit scan but show everything else
		if { [string equal $xaxis x2] } {
		    legend_set .reduce.graph $idx off
		} else {
		    legend_set .reduce.graph $idx on
		}
	    }
	}
    }
    octave eval { send("event generate .reduce.graph <<Elements>>"); }
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

    # XXX FIXME XXX fails for polarized beam
    octave eval {
	up = find(diff(refl.y)>0);
	# if !isempty(up)
	[peak,idx] = max(refl.y(up(1):length(refl.y)));
	dpeak = refl.dy(up(1)+idx-1);
	send (sprintf('set ::transmission_coeff %g',peak));
	send (sprintf('set ::dtransmission_coeff %g',dpeak));
	div = refl = run_scale(refl, 1/peak, dpeak / peak^2);
	run_send_pol("div_%s", div);
	run_send_pol("refl_%s", refl);
    }
}

# average the lines in the individual parts
proc reduce_parts {spec back slit} {
    set ::reduce_monitor 0
    set ::reduce_head {}
    set ::reduce_polarized 0
    foreach part { spec back slit } {
	octave eval "$part = \[];"
	foreach idx [ set $part ] {
            if {[info exists ::${idx}(polarized)]} {
                set ::reduce_polarized 1
            }
            foreach line [reduce_lines $idx] {
		set mon [set ::${line}(monitor)]
		if { $::reduce_monitor == 0 } {
		    set ::reduce_monitor $mon
		    set ::reduce_head $line
		}
		set mon [expr double($::reduce_monitor)/$mon]
		::${line}_ky expr "$mon*::${line}_y"
		::${line}_kdy expr "$mon*::${line}_dy"
                if { [info exists ::${line}(polarization)] } {
                    set pol [set ::${line}(polarization)]
                } else {
                    set pol {}
                }
		octave eval "$part = reduce_part($part,$line,$mon,'$pol')"
	    }
	}
    }
}

proc reduce {spec back slit} {

    # build spec,back,slit from parts
    reduce_parts $spec $back $slit
    octave eval {
	run_send_pol('spec_%s', spec);
	run_send_pol('back_%s', back);
	run_send_pol('slit_%s', slit);
	# XXX FIXME XXX a better way of coordinating footprint screen?
	send("::footprint::slits $::spec_x(:) $::spec_m(:)")
    }

    # Combine the parts, creating sub if there is background subtraction
    # and div if there is slitscan division.  The result is in reduce.
    # XXX FIXME XXX older versions of octave fail to execute
    #   eval("\n  statement;\n   statement;");
    # the work-around belongs in listen, not here.
    octave eval "\[sub, div, cor] = reduce(spec,back,slit,$::reduce_polratio);"

    # convert transmission coefficient to a scale factor
    if { $::calc_transmission } {
	if { ![string_is_double $::dtransmission_coeff] } {
	    set ::dtransmission_coeff 0.0
	}
	if { ![string_is_double $::transmission_coeff] } {
	    set ::transmission_coeff 1.0
	}
	
	# scale by the transmission factor, if it is not 1
        octave eval "div = run_invscale(div, $::transmission_coeff, $::dtransmission_coeff);"
    }

    # footprint correction
    if { $::footprint_correction && $::reduce_head ne {} } {
	footprint::calc
	octave eval { refl = run_div(div,foot); }
    } else {
	octave eval { refl = div; }
    }

    # send back the results
    octave eval {
	run_send_pol('refl_%s', refl);
	run_send_pol('sub_%s', sub);
	run_send_pol('div_%s', div);
    }
    # send polarization correction parameters    
    octave eval { 
	send("foreach v {polx polf polr flipf flipr beta} {::$v delete :}");
	send("foreach v {polx polf polr flipf flipr beta} {::${v}raw delete :}");
	send("foreach v {slitfitA slitfitB slitfitC slitfitD} {::$v delete :}");
        if !isempty(cor)
	  send("polx",cor.x);
	  send("beta",cor.beta);
	  if struct_contains(cor,'polf')
	    send("polf",100*cor.polf);
	    send("polr",100*cor.polr);
	    send("flipf",100*cor.flipf);
	    send("flipr",100*cor.flipr);
	    send("slitfitA",cor.slitA);
	    send("slitfitB",cor.slitB);
	    send("slitfitC",cor.slitC);
	    send("slitfitD",cor.slitD);
	  endif
	  if struct_contains(cor,'z')
	    send(sprintf("reduce_slit_z %g",cor.z));
	  else
	    send("reduce_slit_z 0.");
	  endif
	  if struct_contains(cor,'raw')
	    send("polxraw",cor.raw.x);
	    send("betaraw",cor.raw.beta);
	    send("polfraw",100*cor.raw.polf);
	    send("polrraw",100*cor.raw.polr);
	    send("flipfraw",100*cor.raw.flipf);
	    send("fliprraw",100*cor.raw.flipr);
	  endif
        end 
    }
    # send slit values aligned with Q
    octave eval { 
        if isempty(slit) || !isfield(slit,'A') || isempty(sub)
	  run_send_pol('qslit_%s',[]);
        else
          r=slit;
          r.A.x=interp1(sub.A.m,sub.A.x,slit.A.x,'linear','extrap');
          r.B.x=interp1(sub.A.m,sub.B.x,slit.A.x,'linear','extrap');
          r.C.x=interp1(sub.A.m,sub.C.x,slit.A.x,'linear','extrap');
          r.D.x=interp1(sub.A.m,sub.D.x,slit.A.x,'linear','extrap');
          run_send_pol('qslit_%s',r);
        end
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
    set scanname [lindex [split [$w get $idx] :] 0]
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

# ======================================================

# This is just a macro for savescan.  It gets fid, log and rec
# from there
proc write_reduce { pol } {
    upvar spec spec
    upvar back back
    upvar slit slit
    upvar data data
    upvar rec rec
    upvar fid fid
    upvar log log
    upvar monitor monitor
    # Version info: #RRF $major $minor $appname $appversion for $arch
    puts $fid "#RRF 1 0 $::app_version"
    puts $fid "#date [clock format $rec(date) -format %Y-%m-%d]"
    puts $fid "#title \"$rec(comment)\""
    puts $fid "#instrument $rec(instrument)"
    puts $fid "#monitor $monitor"
    puts $fid "#temperature $rec(T)"
    puts $fid "#field $rec(H)"
    puts $fid "#wavelength $rec(L)"
    if {$pol ne {}} {
	puts $fid "\#polarization $pol"
    }

    # XXX FIXME XXX Hmmm... type might be Specular Background Slit scan ...
    # or it may be:
    #   Subtracted specular (if it includes spec and back) 
    #   Divided specular (if it includes spec and slit, and possibly back)
    #   Divided background (if it includes back and slit but not spec)
    #      this will require special processing during reduction in that
    #      subtraction will happen after slit scan rather than before.
    #   Reflectivity (if it includes footprint and polarization correction)
    #puts $fid "#type $rec(type)"
    #puts $fid "#xlabel $rec(xlab)"
    #puts $fid "#ylabel $rec(ylab)"

    # which runs make up the dataset?
    foreach type { spec back slit } {
	foreach id [set $type] {
            if { [info exists ::${id}(polarized)] } {
                set id [set ::${id}($pol)]
            }
            if { $id eq {} } { continue }
	    upvar #0 $id scanrec
#	    puts "writing scan #$id"
#	    puts [array get scanrec]
	    puts $fid "#$type $scanrec(files)"
	}
    }

    # XXX FIXME XXX move these to where they are actually calculated.  This
    # is especially important for footprint correction since the output is
    # dependent on the kind of footprint correction that is needed.
    if {$::calc_transmission} {
	puts $fid "#transmission coefficient [fix $::transmission_coeff {} {} 5]([fix $::dtransmission_coeff {} {} 5])"
    }
    if {$::footprint_correction} {
        puts $fid "#footprint [footprint::desc]"
    }
    
    write_data $fid ::$data -pol $pol
}

proc reduce_ext {} {
    upvar ext ext
    upvar data data
    upvar monitor monitor
    upvar spec spec
    upvar back back
    upvar slit slit
    
    # Determine the valid extensions.  These will depend on
    # the type since we need to distinguish between bg and avg bg for
    # some background runs and between spec, background subtraction,
    # slit corection and polarization correction), all with the same
    # prefix.
    set havespec [llength $spec]
    if { [info exists rec(psd)] } {
	set haveback [expr {[llength $back]>0 || $rec(psd)}]
    } else {
	set haveback [expr {[llength $back]>0}]
    }
    set haveslit [expr {[llength $slit]>0}]

    # if data has been scaled by intensity, monitor is now 1,
    # not the original monitor in the data record.
    set monitor $::reduce_monitor
    if {$haveslit || $::calc_transmission || $::footprint_correction} {
        # Normalized data is reflectivity, either specular
        # or off-specular, but still reflectivity.  The
        # final subtracted, normalized and footprint corrected
        # reflectivity will also use the .refl extension, so
        # there is potential for conflict.  Calling it .div if 
        # it is not footprint corrected would be reasonable, 
        # except that there are so many cases where people don't 
        # need to bother with footprint correction.
        # XXX FIXME XXX If workflow dictates that people regularly
        # save un-footprint corrected data, then go back and
        # apply footprint correction, then this default will have
        # to change.
        set monitor 1.
	set ext .refl
        set data refl
    } elseif {$havespec && $haveback} {
        # Unnormalized background subtraction.
	set ext .sub
	set data sub
    } elseif {$havespec} {
        # Only specular files, so still a specular file.
        # Calling it .add won't conflict with the base
        # .spec file, or with subsequent .sub or .refl
        # with the same name.
	set ext .add
	set data spec
    } elseif {$haveback} {
        # Only background files, so still a background file.
        # Calling it .add rather than .back won't overwrite
        # any of the input files.
	set ext .add
	set data back
    } elseif {$haveslit} {
        # Only slit files, so still a slit file.  Calling it
        # .add rather than .slit won't overwrite any of the
        # input files.
	set ext .add
	set data slit
    } else {
        error "nothing to write?"
    }
}

proc reduce_filename {} {
    upvar rec rec
    upvar opt opt
    upvar filename filename
    upvar ext ext
    upvar polarized polarized

    if {$polarized} { set pol A } { set pol {} }

    # Get the filename to use
    # XXX FIXME XXX will the user be surprised that the default format
    # is set by ::logaddrun?  Maybe we should add a log/linear option
    # for scripting control
    # XXX FIXME XXX need to be able to overwrite the title; the way to
    # do this is to move the title into a separate widget, but we will
    # have to add it to the graph before printing.  Maybe an EPS canvas?
    # Maybe nice to annotate the graphs as well.
#    if { $::logaddrun } {
#	set filename [file rootname $rec(file)]$logext$pol
#    } else {
	set filename [file rootname $rec(file)]$ext$pol
#    }
    if { [string equal $opt(-query) "all"] } {
	set filename [ tk_getSaveFile -defaultextension $ext$pol \
		-title "Save scan data" -parent .reduce ]
#		-filetypes [list [list Log $logext$pol] [list Linear $ext$pol]] ]
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

    if { $polarized && [string match {*.*[ABCDabcd]} $filename] } {
	set filename [string range $filename 0 end-1]
    }
}

# reduce_save [-query all|existing|none] [-record id] [-vector id]
proc reduce_save { args } {
    array set opt [list \
	    -query none \
	    -record $::reduce_head \
	    -vector refl_ ]
    array set opt $args
    upvar #0 $opt(-record) rec

    Selection_to_scanids spec back slit
    # XXX FIXME XXX save would like to be independent of GUI?
    set polarized $::reduce_polarized
    reduce_ext
    reduce_filename

    # Linear or log?
    set log [string equal [file extension $filename] .log]

    # Write the file
    if {$polarized} { set l {A B C D} } { set l {{}} }
    foreach pol $l {
        if { [catch { open $filename$pol w } fid] } {
            message -bell $fid
        } else {
            if { [catch { write_reduce $pol } msg] } {
                message -bell $msg
            } else {
                message "Saving data in $filename"
            }
            close $fid
        }
    }
}

# group all polarization cross-sections into a single 'scan'
proc reduce_polid { scanid } {
    upvar #0 $scanid scan
    # if not polarized, then don't need a new scanid
    if { ![info exists scan(polarization)] } { return $scanid }
    if { $scan(polarization) eq "" } { return $scanid }

    # Generate a new name by stripping the polarization
    # code off the end of the existing name.
    # XXX FIXME XXX something less hokey please!  Particularly,
    # we need to be able to load a dataset which already has
    # all four cross-sections.
    set pol [string toupper $scan(polarization)]
    set name [string range $scan(name) 0 end-1]
    if [info exists ::scanindex($name)] {
	set pid $::scanindex($name)
    } else {
        if { [info exists scan(psd)] } { set psd 1 } { set psd 0 }
	set pid scanp[incr ::scancount]
	array set ::$pid [list polarized 1 id $pid \
                              comment $scan(comment) \
			      monitor $scan(monitor) \
			      file [file rootname $scan(file)]. \
			      instrument $scan(instrument) \
			      name $name type $scan(type) \
			      index [string range $scan(index) 0 end-1] \
			      A {} B {} C {} D {} psd $psd ]
	set ::scanindex($name) $pid
    }
    set ::${pid}($pol) $scanid
    return $pid
}

proc reduce_lines { scanid } {
    upvar #0 $scanid scan
    if { ![info exists scan(polarized)] } { return $scanid }
    set ids {}
    foreach pol {A B C D} {
        if {$scan($pol) ne ""} { lappend ids $scan($pol) }
    }
    return $ids
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
    set scanid [reduce_polid $scanid]
    upvar #0 $scanid scanrec
    if { ![info exists scanrec(registered)] } {
	#puts "creating new scan entry"
	set item "$scanrec(name): $scanrec(comment)"
	# XXX FIXME XXX if scan is not a known type then we
	# need a way to kill it
	switch -- $scanrec(type) {
	    spec -
	    slit -
	    back { listbox_ordered_insert .reduce.$scanrec(type) $item }
	}
	set scanrec(registered) 1
    } elseif { ![string equal {} [.reduce.graph elem names $scanid]] } {
	#puts "updating existing scan entry"
	reduce_selection
    } else {
	#puts "scan already entered"
    }
}

proc reduce_clearscan { scanid } {
    # Note: works for pol scans automatically
    if { [string equal $scanid -all] } {
	foreach box { spec slit back } { .reduce.$box delete 0 end }
    } else {
	upvar #0 $scanid scanrec
    
	set item "$scanrec(name): $scanrec(comment)"
	switch -- $scanrec(type) {
	    spec -
	    slit -
	    back { listbox_delete_by_name .reduce.$scanrec(type) $item }
	}
    }
    reduce_selection
}

proc convertscan { scanid } {
    # Note: works for pol scans automatically
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
    set item "$scanrec(name): $scanrec(comment)"
    listbox_delete_by_name .reduce.$scanrec(type) $item
    set scanrec(type) $newtype
    set scanrec(index) $newindex
    listbox_ordered_insert .reduce.$scanrec(type) $item
    reduce_selection
}

# initialize if haven't already done so
if {![winfo exists .reduce]} { 
    reduce_init
    source [file join $::VIEWRUN_HOME footprint.tcl]
    footprint::init
}

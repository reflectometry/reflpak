namespace eval footprint {

    variable mfiles { 
        footprint_gen.m
        footprint_interp.m
        footprint_fit.m
    }
    variable fp .footprint
    variable opening_slits {}

proc init {} {
    set ::footprint_line {}
    set ::footprint_m {}
    set ::footprint_b {}
    set ::footprint_dm {}
    set ::footprint_db {}
    set ::footprint_Qmin {}
    set ::footprint_Qmax {}
    set ::footprint_correction 0
    set ::footprint_correction_type fit
    set ::fit_footprint_correction 0
    set ::fit_footprint_style 'line'
    set ::fit_footprint_Qmin {}
    set ::fit_footprint_Qmax {}
    set ::footprint_at_Qmax {}
    set ::footprint_Q_at_one {}
    variable mfiles
    foreach f $mfiles { 
        octave mfile [file join $::VIEWRUN_HOME octave $f]
    }
}

proc desc {} {
    switch $::footprint_correction_type {
        fit -
        fix {
            return "[fix $::footprint_m {} {} 5]([fix $::footprint_dm {} {} 5]) + [fix $::footprint_b {} {} 5]([fix $::footprint_db {} {} 5]) from Qz=[fix $::footprint_Qmin {} {} 5] to Qz=[fix $::footprint_Qmax {} {} 5], [fix $::footprint_at_Qmax {} {} 5]([fix $::footprint_at_Qmax_err {} {} 5]) above"
        }
        div {
            return "divided by [set ::${::footprint_line}(file)]"
        }
    }
}

proc draw {} {
    variable fp
    if { [winfo exists $fp] } {
	raise $fp
	return
    }
    set width 8
    
    toplevel $fp
    wm title $fp "Footprint correction"
    sizer $fp

    # set up the graph
    opt $fp.graph Height 200 \
        y.title "Normalized reflectivity" \
        x.title "Q ($::symbol(invangstrom))"
    foreach line { footp footm } {
        opt $fp.graph.$line Color darkred LineWidth 1 \
            Pixels 0 Dashes {7 3} Label {} Symbol {}
    }
    opt $fp.graph.foot Label Footprint Color darkred \
        LineWidth 1 Pixels 0 Symbol {}

    graph $fp.graph
    Blt_ZoomStack $fp.graph
    active_axis $fp.graph y
    vector create ::foot_x ::foot_y ::foot_dy ::foot_yp ::foot_ym
    $fp.graph element create foot -xdata ::foot_x -ydata ::foot_y
    $fp.graph element create footp -xdata ::foot_x -ydata ::foot_yp
    $fp.graph element create footm -xdata ::foot_x -ydata ::foot_ym
    legend_set $fp.graph foot on
    set colors [option get $fp.graph lineColors LineColors]
    foreach pol { {} A D } color [lrange $colors 0 2] {
        opt $fp.graph.div$pol Pixels 4 Fill $color \
            LineWidth 0 Label "Data $pol" Color $color
	$fp.graph element create div$pol \
	    -xdata ::div_x$pol -ydata ::div_y$pol -yerror ::div_dy$pol
	legend_set $fp.graph div$pol on
    }
    active_legend $fp.graph

    
    radiobutton $fp.auto -variable ::footprint_correction_type -value fit \
	-text "Fit footprint correction"

    set fpfs [frame $fp.fitstyle]
    label $fpfs.fit -text "Fit"
    radiobutton $fpfs.origin -variable ::fit_footprint_style \
	-value 'slope' -text "m*Qz"
    radiobutton $fpfs.plateau -variable ::fit_footprint_style \
	-value 'plateau' -text "b"
    radiobutton $fpfs.line -variable ::fit_footprint_style \
	-value 'line' -text "m*Qz+b"
    pack $fpfs.fit $fpfs.line $fpfs.origin $fpfs.plateau -side left

    set fpfr [frame $fp.fitrange]
    entry $fpfr.min -textvariable ::fit_footprint_Qmin -width $width
    entry $fpfr.max -textvariable ::fit_footprint_Qmax -width $width
    label $fpfr.from -text "Fit from Qz"
    label $fpfr.to -text "$::symbol(invangstrom) to Qz"
    label $fpfr.units -text "$::symbol(invangstrom)"
    button $fpfr.click -text "From graph..." -command [subst {
	graph_select $fp.graph ::fit_footprint_Qmin ::fit_footprint_Qmax
    }]
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
    ComboBox $fp.div.spec -editable no -postcommand \
	"$fp.div.spec configure -values \$::available_spec"
    $fp.div.spec configure -modifycmd \
	"footprint::line \[$fp.div.spec cget -text]"
    pack $fp.div.lab $fp.div.spec -side left

    set fpar [frame $fp.applyrange]
    entry $fpar.min -textvariable ::footprint_Qmin -width $width
    entry $fpar.max -textvariable ::footprint_Qmax -width $width
    label $fpar.from -text "Correct from Qz"
    label $fpar.to -text "$::symbol(invangstrom) to Qz"
    label $fpar.units -text "$::symbol(invangstrom)"
    button $fpar.click -text "From graph..." -command [subst {
	graph_select $fp.graph ::footprint_Qmin ::footprint_Qmax
    }]
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

    button $fp.calc -text Calc \
        -command [namespace code calc]
    button $fp.apply -text Apply -command {
	set ::footprint_correction 1
	reduce_selection
    }

    grid $fp.graph - - - - - -sticky news
    grid $fp.auto - - - - - -sticky sw
    grid x $fpfs - - - - -sticky w
    grid x $fpfr - - - - -sticky ew
    grid $fp.manual - - - - - -sticky sw
    grid x $fp.mlab $fp.m $fp.dmlab $fp.dm x -sticky ew
    grid x $fp.blab $fp.b $fp.dblab $fp.db $fp.bunits -sticky ew
    grid $fp.div - - - - -sticky ew
    grid $fpar - - - - - -sticky sew
    grid $fpcr - - - - - -sticky sew
    grid $fpone - - - $fp.calc $fp.apply -sticky sew

    #set ::message {}
    #label $fp.message -relief ridge -anchor w -textvariable ::footprint_message
    #grid $fp.message - - - - - -sticky we

    # resizable graph
    grid rowconfigure $fp 0 -weight 1
    # force indent relative to the radio buttons
    grid columnconfigure $fp 0 -minsize 20
    # force Slope/Itercept to be left justified
    grid configure $fp.mlab $fp.blab -sticky w
    # space between the sections
    grid rowconfigure $fp 1 -pad 10
    foreach row { 4 7 8 9 } { grid rowconfigure $fp $row -pad 15 }
    # column stretch
    foreach col { 2 4 } { grid columnconfigure $fp $col -weight 1 }
    pack conf $fpar.min $fpar.max $fpfr.min $fpfr.max -fill x -expand yes

    variable opening_slits
    draw_opening_slits $opening_slits
}

# Indicate on the footprint graph where the slits are opening using the
# {start1 stop1 start2 stop2 ...} information in edges.
proc draw_opening_slits {edges} {
    variable fp
    if { [winfo exists $fp] } {
	eval [linsert [$fp.graph marker names] 0 $fp.graph marker delete]
	foreach {start stop} $edges {
	    $fp.graph marker create polygon -under true \
		-coords [list $start -Inf $start Inf $stop Inf $stop -Inf] \
		-fill AntiqueWhite
	    $fp.graph marker create text \
		-coords [list $start -Inf] -anchor sw -text "opening slits"
	}
    }
}

# Walk through a list of paired Q,slit values sorted by Q, returning
# those ranges of Q for which the slits are moving as a a list of
# {start1 stop1 start2 stop2 ...}.
proc find_opening_slits {Q M} {
    set state 0
    set edges {}
    foreach q $Q m $M {
	switch $state {
	    0 {
		# first Q
		set state 1
	    }
	    1 {
		# Not in run
		if {$curM != $m} {
		    lappend edges $curQ
		    set state 2
		}
	    }
	    2 {
		# In run, see if we can extend it
		if {$curM == $m && $curQ != $q} {
		    lappend edges $curQ
		    set state 1
		}
	    }
	}
	set curM $m
	set curQ $q
    }
    if {$state == 2} { lappend edges $curQ }
    return $edges
}

proc slits { Q m } {
    variable opening_slits [find_opening_slits $Q $m]
}

proc line { name } {
    # prep the scan associated with the footprint line name
    set name [lindex [split $name :] 0]
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

proc calc {{div div} {foot foot}} {
    if {$div ne "div" || $foot ne "foot"} { 
        error "Use \[footprint::update div foot] for now"
    }    
    octave eval { foot = [] }
    foreach v { x y dy yp ym } { ::foot_$v delete : }

    switch $::footprint_correction_type {
	fit {
	    if { ![string_is_double $::fit_footprint_Qmin] || \
		    ![string_is_double $::fit_footprint_Qmax] } {
		set ::message "Invalid footprint fit Q range"
		return
	    }
	    octave eval [subst -nocommand {
                [p,dp] = footprint_fit(div,$::fit_footprint_Qmin,
                    $::fit_footprint_Qmax,$::fit_footprint_style);
		send(sprintf('set ::footprint_m  %.15g', p(1)));
		send(sprintf('set ::footprint_dm %.15g',dp(1)));
		send(sprintf('set ::footprint_b  %.15g', p(2)));
		send(sprintf('set ::footprint_db %.15g',dp(2)));
	    }]
	}
	fix {
	    if {$::footprint_b eq ""} { set ::footprint_b 0.0 }
	    if {$::footprint_db eq ""} { set ::footprint_db 0.0 }
	    if {$::footprint_dm eq ""} { set ::footprint_dm 0.0 }
	    if { ![string_is_double $::footprint_m] || \
		    ![string_is_double $::footprint_dm] || \
		    ![string_is_double $::footprint_b] || \
		    ![string_is_double $::footprint_db] } {
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
	    if { ![string_is_double $::footprint_Qmin] || \
		    ![string_is_double $::footprint_Qmax] } {
		set ::message "Invalid footprint application Q range"
		return
	    }

	    octave eval [subst -nocommand {
                Qmin = $::footprint_Qmin;
                Qmax = $::footprint_Qmax;
                foot=footprint_gen(div,p,dp,Qmin,Qmax);
		send(sprintf('set footprint_Q_at_one %.15g', (1-p(2))/p(1)));
		send(sprintf('set footprint_at_Qmax %.15g', polyval(p,Qmax)));
		send(sprintf('set footprint_at_Qmax_err %.15g', 
                    sqrt(polyval(dp.^2,Qmax.^2))));
	    }]
	}
	div {
	    if { ![llength $::footprint_line]} {
		set ::message "No footprint line selected"
		return
	    }
	    set ::footprint_Q_at_one {}
	    octave eval "foot=footprint_interp(div,$::footprint_line)"
	}
    }

    # send results
    #octave eval { run_send_pol('foot_%s', foot); }
    
    # send display result
    octave eval {
        if !isempty(foot)
            if isfield(foot,'A')
                run_send('foot_%s', foot.A);
            else
                run_send('foot_%s', foot);
            end
        end
        send('::foot_yp expr {::foot_y+::foot_dy}');
        send('::foot_ym expr {::foot_y-::foot_dy}');
    }
}

}

if {$argv0 eq [info script] && ![info exists running]} {
    set running 1

    # Get needed library context
    lappend auto_path [file dirname $argv0]/..
    package require Tk
    package require BLT
    package require ncnrlib
    package require octave
    package require BWidget
    package require tkcon
    namespace import blt::vector blt::graph

    set ::VIEWRUN_HOME [file dirname $argv0]
    load_resources $::VIEWRUN_HOME tkviewrun
    # open octave connection
    octave connect 1515
    foreach file {wpolyfit wsolve polyconf interp1err run_send } { 
        octave mfile $::VIEWRUN_HOME/octave/$file.m
    }
    
    # set up some data
    foreach pol { {} A D } {
        vector create ::div_x$pol ::div_y$pol ::div_dy$pol ::div_m$pol
    }
    set pol A
    div_x$pol set { 1 2 3 4 5 6 7 8 9 10 }
    div_m$pol set { 1 1 1 1 1 1 2 3 4 4  }
    div_y$pol set { 1.03 1.92 3.05 3.93 3.99 3.5  3.1  2.8  2.1  1.4 }
    div_dy$pol set { .06  .07  .08  .09  .09  .08  .07  .07  .07  .06 }
    div_y$pol expr div_y$pol/5
    div_dy$pol expr div_dy$pol/5
    if { $pol ne {} } { 
        octave send ::div_xA div.A.x
        octave send ::div_yA div.A.y
        octave send ::div_dyA div.A.dy
        octave eval { div.B = div.C = div.D = []; }
    } {
        octave send ::div_x div.x
        octave send ::div_y div.y
        octave send ::div_dy div.dy
    }
    set ::available_spec {}

    # set up debugging tools
    tkcon show
    proc disp x { 
        octave eval { retval='\n' }
        octave eval "retval=$x"
        octave eval { send(sprintf('set ::ans {%s}',disp(retval))) }
        vwait ::ans 
        return [string range $::ans 0 end-1]
    }
    
    # all so that we can try two little lines
    footprint::init
    footprint::draw
}

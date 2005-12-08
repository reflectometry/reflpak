namespace eval ::psd {
    variable id
    variable logscale
    variable coords
    # use { qzslice binslice } for all
    variable fix_counts {}
    variable minnz
    variable mincounts
    variable maxcounts
    variable minbin
    variable maxbin
    variable minQz
    variable maxQz
    variable skew 0.0
    variable binidx {}
    variable drawn 0
    image create photo ::psd::matrix
    image create photo ::psd::colorbar
}



vector create psd_bin psd_bin_counts psd_bin_err \
	psd_Qz psd_Qz_counts psd_Qz_err \
	psd_select1_counts psd_select1_err \
	psd_select2_counts psd_select2_err \
	psd_spec_y psd_spec_dy psd_back_y psd_back_dy \
        psd_reduce_y psd_reduce_dy psd_x

# ****************** Create graphs ******************************

# Assumes Qz, psd and psderr are already defined in the octave toplevel.
# Raises the psd window loaded with the psd data.
proc psd {id} {

    if {[string equal $id clear]} {
	::psd::clear
	return
    }

    set ::psd::id $id
    ::psd::init
    wm title .psd "PSD [set ::${id}(file)] ($id)"

    # send Qz index
    octave send ::x_$id Qz

    # correct matrix if presented in reverse order
    octave eval "
 	if Qz(1) > Qz(length(Qz))
	  Qz = flipud(Qz(:));
	  psd_$id = flipud(psd_$id);
	  send('x_$id',Qz);
	endif
    "
    octave eval "psd = psd_$id;"
    octave eval "psderr = psderr_$id;"
    ::psd::draw_matrix
    ::psd::reset_axes
    ::psd::integrate
    ::psd::set_lines
}

proc ::psd::clear {} {
    if { $::psd::drawn } {
	set ::psd::drawn 0
	.psd.matrix marker delete [.psd.matrix marker names]
	.psd.matrix axis conf Qz -min {} -max {}
	.psd.matrix axis conf bin -min {} -max {}
	foreach v { Qz Qz_counts Qz_err bin bin_counts bin_err } {
	    ::psd_$v set {}
	}
    }
}

proc ::psd::reset_axes {} {

    variable minbin
    variable maxbin
    variable minQz
    variable maxQz

    # initial zoom
    # XXX FIXME XXX need to clear the BLT zoom stack
    .psd.matrix axis configure Qz -min $minQz -max $maxQz
    .psd.matrix axis configure bin -min $minbin -max $maxbin
    .psd.qzslice axis configure bin -min {} -max {}

    # Draw the current slices with the appropriate zoom
    zoom_slice

}


proc ::psd::init {} {
    if { [winfo exists .psd] } { 
	wm deiconify .psd
	raise .psd
	return
    }

    toplevel .psd
    # XXX FIXME XXX need a way to reopen the psd window if the
    # user closes it, and to switch between sections of the psd
    # that are displayed.  Perhaps want a way to display the
    # combined psd.
    wm protocol .psd WM_DELETE_WINDOW { wm withdraw .psd }
    bind .psd <Destroy> { }

    # coordinate labels
    label .psd.coords -textvariable ::psd::coords -relief ridge

    # graph of 2D data, 1D slices and reduction
    graph .psd.matrix
    graph .psd.binslice
    graph .psd.qzslice
    graph .psd.reduction

    # colormap
    frame .psd.colormap
    label .psd.colormap.label -text "Color Map"
    ComboBox .psd.colormap.entry \
	    -textvariable ::psd::colormap_expr \
	-values [load_colormaps] \
	    -modifycmd { ::psd::colormap } \
	    -command { ::psd::colormap }
    graph .psd.colormap.bar
    grid .psd.colormap.label 
    grid .psd.colormap.entry
    grid .psd.colormap.bar
    # set initial colormap
    colormap [option get .psd.matrix colormap Colormap]

    # Create named axes
    .psd.matrix axis create Qz
    .psd.matrix axis create bin
    .psd.binslice axis create Qz
    .psd.binslice axis create counts -rotate 90
    .psd.qzslice axis create bin
    .psd.qzslice axis create counts
    .psd.colormap.bar axis create counts
    .psd.reduction axis create Qz
    .psd.reduction axis create counts

    # hide the usual x-y axes
    foreach w { matrix binslice qzslice colormap.bar reduction } {
	.psd.$w xaxis configure -hide 1
	.psd.$w yaxis configure -hide 1
    }

    # Use x2-y for the image, x2-y2 for the Y slice and x-y for the X slice
    # Fix margin sizes so that scales are commensurate between the graphs
    .psd.matrix x2axis use bin
    .psd.matrix yaxis use Qz
    .psd.binslice y2axis use counts
    .psd.binslice x2axis use Qz
    .psd.qzslice xaxis use bin
    .psd.qzslice yaxis use counts
    .psd.colormap.bar y2axis use counts
    .psd.reduction xaxis use Qz
    .psd.reduction y2axis use counts

    # Add x and y slices

    .psd.binslice element create slice -label "bin #" \
	    -xdata ::psd_Qz -ydata ::psd_Qz_counts -mapx Qz -mapy counts
    .psd.qzslice element create slice -label "Qz ($::symbol(invangstrom)" \
	    -xdata ::psd_bin -ydata ::psd_bin_counts -mapx bin -mapy counts
    if [blt_errorbars] {
	.psd.binslice elem conf slice -yerror ::psd_Qz_err -showerrorbar y
	.psd.qzslice elem conf slice -yerror ::psd_bin_err -showerrorbar y
    }
    .psd.matrix marker create line -name binslice -mapx bin -mapy Qz
    .psd.matrix marker create line -name qzslice -mapx bin -mapy Qz -bindtags skew

    # Add reduction graph lines
    foreach {el lab} { spec "Specular" back "Background" reduce "Reduction" } {
	.psd.reduction element create $el -label $lab \
		-xdata ::psd_x -ydata ::psd_${el}_y -mapx Qz -mapy counts
	if [blt_errorbars] {
	    .psd.reduction element conf $el -yerror ::psd_${el}_dy \
		    -showerrorbar y
	}
    }
    # Allow user to click on/off legend entries
    active_legend .psd.reduction
    active_axis .psd.reduction counts


    # Note: relying on the fact that x-y defaults to range 0,1 when
    # pasting images into .psd.colorbar
    bind_slice

    bind .psd.matrix <Motion> { ::psd::coords %x %y }
    bind .psd.binslice <Motion> { ::psd::slice_coords %W %y %x }
    bind .psd.qzslice <Motion> { ::psd::slice_coords %W %x %y }

    # if user zooms in image, then zoom in slices
    bind .psd.matrix <ButtonPress-3> { ::psd::zoom_slice }
    bind .psd.matrix <ButtonPress-1> { ::psd::zoom_slice }

    bind .psd.matrix <Shift-ButtonPress-3> { PrintDialog %W }

    Blt_ZoomStack .psd.matrix
    Blt_ZoomStack .psd.reduction
    Blt_ZoomStack .psd.qzslice
    Blt_ZoomStack .psd.binslice
    
    # Make sure the legends are showing in the slice boxes, because that's
    # where we are going to show the slice coordinates
    .psd.binslice legend configure -position plotarea -anchor ne
    .psd.qzslice legend configure -position plotarea -anchor ne
    .psd.reduction legend configure -position plotarea -anchor ne

    # Logscale toggle
    variable logscale
    set logscale [string is true [option get .psd.matrix logscale Logscale]]
    foreach w {qzslice binslice colormap.bar} {
	.psd.$w axis configure counts -logscale $logscale
	.psd.$w axis bind counts <Enter> {
	    %W axis configure counts -background lightblue2
	}
	.psd.$w axis bind counts <Leave> {
	    %W axis configure counts -background ""
	}
	.psd.$w axis bind counts <1> {
	    ::psd::toggle_logscale
	}
    }

    octave eval {
	function idx = nearest(V,x)
	idx = interp1(V,1:length(V),x,'nearest','extrap');
	end
    }

    # initial specular selection
    ::psd::init_select


    # Define layout
    #      0         1         2
    # 0  matrix  binslice  colormap
    # 1  qzslice reduction---------
    # 2  coords--------------------
    grid .psd.matrix    -row 0 -column 0 -sticky news
    grid .psd.binslice  -row 0 -column 1 -sticky news
    grid .psd.colormap  -row 0 -column 2 -sticky news
    grid .psd.qzslice   -row 1 -column 0 -sticky news
    grid .psd.reduction -row 1 -column 1 -columnspan 2 -sticky news
    grid .psd.coords    -row 2 -column 0 -columnspan 3 -sticky ew

    # Set initial sizes and stretch
if 0 {
    .psd.matrix conf -height 300 -width 300
    .psd.reduction conf -height 200 -width 250
    .psd.binslice conf -width 200
    .psd.qzslice conf -height 200
    .psd.colormap.bar conf -width 100
}
    # XXX FIXME XXX make BWidget respect resources
    .psd.colormap.entry configure -width 10
    grid rowconfigure    .psd 0 -weight 2 -minsize 150
    grid columnconfigure .psd 0 -weight 2 -minsize 150
    grid rowconfigure    .psd 1 -weight 1
    grid columnconfigure .psd 1 -weight 1
}

if 0 {
    # Set margins so that graphs are aligned
    .psd.matrix configure -plotpadx 0 -plotpady 0 \
	    -leftmargin 50 -topmargin 50 -rightmargin 0 -bottommargin 0
    .psd.binslice configure -invertxy true \
	    -plotpadx 0 -plotpady 0 \
	    -rightmargin 50 -topmargin 50 -leftmargin 0 -bottommargin 0
    .psd.qzslice configure -plotpadx 0 -plotpady 0 \
	    -leftmargin 50 -bottommargin 50 -rightmargin 0 -topmargin 0
    .psd.reduction configure  -plotpadx 0 -plotpady 0 \
	    -leftmargin 0 -bottommargin 50 -rightmargin 50 -topmargin 0
    .psd.colormap.bar configure -plotpadx 0 -plotpady 0 \
	    -leftmargin 0 -bottommargin 0 -rightmargin 50 -topmargin 0
}


proc ::psd::init_select {} {

    .psd.matrix marker bind handle <B1-Motion> { ::psd::select %x %y drag }
    .psd.matrix marker bind handle <Button-1> { zoom %W off; ::psd::select %x %y drag_start }
    .psd.matrix marker bind handle <ButtonRelease-1> { zoom %W on; ::psd::select %x %y drag_end }

    foreach h { select1 select2 } {
	.psd.matrix marker create line -name $h -mapx bin -mapy Qz -bindtags handle
	.psd.binslice elem create $h -xdata ::psd_Qz \
		-ydata ::psd_${h}_counts -mapx Qz -mapy counts
	if [blt_errorbars] {
	    .psd.binslice elem conf $h -yerror ::psd_${h}_err
	}
    }
    default_select
}

proc ::psd::default_select {} {
    set ::psd::select1m 0
    set ::psd::select2m 0
    set ::psd::select1b 106
    set ::psd::select2b 130
}

proc ::psd::find_select {} {
    default_select
    integrate
    set_lines
}

proc ::psd::hide_select {hide} {
    .psd.binslice elem conf select1 -hide $hide
    .psd.binslice elem conf select2 -hide $hide
}

proc ::psd::select { x y action } {
    hide_slice 1
    hide_select 0
    variable drag
    switch -- $action {
	drag_start {
	    set drag(marker) [.psd.matrix marker get current]
	    foreach {x1 y1 x2 y2} [.psd.matrix marker cget $drag(marker) -coords] break

	    set x1 [.psd.matrix axis transform bin $x1]
	    set x2 [.psd.matrix axis transform bin $x2]
	    set y1 [.psd.matrix axis transform Qz $y1]
	    set y2 [.psd.matrix axis transform Qz $y2]
	    set end1 [vector expr sqrt(($x1-$x)^2+($y1-$y)^2)]
	    set end2 [vector expr sqrt(($x2-$x)^2+($y2-$y)^2)]
	    if { $end1 < ($end1+$end2)/5. } {
		set drag(index) 0
	    } elseif { $end2 < ($end1+$end2)/5. } {
		set drag(index) 1
	    } else {
		set drag(index) {}
	    }
	}
	drag_end {}
	drag {
	    set bin [.psd.matrix axis invtransform bin $x]
	    set Qz [.psd.matrix axis invtransform Qz $y]
	    variable select1m
	    variable select2m
	    variable select1b
	    variable select2b
	    variable minQz
	    variable maxQz
	    upvar 0 $drag(marker)m m
	    upvar 0 $drag(marker)b b

	    foreach {x1 y1 x2 y2} [.psd.matrix marker cget $drag(marker) -coords] break
	    switch $drag(index) {
		0  { set m [expr { double($bin - $x2)/($Qz - $y2) }] }
		1  { set m [expr { double($bin - $x1)/($Qz - $y1) }] }
	    }
	    set b [expr { $bin - $Qz*$m } ]

	    set_lines
	    update idletasks

	    octave sync ::psd::integrate $select1m $select1b $select2m $select2b
	}
	default { error "unknown action $action" }
    }
}

# HELP internal
# Usage: psd::set_lines
#
# Position the integration lines on the psd matrix
proc ::psd::set_lines {} {
    variable select1m
    variable select1b
    variable select2m
    variable select2b
    variable minQz
    variable maxQz
    set lo $minQz
    set hi $maxQz
    .psd.matrix marker conf select1 -coords \
	[list [expr {$select1m*$lo+$select1b}] $lo \
	     [expr {$select1m*$hi+$select1b}] $hi]
    .psd.matrix marker conf select2 -coords \
	[list [expr {$select2m*$lo+$select2b}] $lo \
	     [expr {$select2m*$hi+$select2b}] $hi]
}

proc ::psd::integrate {args} {
    variable id
    variable select1m
    variable select1b
    variable select2m
    variable select2b

    octave eval [subst {
        select1m=$select1m; 
        select1b=$select1b;
        select2m=$select2m;
        select2b=$select2b;
    }]
    
    octave eval {
	n = columns(psd);

	# Find the lines of integration
	from = clip(round(select1m*Qz + select1b),[1,n]);
	to = clip(round(select2m*Qz + select2b),[1,n]);

	# Make sure we are integrating between the lines
	swapidx = (from>to);
	swap = from(swapidx);
	from(swapidx) = to(swapidx);
	to(swapidx) = swap;

	# Make the background area equal to the specular area
	width = (to-from+1)/2;
	bgfrom = max(1, from-floor(width));
	bgto = min(n, to+ceil(width));

	# Integrate the specular and the background+specular
	slicefrom = sliceto = dslicefrom = dsliceto = psd(:,1);
	spec = y = d2spec = d2y = psd(:,1);
	for i=1:rows(psd)
	  slicefrom(i) = psd(i,from(i));
	  sliceto(i) = psd(i,to(i));
	  dslicefrom(i) = psderr(i,from(i));
	  dsliceto(i) = psderr(i,to(i));
	  spec(i) = sum(psd(i,from(i):to(i)));
	  y(i) = sum(psd(i,bgfrom(i):bgto(i)));
	  d2spec(i) = sumsq(psderr(i,from(i):to(i)));
	  d2y(i) = sumsq(psderr(i,bgfrom(i):bgto(i)));
        end

	# Extract specular, background and reflectivity
	back = y - spec;
	y = spec - back;
	d2back = d2y - d2spec;
    }
    octave recv y_$id y
    octave recv dy_$id sqrt(d2y)
    octave recv psd_spec_y spec
    octave recv psd_back_y back
    octave recv psd_spec_dy sqrt(d2spec)
    octave recv psd_back_dy sqrt(d2back)
    octave recv psd_select1_counts slicefrom
    octave recv psd_select1_err dslicefrom
    octave recv psd_select2_counts sliceto
    octave recv psd_select2_err dsliceto
    octave eval "
      send('::y_$id dup ::psd_reduce_y');
      send('::dy_$id dup ::psd_reduce_dy');
      send('::counts_$id expr ::y_$id*::monitor_$id');
      send('::dcounts_$id expr ::dy_$id*::monitor_$id');
    "
    octave eval { send('atten_set $::addrun'); }
}


# ************** Define configurion control frame *****************

proc ::psd::colormap { { expr {} } } {
    if { [string length $expr] > 0 } {
	set ::psd::colormap_expr $expr
    }
    set_colormap $::psd::colormap_expr
    octave recv ::psd::colorbar { [1:rows(colormap)]' }
    octave eval {
	send('.psd.colormap.bar marker create image -name colorbar -image ::psd::colorbar -under 0 -coords { 0 0 1 1 }');
    }

    # reload the matrix with the new colormap
    if { $::psd::drawn } { ::psd::draw_matrix }
}
 


# ************************* Graph interactions ***********************

proc ::psd::toggle_logscale {} {
    variable logscale
    set logscale [expr 1 - $logscale]
    ::psd::draw_matrix
}

proc ::psd::draw_matrix { } {

    variable minQz
    variable maxQz
    variable minbin
    variable maxbin
    variable minnz
    variable mincounts
    variable maxcounts
    variable logscale

    # Get the data range from octave
    octave eval { minnz = min(psd(psd>0)); if isempty(minnz), minnz=1; end }
    octave eval { 
	if length(Qz) > 1
	  minQz = ( 3*Qz(1) - Qz(2) ) / 2;
	  maxQz = ( 3*Qz(length(Qz)) - Qz(length(Qz)-1) ) / 2;
	elseif Qz==0
	  minQz = 0;
	  maxQz = 1;
	else
	  minQz = Qz(1)/2;
	  maxQz = 3*Qz(1)/2;
	endif
    }
    octave recv psd::minnz minnz
    octave recv psd::maxcounts max(psd(:)+psderr(:))
    # Note: assuming that the index values into the image cells refer to a
    # corner of the cell rather than the center.  If we want the center, then
    # we will need to subtract one half the cell width/height from the 
    # min/max of bin/Qz.
    octave recv psd::minbin 0.5
    octave recv psd::minQz minQz
    octave recv psd::maxbin { columns(psd)+0.5 }
    octave recv psd::maxQz maxQz

    # XXX FIXME XXX quick hack to get psd selector ranges working
    # Need an initial Qz to attach to the xdata for the selector slices
    # Alternatively, set the initial crosshairs.
    # Don't know why we need binidx
    octave recv psd_x Qz
    octave eval { binidx=128; } 

    # Request new matrix image from octave and wait for it
    if { $logscale } {
	# XXX FIXME XXX make sure that imagesc(log10) corresponds
	# to the logscale on the colorbar
	octave recv ::psd::matrix imagesc(log10(psd+minnz))
    } else {
	octave recv ::psd::matrix imagesc(psd)
    }
    octave sync

if 0 {
    # Clear crosshairs (necessary because they may be xor'd).
    foreach line { binslice qzslice select1 select2 } {
	if { [llength [.psd.matrix marker names $line]] > 0 } {
	    set pos($line) [.psd.matrix marker cget $line -coords]
	    set bindtags($line) [.psd.matrix marker cget $line -bindtags]
	}
	.psd.matrix marker delete $line
    }
}

    # Paste matrix image into the graph
    .psd.matrix marker create image -name matrix -image ::psd::matrix \
	    -coords [list $minbin $minQz $maxbin $maxQz ] \
	    -mapx bin -mapy Qz -under 1

if 0 {
    # Restore crosshairs
    foreach line [array names pos] {
	.psd.matrix marker create line -name $line -under 0 \
		-mapx bin -mapy Qz -coords $pos($line) \
		-bindtags $bindtags($line)
    }
}

    # Make sure the min counts reflects the matrix min counts
    if { $logscale } {
	set mincounts $minnz
    } else {
	set mincounts 0
    }

    # Set logscale count axes and logscale colorbar range and fix
    # the limits on the X/Y slices so that you can compare heights
    # easily by dragging the mouse
    .psd.colormap.bar axis configure counts -logscale $logscale \
	    -min $mincounts -max $maxcounts
    .psd.reduction axis configure counts -logscale $logscale
    foreach w { binslice qzslice } {
	if { [lsearch $::psd::fix_counts $w] > 0 } {
	    .psd.$w axis configure counts -logscale $logscale \
		    -min $mincounts -max $maxcounts
	} else {
	    .psd.$w axis configure counts -logscale $logscale \
		    -min {} -max {}
	}
    }

    set ::psd::drawn 1
}

proc ::psd::coords { x y } {
    if {! $::psd::drawn } { return }

    # convert x coordinate into a bin index
    # convert y coordinate into a Qz index
    set bin [.psd.matrix axis invtransform bin $x]
    set qz [.psd.matrix axis invtransform Qz $y]

    # display coordinates in psd window
    variable coords "bin [expr {floor($bin+0.5)}], Qz [fix $qz]"
}

proc ::psd::slice_coords { w x y } {
	$w element closest $x $y where
	if { [info exists where(x)] } {
	    variable coords "[fix $where(x)], [fix $where(y) {} {} 5]"
	} else {
	    variable coords ""
	}
}


proc ::psd::zoom_slice { } {

    foreach { a x } { Qz min Qz max bin min bin max } {
	set t$x$a [.psd.matrix axis cget $a -$x]
    }
    .psd.binslice axis conf Qz -min $tminQz -max $tmaxQz
    .psd.qzslice axis conf bin -min $tminbin -max $tmaxbin
}

proc ::psd::hide_slice { hide } {
    .psd.matrix marker conf binslice -hide $hide
    .psd.matrix marker conf qzslice -hide $hide
    .psd.binslice elem conf slice -hide $hide
    .psd.qzslice elem conf slice -hide $hide
}

proc ::psd::bind_slice { } {
    bind .psd.matrix <B2-Motion> { ::psd::drag_slice drag %x %y }
    bind .psd.matrix <ButtonPress-2> { ::psd::drag_slice center %x %y }
    bind .psd.matrix <Shift-ButtonPress-2> { ::psd::drag_slice skew %x %y }
    bind .psd.matrix <Alt-B3-Motion> { ::psd::drag_slice drag %x %y }
    bind .psd.matrix <Alt-ButtonPress-3> { ::psd::drag_slice center %x %y }
    bind .psd.matrix <Alt-Shift-ButtonPress-3> { ::psd::drag_slice skew %x %y }
}

proc ::psd::drag_slice { action x y } {
    if {! $::psd::drawn } { return }

    variable skew
    variable bincross
    variable Qzcross
    variable slice_action
    variable minbin
    variable maxbin

    # Hide the integration lines
    hide_select 1
    hide_slice 0

    # Remember whether we are dragging center or skew
    if { [string equal $action drag] } {
	set action $slice_action
    } else {
	set slice_action $action
    }

    # Find new location
    set bin [.psd.matrix axis invtransform bin $x]
    set qz [.psd.matrix axis invtransform Qz $y]
 
    if { [string equal $action skew] } {
	# If changing skew, calculate new skew
	set skew [expr {double($qz-$Qzcross)/($bin-$bincross)}]
    } else {
	# If changing center, remember new center
	set bincross $bin
	set Qzcross $qz

	# Set the crosshair for the vertical.
	.psd.matrix marker conf binslice \
		-coords [list $bincross $::psd_x(0) $bincross $::psd_x(end)]
    }

    # Set crosshair for the horizontal
    .psd.matrix marker conf qzslice \
	    -coords [list $minbin [expr {$skew*($minbin-$bincross) + $Qzcross}] \
	                $maxbin [expr {$skew*($maxbin-$bincross) + $Qzcross}]]

    # Get the new slice from Octave
    octave sync ::psd::draw_slice $action $skew $Qzcross $bincross
}

proc ::psd::draw_slice {action skew Qzcross bincross} {

    if { [string equal $action center] } {
	# Find the new vertical slice
	octave eval "binidx=round(clip($bincross,\[1,columns(psd)]));"
	octave eval {
	    qzy=psd(:,binidx);
	    qzdy=psderr(:,binidx);
	    qzy(qzy==0) = min(qzy(qzy!=0))/2;
	    send(sprintf('.psd.binslice elem conf slice -label "bin = %d"',binidx));
	}
	octave recv psd_Qz Qz
	octave recv psd_Qz_counts qzy
	octave recv psd_Qz_err qzdy
    }

    # Find the new skew slice
    octave eval "\[slicebin, sliceqz, biny, bindy]=psdslice(Qz,psd,psderr,$skew,$Qzcross,$bincross);"
    octave eval { biny(biny==0) = min(biny(biny!=0))/2; }
    octave recv psd_bin slicebin
    octave recv psd_bin_counts biny
    octave recv psd_bin_err bindy
}

proc saveslice { {name "psdslice"}} {
    if { [file extension $name] == "" } { append name ".txt" }
    set fid [open $name "w"]
    puts $fid [join $::psd_bin_counts(:) \n]
    close $fid
}


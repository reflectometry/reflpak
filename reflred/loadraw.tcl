# See README.load

# note the new extension
proc register_raw {} {
    set ::extfn(.raw) RAWinfo
    set ::typelabel(height) "Height scan"
    set ::typelabel(phi) "Sample rotote"
    set ::typelabel(chi) "Sample tilt"
    set ::typelabel(rock3) "A3 rock"
}

proc RAWinfo { action {name {}} } {
    switch -- $action {
	instrument { return XRAY }
	dataset { return [file join [file dirname $name] RAW] }
	info {
	    set date [clock format [file mtime $name] -format %Y-%m-%d]
	    set comment [file tail [file rootname $name]]
	    return [list date $date comment $comment]
	}
	pattern { return [file join [file dirname $name] {*.[rR][aA][wW]}] }
	mark { RAWmark $name }
    }
}

proc RAWmark {file} {
    # ptrace
    # suck in the file
    if {[ catch { open $file rb } fid ] } { 
	message "Error: $fid"
	return 
    }
    set raw [read $fid]
    close $fid

    # RAW files can have multiple data sections in the same
    # file.  We explode these on mark.

    # Data common to each section
    set sample [string trim [string map { "\0" " " } [string range $raw 326 385]]]
    set run [file rootname [file tail $file]]
    set date [clock scan "[string range $raw 16 25] [string range $raw 26 35]"]
    binary scan [string range $raw 616 623] d wavelength
    set head [string range $raw 0 711]

    # Split the remainder into data sections
    binary scan [string range $raw 12 17] i ranges
    if { $ranges <= 0 } {
	message "skipping empty file $file"
	return
    }
 
    set section 0
    set offset 712
    while {$section < $ranges} {
        # split section into rhead/rdata and move to next section
	binary scan [string range $offset [expr {$offset+3}]] i rhead_length
        binary scan [string range [expr {$offset+256}] [expr {$offset+259}]] i extra_length
        set data_offset [expr {$offset+$rhead_length+$extra_length}]
        set rhead [string range $offset [expr {$data_offset-1}]]
        binary scan [string range $rhead 4 7] i nrow
        binary scan [string range $rhead 252 255] i row_length
        set offset [expr {$data_offset+$nrow*$row_length}]
        set rdata [string range $data_offset [expr {$offset-1}]]
        incr section

	# Create separate data records for each section
	if { $ranges >= 0 } {
	    upvar "#0" [new_rec $file-$section] rec
	    set rec(run) $run-$section
	    set rec(comment) "$sample $section"
	} else {
	    upvar "#0" [new_rec $file] rec
	    set rec(run) $run
	    set rec(comment) $sample
	}
        set rec(load) RAWload
	set rec(view) RAWview
	set rec(instrument) "XRAY"
	set rec(L) $wavelength
	set rec(base) "TIME"
        binary scan [string range $rhead 212 215] f rec(T)
	set rec(H) 0
	# Common fields
	set rec(dataset) RAW
	set rec(date) $date 
        set rec(rawhead) $head
        set rec(rawrange) $rhead
        set rec(rawdata) $rdata

        # Interpret scan type
        binary scan [string range $rhead 196 199] i scan_type
        binary scan [string range $rhead 176 183] d increment
        binary scan [string range $rhead 8 63] ddddddd \
		theta two_theta chi phi x y z

	switch $scan_type {
	    0 { # locked coupled
                set min $two_theta
		set max [expr $min+$increment*$nrow]
		switch -regexp -- $run {
		    bk?g?[bm-]$ {
			marktype back $min $max -
		    }
		    bk?g?[ap+]?$ {
			marktype back $min $max +
		    }
		    default {
			marktype spec $min $max
		    }
		}
	    }
	    1 { # unlocked coupled
                set min $two_theta
                set max [expr $min+$increment*$nrow]
                if {2*$theta < $two_theta} {
		    marktype back $min $max -
                } else {
		    marktype back $min $max +
                }
            }
            2 { # detector scan
		set rec(rockbar) [expr $theta]
                marktype rock3 $two_theta [expr $two_theta+$increment*$nrow]
	    }
	    3 { # rocking curve
		set rec(rockbar) [expr $two_theta/2.]
		marktype rock $theta [expr $theta+$increment*$nrow]
            }
            4 { # chi scan
		marktype chi $chi [expr $chi+$increment*$nrow]
	    }
	    5 { # phi scan
		marktype phi $phi [expr $phi+$increment*$nrow]
	    }
	    8 { # z scan
		marktype height $z [expr $z+$increment*$nrow]
	    }
	}
    }
}

proc RAWview {id w} { 
    set rawhead ::${id}(rawhead)
    set rawdata ::${id}(rawdata)
    binary scan $rawhead \
        a8iia10a10a72a218a60a160a2iiiifffiifflllla4fddddda4ffa32fiaaaa \
        rawid measure_flag ranges date time user site sample comment res0 \
        goniom_model goniom_stage sample_changer goniom_ctrl goniom_radius \
        fixed_inc_divsli fixed_inc_samplesli fixed_inc_soller \
        fixed_inc_monochromator fixed_dif_antisli fixed_dif_detsli \
        fixed_dif_sndsoller fixed_dif_thinfilm fixed_dif_betafilter \
        fixed_dif_analyzer anode actual_QUANT_offset alpha_average \
        alpha_1 alpha_2 beta alpha_21 wave_unit beta_rel_int \
        run_time reserved PSDopening ranges_in_dql reserved_1 \
        further_dql_reading cQuantSequence HWindicator
    binary scan $rawdata \
        iidddddddda6a2da6a2iffffia8ffa5a3dddia4ddfiffffffiiia4diiifia4da24 \
        rawdata_length numpoints \
        theta_start two_theta_start chi_start phi_start x_start y_start z_start \
        divslit_start divslit_code res2 antislit_start antislit_code res3 \
        detector_1 det_HV_1 det_AG_1 det_LL_1 det_UL_1 \
        detector_2 res4 det_LL_2 det_UL_2 detslit_code res5 \
        aux1_start aux2_start aux3_start scan_mode res6 \
        increment_1 increment_2 step_time scan_type measurement_delay_time \
        range_sample_started rot_speed temperature heating_cooling_rate \
        temp_delay_time generator_voltage generator_current \
        display_plane_number res7 act_used_lambda varying_parameters \
        data_record_length extra_record_length smoothing_width sim_meas_cond \
        res8 increment_3 reserved_3


    set head "\
[rawid] 
measure_flag $measure_flag 
num_ranges $ranges 
date $date $time 
user $user 
site $site 
sample $sample 
comment $comment
goniom_model $goniom_model 
goniom_stage $goniom_stage
sample_changer $sample_changer 
goniom_ctrl $goniom_ctrl 
goniom_diameter $goniom_radius 
fixed_inc_divsli $fixed_inc_divsli 
fixed_inc_samplesli $fixed_inc_samplesli 
fixed_inc_soller $fixed_inc_soller 
fixed_inc_monochromator $fixed_inc_monochromator 
fixed_dif_antisli $fixed_dif_antisli 
fixed_dif_detsli $fixed_dif_detsli
fixed_dif_sndsoller $fixed_dif_sndsoller 
fixed_dif_thinfilm $fixed_dif_thinfilm 
fixed_dif_betafilter $fixed_dif_betafilter
fixed_dif_analyzer $fixed_dif_analyzer 
anode $anode 
actual_QUANT_offset $actual_QUANT_offset 
alpha_average $alpha_average
alpha_1 $alpha_1 
alpha_2 $alpha_2 
beta $beta 
alpha_21 $alpha_21 
wave_unit $wave_unit 
beta_rel_int $beta_rel_int
run_time $run_time 
PSDopening $PSDopening 
ranges_in_dql $ranges_in_dql 
further_dql_reading $further_dql_reading 
cQuantSequence $cQuantSequence 
HWindicator $HWindicator

numpoints $numpoints
theta_start $theta_start 
two_theta_start $two_theta_start 
chi_start $chi_start 
phi_start $phi_start 
x_start $x_start 
y_start $y_start 
z_start $z_start
aux1_start $aux1_start 
aux2_start $aux2_start 
aux3_start $aux3_start 
divslit_start $divslit_start 
divslit_code $divslit_code 
antislit_start $antislit_start 
antislit_code $antislit_code 
detector_1 $detector_1 
det_HV_1 $det_HV_1 
det_AG_1 $det_AG_1 
det_LL_1 $det_LL_1 
det_UL_1 $det_UL_1 
detector_2 $detector_2 
det_LL_2 $det_LL_2 
det_UL_2 $det_UL_2 
detslit_code $detslit_code 
varying_parameters $varying_parameters 
increment_1 $increment_1 
increment_2 $increment_2 
increment_3 $increment_3
step_time $step_time 
measurement_delay_time $measurement_delay_time 
range_start_time $range_sample_started 
rot_speed $rot_speed 
temperature $temperature 
heating_cooling_rate $heating_cooling_rate 
temp_delay_time $temp_delay_time 
generator_voltage $generator_voltage 
generator_current $generator_current 
display_plane_number $display_plane_number 
act_used_lambda $act_used_lambda 
smoothing_width $smoothing_width 
sim_meas_cond $sim_meas_cond 
"
    # FIXME: not handling multi-column data
    binary scan $rec(rawdata) f* counts
    set data [join $counts "\n"]
    text_replace $w $head$data
}

proc RAWload {id} {
    upvar #0 $id rec

    binary scan [string range $rec(rawrange) 192 195] f rec(monitor)
    if { $rec(monitor)==0.0 } { set rec(monitor) 1.0 }

    # See if the attenuator is in place.  Set the default attenuator
    # appropriately.
    switch -- [string range $rec(rawrange) 136 137] {
	IN - In - in { set rec(k) 100.0 }
	default { set rec(k) 1.0 }
    }

    # convert the data columns to vectors
    binary scan [string range $rhead 196 199] i scan_type
    binary scan [string range $rhead 176 183] d increment
    binary scan [string range $rhead 4 7] i nrow
    binary scan [string range $rhead 8 63] ddddddd \
	theta two_theta chi phi x y z
    binary scan $rec(rawdata) f* counts

    switch $scan_type {
        0 - 1 {
            set motor beta
            set start $two_theta
            set rec(xlab) "Qz ($::symbol(invangstrom))"
        }
	2 {
	    set motor beta
	    set start $two_theta
            set rec(xlab) "Detector angle (degrees)"
	}
	3 { 
	    set motor alpha
            set start $theta
	    set rec(xlab) "Incident angle (degrees)" 
	}
	4 { 
	    set motor sample_tilt
	    set start $chi
	    set rec(xlab) "Sample tilt (degrees)" 
	}
	5 {
	    set motor sample_rotation
	    set start $phi
	    set rec(xlab) "Sample rotation (degrees)" 
	}
	8 { 
	    set motor height
            set start $z
	    set rec(xlab) "Height" 
	}
    }
    vector create ::${motor}_$id ::counts_$id
    ::${motor}_$id_$id seq 1 $nrow
    ::${motor]_$id expr "$START + (::${motor}_$id-1)*$increment"
    ::counts_$id set $counts
    # FIXME: fails if data has more than one column
    if { $scan_type == 0 } {
	vector create ::alpha_$id
	::alpha_$id expr "::beta_$id/2"
	AB_to_QxQz $id
	::Qz_$id dup ::x_$id
    } else if { $scan_type == 1 } {
        set offset [expr $two_theta/2.-$theta]
        ::alpha_$id expr "$offset + ::beta_$id/2" 
	AB_to_QxQz $id
	::Qz_$id dup ::x_$id
    } else {
	::${motor}_$id dup ::x_$id
    }

    # If measurements recorded as counts per second, translate to counts.
    vector create ::dcounts_$id
    ::dcounts_$id expr "sqrt(::counts_$id + !::counts_$id)"

    # Create the 'seconds' column from the constant monitor
    vector create ::seconds_$id
    ::seconds_$id expr "::counts_$id*0 + $rec(monitor)"

    # FIXME: convert x to Qz or whatever units are appropriate
    set rec(ylab) [monitor_label $rec(base) $rec(monitor)]

    return 1
}

# See README.load

# note the new extension
proc register_bruker {} {
    set ::extfn(.raw) RAWinfo
    set ::typelabel(height) "Height scan"
    set ::typelabel(phi) "Sample rock"
    set ::typelabel(chi) "Sample tilt"
    set ::typelabel(other) "Other motor"
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

proc trim {s} {
    return [string map {"\0" "" } $s]
}

proc RAWmark {file} {
    # ptrace
    # suck in the file
    if {[ catch { open $file r } fid ] } { 
	message "Error: $fid"
	return 
    }
    fconfigure $fid -translation binary
    set raw [read $fid]
    close $fid

    # Check header
    if { [string compare [string range $raw 0 3] "RAW1"] != 0 } {
        # not a bruker RAW file
        return
    }

    # RAW files can have multiple data sections in the same
    # file.  We explode these on mark.

    # Data common to each section
    set sample [trim [string range $raw 326 385]]
    set run [file rootname [file tail $file]]
    set date [clock scan "[trim [string range $raw 16 25]] [trim [string range $raw 26 35]]"]
    set head [string range $raw 0 711]
    binary scan [string range $raw 616 623] d wavelength

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
	binary scan [string range $raw $offset [expr {$offset+3}]] i rhead_length
        binary scan [string range $raw [expr {$offset+256}] [expr {$offset+259}]] i extra_length
        set data_offset [expr {$offset+$rhead_length+$extra_length}]
        set rhead [string range $raw $offset [expr {$data_offset-1}]]
        binary scan [string range $rhead 4 7] i nrow
        binary scan [string range $rhead 252 255] i row_length
        set offset [expr {$data_offset+$nrow*$row_length}]
        set rdata [string range $raw $data_offset [expr {$offset-1}]]
        incr section

	# Create separate data records for each section
	if { $ranges > 1 } {
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
        binary scan [string range $rhead 8 63] \
	    ddddddd theta two_theta chi phi x y z

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
                marktype rock $two_theta [expr $two_theta+$increment*$nrow]
	    }
	    3 { # rocking curve
	        # Rather than using a rocking curve with Qx offet, pretend that
		# we are doing a phi scan, and set ranges appropriately
		#set rec(rockbar) [expr $two_theta/2.]
		#marktype rock $theta [expr $theta+$increment*$nrow]
		#set rec(rockbar) $phi
	        marktype phi [expr $phi-($two_theta/2.-$theta)] \
		    [expr $phi-($two_theta/2.-$theta)+$increment*$nrow]
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
            default { # some other scan
                marktype other 0 [expr $increment*$nrow]
            }
	}
    }
}

proc RAWview {id w} { 
    upvar #0 $id rec
    binary scan $rec(rawhead) \
        a8iia10a10a72a218a60a160a2iiiifffiiffiiiia4fddddda4ffa32fiaaaa \
        raw_id meas_flag no_of_tot_meas_ranges date time user site \
        samplename comment res0 \
        goniom_model goniom_stage sample_changer goniom_ctrl goniom_radius \
        fixed_inc_divsli fixed_inc_samplesli fixed_inc_soller \
        fixed_inc_monochromator fixed_dif_antisli fixed_dif_detsli \
        fixed_dif_sndsoller fixed_dif_thinfilm fixed_dif_betafilter \
        fixed_dif_analyzer anode actual_QUANT_offset alpha_average \
        alpha_1 alpha_2 beta alpha_21 wave_unit beta_rel_int \
	total_sample_run_time \
        reserved PSDopening no_of_tot_meas_ranges_in_dql reserved_1 \
        further_dql_reading cQuantSequence HWindicator
    binary scan $rec(rawrange) \
        iidddddddda6a2da6a2iffffia8ffa5a3dddia4ddfiffffffiiia4diiifia4da24 \
        length_of_RAW_RANGE_HEADER no_of_measured_data theta_start \
	two_theta_start chi_start phi_start x_start y_start z_start \
        divslit_start divslit_code res2 antislit_start antislit_code res3 \
        detector_1 det_HV_1 det_AG_1 det_LL_1 det_UL_1 \
        detector_2 res4 det_LL_2 det_UL_2 detslit_code res5 \
        aux1_start aux2_start aux3_start scan_mode res6 \
        increment_1 increment_2 step_time scan_type meas_delay_time \
        range_sample_started rot_speed temperature heating_cooling_rate \
        temp_delay_time generator_voltage generator_current \
        display_plane_number res7 act_used_lambda varying_parameters \
        data_record_length extra_record_length smoothing_width sim_meas_cond \
        res8 increment_3 reserved_3

    # Compose header summary
    array set stepper_name { 
        0 2theta 1 2theta 2 2theta 3 phi 4 chi
        5 phi 6 x 7 y 8 z 9 aux1 10 aux2 11 aux3 12 psi 13 hkl
        14 recspace 20 2theta 129 PSD-fixed 130 PSD-fast
    }
    array set stepper_var {
        0 two_theta_start 1 two_theta_start 2 two_theta_start
        3 theta_start 4 chi_start 5 phi_start 6 x_start 7 y_start
        8 z_start 9 aux1_start 10 aux2_start 11 aux3_start
    }
    if {$scan_type == 3} {
        set start_range [expr $phi_start - ($two_theta_start/2.-$theta_start)]
    } else {
        set start_range [set $stepper_var($scan_type)]
    }
    set stop_range [expr $start_range+$no_of_measured_data*$increment_1]
    set scanstr [format "%s from %.4f to %.4f by %.4f" \
        $stepper_name($scan_type) $start_range $stop_range $increment_1]
    if {$scan_type == 0 || $scan_type == 20} {
        append scanstr ", theta = 2theta/2"
    } elseif {$scan_type == 1} {
        set offset [expr 0.5*$two_theta_start-$theta_start]
        if {$offset < 0} {
            set offsetstr [format "- %.4f" [expr -$offset]]
        } else {
            set offsetstr [format "+ %.4f" $offset]
        }
        append scanstr ", theta = 2theta/2 $offsetstr"
    } elseif {$scan_type == 3} {
        append scanstr " using theta/2theta"
    }
    set startstr [format \
        "theta:%.4f  2theta:%.4f  chi:%.4f  phi:%.4f  x:%.4f  y:%.4f  z:%.4f" \
        $theta_start $two_theta_start $chi_start $phi_start \
	$x_start $y_start $z_start]
    if {$scan_mode == 0} {
        set modestr "continuous"
    } else {
        set modestr "stepped"
    }
    set countstr [format "%d steps at %.4f sec/step" \
        $no_of_measured_data $step_time]
    set slitstr [format "%.1f  %.1f  %.1f  %.1f" $fixed_inc_divsli \
        $fixed_inc_samplesli $fixed_dif_antisli $fixed_dif_detsli]

    set head "# [trim $date] [trim $time] [trim $samplename]
# $modestr scan with $countstr
# scan $scanstr
# start $startstr
# slits $slitstr
# source [trim $anode] $alpha_average A, generator $generator_voltage V / $generator_current mA, det slit [trim $detslit_code] 
# temperature $temperature K changing by $heating_cooling_rate K/s
"

set foot "

# ===== RAW_HEADER =====
raw_id [trim $raw_id]
meas_flag $meas_flag 
no_of_tot_meas_ranges $no_of_tot_meas_ranges
date [trim $date]
time [trim $time] 
user [trim $user]
site [trim $site] 
samplename [trim $samplename]
comment [trim $comment]
goniom_model $goniom_model 
goniom_stage $goniom_stage
sample_changer $sample_changer 
goniom_ctrl $goniom_ctrl 
goniom_radius $goniom_radius 
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
anode [trim $anode]
actual_QUANT_offset $actual_QUANT_offset 
alpha_average $alpha_average
alpha_1 $alpha_1 
alpha_2 $alpha_2 
beta $beta 
alpha_21 $alpha_21 
wave_unit [trim $wave_unit]
beta_rel_int $beta_rel_int
total_sample_run_time $total_sample_run_time 
PSDopening $PSDopening 
no_of_tot_meas_ranges_in_dql $no_of_tot_meas_ranges_in_dql 
further_dql_reading [trim $further_dql_reading]
cQuantSequence [trim $cQuantSequence]
HWindicator [trim $HWindicator]

# ===== RAW_RANGE_HEADER =====
no_of_measured_data $no_of_measured_data
theta_start $theta_start 
two_theta_start $two_theta_start 
chi_start $chi_start 
phi_start $phi_start 
x_start $x_start 
y_start $y_start 
z_start $z_start
divslit_start $divslit_start
divslit_code [trim $divslit_code]
antislit_start $antislit_start 
antislit_code [trim $antislit_code]
detector_1 $detector_1 
det_HV_1 $det_HV_1 
det_AG_1 $det_AG_1 
det_LL_1 $det_LL_1 
det_UL_1 $det_UL_1 
detector_2 $detector_2 
det_LL_2 $det_LL_2 
det_UL_2 $det_UL_2 
detslit_code [trim $detslit_code]
aux1_start $aux1_start 
aux2_start $aux2_start 
aux3_start $aux3_start 
scan_mode [trim $scan_mode]
increment_1 $increment_1 
increment_2 $increment_2 
step_time $step_time 
scan_type $scan_type
meas_delay_time $meas_delay_time 
range_sample_started $range_sample_started 
rot_speed $rot_speed 
temperature $temperature 
heating_cooling_rate $heating_cooling_rate 
temp_delay_time $temp_delay_time 
generator_voltage $generator_voltage 
generator_current $generator_current 
display_plane_number $display_plane_number 
act_used_lambda $act_used_lambda 
varying_parameters $varying_parameters 
smoothing_width $smoothing_width 
sim_meas_cond $sim_meas_cond 
increment_3 $increment_3
"
    # FIXME: not handling multi-column data
    binary scan $rec(rawdata) f* counts
    set data ""
    foreach c $counts { append data "[expr int($c)]\n" }
    text_replace $w $head$data$foot
}

proc RAWload {id} {
    upvar #0 $id rec

    set head $rec(rawhead)
    set rhead $rec(rawrange)
    binary scan [string range $rhead 192 195] f rec(monitor)
    if { $rec(monitor)==0.0 } { set rec(monitor) 1.0 }

    # See if the attenuator is in place.  Set the default attenuator
    # appropriately.
    switch -- [string range $rhead 136 137] {
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
    binary scan [string range $head 568 575] ff divslit sampleslit
    binary scan [string range $head 584 591] ff antislit detectorslit

    switch $scan_type {
	0 - 1 {
	    set motor beta
	    set start $two_theta
	    set rec(xlab) "Qz ($::symbol(invangstrom))"
	}
	2 {
	    set motor beta
	    set start $two_theta
	    set rec(xlab) "Qx ($::symbol(invangstrom))"
	}
	3 { 
	    # Use effective phi for x-axis rather than Qx so we can
	    # overplot phi curves
	    set motor phi
	    set start [expr $phi-($two_theta/2.-$theta)]
	    set rec(xlab) "phi (degrees)"

	    # Uncomment if using real rocking curve
	    #set motor alpha
	    #set start $theta
	    #set rec(xlab) "Qx ($::symbol(invangstrom))"
	}
	4 { 
	    set motor sample_tilt
	    set start $chi
	    set rec(xlab) "chi (degrees)"
	}
	5 {
	    set motor sample_angle
	    set start $phi
	    set rec(xlab) "phi (degrees)"
	}
	8 { 
	    set motor height
	    set start $z
	    set rec(xlab) "Height" 
	}
    }
    vector create ::${motor}_$id ::counts_$id \
        ::slit1_$id ::slit2_$id ::slit3_$id ::slit4_$id
    ::${motor}_$id seq 1 $nrow
    ::${motor}_$id expr "$start + (::${motor}_$id-1)*$increment"
    ::counts_$id set $counts
    ::slit1_$id expr "::counts_$id*0 + $divslit"
    ::slit2_$id expr "::counts_$id*0 + $sampleslit"
    ::slit3_$id expr "::counts_$id*0 + $antislit"
    ::slit4_$id expr "::counts_$id*0 + $detectorslit"
    # FIXME: fails if data has more than one column
    if { $scan_type == 0 } {
	vector create ::alpha_$id
	::alpha_$id expr "::beta_$id/2"
	AB_to_QxQz $id
	::Qz_$id dup ::x_$id
    } elseif { $scan_type == 1 } {
	vector create ::alpha_$id
        set offset [expr $two_theta/2.-$theta]
        ::alpha_$id expr "$offset + ::beta_$id/2" 
	AB_to_QxQz $id
	::Qz_$id dup ::x_$id
    } elseif { $scan_type == 2 } {
        vector create ::alpha_$id
        ::alpha_$id expr "0*::beta_$id + $theta"
	AB_to_QxQz $id
	::Qx_$id dup ::x_$id
    } elseif { $scan_type == 3 } {
        ::phi_$id dup ::x_$id
	# Uncomment for Qx plot rather than effective phi
        #vector create ::beta_$id
        #::beta_$id expr "0*::alpha_$id + $two_theta"
	#AB_to_QxQz $id
	#::Qx_$id dup ::x_$id
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

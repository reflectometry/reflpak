#!/bin/sh
# \
exec wish "$0" "$@"

# icons.tcl --
#
# Win32 ico manipulation code
#
# Copyright (c) 2003 Aaron Faupell
# Copyright (c) 2003 ActiveState Corporation
#

# http://www.fearme.com/misc/programs.cgi?type=tcltk&file=icons
# Date: 12/1/2003

# Description:
#
#   functions for reading and writing icons from .ICO .EXE .DLL and .ICL files
#
# Demo:
#
#   run "wish icons.tcl iconfile.ico" from the command line for a
#   demo displaying all the icons in the file.
#
# Usage:
#
#   [IconStats file type] returns info on the icons within the
#   file. there is one list element per icon. each element consists of 3
#   numbers, the width, height, and color depth of the icon. type must
#   be one of ICO, EXE, DLL, ICL
#
#   [getIconImage file type index] returns the name of an [image]
#   containing the icon named by file and index. index starts at 0, see
#   IconStats.
#
#   [getIconColors file type index] returns a list where each element is
#   a row of the image. each row is a list where each element is a
#   pixel. each pixel is in the familiar form #RRGGBB. an empty pixel
#   denotes transparency. the image rows are in a bottom to top order.
#
#   [writeIcon file type index bpp colors] writes an icon to the named
#   file. colors is either a list in the above format, or it is the name
#   of an [image] from which to extract the data. bpp is the color depth
#   to write the icon with. supported depths are 1 4 8 24 and 32. if you
#   select 1 4 or 8 and your image has too many colors an error will be
#   generated. index may be specified as one higher than the number of
#   icons currently in the file. indexes outside this range will
#   generate an error. when writing an exe you may only replace an icon
#   with one of the same size and color depth. you cannot add new icons
#   to exes.
#
#   [translateColors colors] this function will change a list of colors
#   in the #RRGGBB format to the "R G B" format
#
#   [transparentColor image color] sets every pixel that is color in Tk
#   [image] image to be transparent. color may be either the #RRGGBB or
#   the "R G B" format.
#
#   [EXEtoICO exe ico] creates a new .ico file with the name ico
#   containing every icon from the exe exe. this function is much faster
#   than extracting and writing the icons using the other functions.
#
# Notes:
#
#   Tk [image]s do not support alpha blending. writing a 32bpp icon from
#   an [image] is equivalent to writing a 24bpp icon. you can use the
#   full alpha channel by writing from a list of colors in the format
#   "R G B A". you may write a 24bpp icon from 32bpp formatted data, the
#   alpha channel will be silently dropped.
#
#   DLLs and ICLs have the same format as EXEs so you can read them
#   by using the EXE type.


package require Tcl 8.4

# Instantiate vars we need for this package
namespace eval ::ico {
    # don't look farther than this for icos past beginning or last ico found
    variable maxIcoSearch 32768; #16384 ; #32768

    # stores cached indices of icons found
    variable  ICONS
    array set ICONS {}

    # used for 4bpp number conversion
    variable BITS
    array set BITS [list {} 0 0000 0 0001 1 0010 2 0011 3 0100 4 \
	       0101 5 0110 6 0111 7 1000 8 1001 9 \
	       1010 10 1011 11 1100 12 1101 13 1110 14 1111 15 \
	       \
	       00000 00 00001 0F 00010 17 00011 1F \
	       00100 27 00101 2F 00110 37 00111 3F \
	       01000 47 01001 4F 01010 57 01011 5F \
	       01100 67 01101 6F 01110 77 01111 7F \
	       10000 87 10001 8F 10010 97 10011 9F \
	       10100 A7 10101 AF 10110 B7 10111 BF \
	       11000 C7 11001 CF 11010 D7 11011 DF \
	       11100 E7 11101 EF 11110 F7 11111 FF]
}

# List of icons in the file (each element a list of w h and bpp)
proc ::ico::IconStats {file type} {
    if {[info commands IconStats$type] == ""} {
	return -code error "unsupported file format $type"
    }
    IconStats$type [file normalize $file]
}

# Get icon @ index in file as tk image
proc ::ico::getIconImage {file type index} {
    if {[info commands extractIcon$type] == ""} {
	return -code error "unsupported file format $type"
    }
    return [eval [list createImage] [extractIcon$type [file normalize $file] $index]]
}

# Get pixel data of icon @ index in file
proc ::ico::getIconColors {file type index} {
    if {[info commands extractIcon$type] == ""} {
	return -code error "unsupported file format $type"
    }
    return [eval [list getColors] [extractIcon$type [file normalize $file] $index]]
}

# Write icon @ index in file of specific type with depth/pixel data
proc ::ico::writeIcon {file type index bpp colors} {
    if {[info commands writeIcon$type] == ""} {
	return -code error "unsupported file format $type"
    }
    if {[llength $colors] == 1} {
        set colors [getColorsFromImage $colors]
    } elseif {[string match "#*" [lindex $colors 0 0]]} {
        set colors [translateColors $colors]
    }
    if {$bpp != 0 && $bpp != 1 && $bpp != 4 && $bpp != 8 && $bpp != 24 && $bpp != 32} {
	return -code error "invalid color depth --- use 0 for default"
    }
    set palette {}
    if {$bpp <= 8} {
        set palette [getPaletteFromColors $colors]
        if { $bpp == 0 } {
            set n [lindex $palette 0]
            if { $n <= 2 } {
                set bpp 1
            } elseif { $n <= 16 } {
                set bpp 4
            } elseif { $n <= 256 } {
                set bpp 8
            } else {
                set bpp 24
            }
            # XXX FIXME XXX no transparency in Tcl images
        }
        if {[lindex $palette 0] > (1 << $bpp)} {
	    return -code error "specified color depth too low"
	}
        set colors [lindex $palette 2]
        set palette [lindex $palette 1]
        append palette [string repeat \000 [expr {(1 << ($bpp + 2)) - [string length $palette]}]]
    }
    set and [getAndMaskFromColors $colors]
    set xor [getXORFromColors $bpp $colors]
    writeIcon$type [file normalize $file] $index \
	[llength [lindex $colors 0]] [llength $colors] $bpp $palette $xor $and
}

##
## Internal helper commands.
##

proc ::ico::formatColor {r g b} {
    format "#%02X%02X%02X" [scan $r %c] [scan $g %c] [scan $b %c]
}

proc ::ico::translateColors {colors} {
    set new {}
    foreach line $colors {
        set tline {}
        foreach x $line {
            if {$x == ""} {lappend tline {}; continue}
            lappend tline [scan $x "#%2x%2x%2x"]
        }
        set new [linsert $new 0 $tline]
    }
    return $new
}

proc ::ico::transparentColor {img color} {
    if {[string match "#*" $color]} {
	set color [scan $x "#%2x%2x%2x"]
    }
    set w [image width $img]
    set h [image height $img]
    for {set y 0} {$y < $h} {incr y} {
        for {set x 0} {$x < $w} {incr x} {
            if {[$img get $x $y] eq $color} {$img transparency set $x $y 1}
        }
    }
}

proc ::ico::getdword {fh} {
    binary scan [read $fh 4] i* tmp
    return $tmp
}

proc ::ico::getword {fh} {
    binary scan [read $fh 2] s* tmp
    return $tmp
}

proc ::ico::bputs {fh format args} {
    puts -nonewline $fh [eval [list binary format $format] $args]
}

proc ::ico::createImage {w h bpp palette xor and} {
    set img [image create photo -width $w -height $h]
    set x 0
    set y [expr {$h - 1}]

    if {$bpp == 1} {
        binary scan $xor B* xorBits
        foreach i [split $xorBits {}] a [split $and {}] {
            if {$x == $w} { incr y -1; set x 0 }
            if {$a == 0} {
                $img put -to $x $y [lindex $palette $i]
            }
            incr x
        }
    } elseif {$bpp == 4} {
	# palette will be 16 color list
	variable BITS
	binary scan $xor B* xorBits
	set i 0
	foreach a [split $and {}] {
	    # move y at edge boundaries
	    if {$x == $w} { incr y -1; set x 0 }
	    if {$a == 0} {
		set bits [string range $xorBits $i [expr {$i+3}]]
		$img put -to $x $y [lindex $palette $BITS($bits)]
	    }
	    incr i 4
	    incr x
	}
    } elseif {$bpp == 8} {
        foreach i [split $xor {}] a [split $and {}] {
            if {$x == $w} { incr y -1; set x 0 }
            if {$a == 0} {
                $img put -to $x $y [lindex $palette [scan $i %c]]
            }
            incr x
        }
    } elseif {$bpp == 16} {
        variable BITS
        binary scan $xor b* xorBits
        set i 0
	foreach a [split $and {}] {
	    if {$x == $w} { incr y -1; set x 0 }
	    if {$a == 0} {
		set b1 [string range $xorBits       $i       [expr {$i+4}]]
		set b2 [string range $xorBits [expr {$i+5}]  [expr {$i+9}]]
		set b3 [string range $xorBits [expr {$i+10}] [expr {$i+14}]]
		$img put -to $x $y #$BITS($b3)$BITS($b2)$BITS($b1)
	    }
	    incr i 16
	    incr x
	}
    } elseif {$bpp == 24} {
        foreach {b g r} [split $xor {}] a [split $and {}] {
            if {$x == $w} { incr y -1; set x 0 }
            if {$a == 0} {
                $img put -to $x $y [formatColor $r $g $b]
            }
            incr x
        }
    } elseif {$bpp == 32} {
        foreach {b g r a} [split $xor {}] a [split $and {}] {
            if {$x == $w} { incr y -1; set x 0 }
            if {$a == 0} {
                $img put -to $x $y [formatColor $r $g $b]
            }
            incr x
        }
    }
    return $img
}

proc ::ico::getColors {w h bpp palette xor and} {
    set list {}
    set row {}
    set x 0
    if {$bpp == 1} {
        binary scan $xor B* xorBits
        foreach i [split $xorBits {}] a [split $and {}] {
            if {$x == $w} {
                set x 0
                set list [linsert $list 0 $row]
                set row {}
            }
            if {$a == 0} {
                lappend row [lindex $palette $i]
            } else {
                lappend row {}
            }
            incr x
        }
    } elseif {$bpp == 4} {
        variable BITS
        binary scan $xor B* xorBits
        set i 0
        foreach a [split $and {}] {
            if {$x == $w} {
                set x 0
                set list [linsert $list 0 $row]
                set row {}
            }
            if {$a == 0} {
                set bits [string range $xorBits $i [expr {$i+3}]]
                lappend row [lindex $palette $BITS($bits)]
            } else {
                lappend row {}
            }
            incr i 4
            incr x
        }
    } elseif {$bpp == 8} {
        foreach i [split $xor {}] a [split $and {}] {
            if {$x == $w} {
		set x 0
		set list [linsert $list 0 $row]
		set row {}
	    }
            if {$a == 0} {
                lappend row [lindex $palette [scan $i %c]]
            } else {
                lappend row {}
            }
            incr x
        }
    } elseif {$bpp == 16} {
        variable BITS
        binary scan $xor b* xorBits
        set i 0
	foreach a [split $and {}] {
	    if {$x == $w} {
	        set x 0
	        set list [linsert $list 0 $row]
		set row {}
	    }
	    if {$a == 0} {
		set b1 [string range $xorBits      $i        [expr {$i+4}]]
		set b2 [string range $xorBits [expr {$i+5}]  [expr {$i+9}]]
		set b3 [string range $xorBits [expr {$i+10}] [expr {$i+14}]]
		lappend row #$BITS($b3)$BITS($b2)$BITS($b1)
	    } else {
	        lappend row {}
	    }
	    incr i 16
	    incr x
	}
    } elseif {$bpp == 24} {
        foreach {b g r} [split $xor {}] a [split $and {}] {
            if {$x == $w} {
		set x 0
		set list [linsert $list 0 $row]
		set row {}
	    }
            if {$a == 0} {
                lappend row [formatColor $r $g $b]
            } else {
                lappend row {}
            }
            incr x
        }
    } elseif {$bpp == 32} {
        foreach {b g r a} [split $xor {}] a [split $and {}] {
            if {$x == $w} {
		set x 0
		set list [linsert $list 0 $row]
		set row {}
	    }
            if {$a == 0} {
                lappend row [formatColor $r $g $b]
            } else {
                lappend row {}
            }
            incr x
        }
    }
    set list [linsert $list 0 $row]
    return $list
}

proc ::ico::getAndMaskFromColors {colors} {
    set and {}
    foreach line $colors {
        set l {}
        foreach x $line {append l [expr {$x == ""}]}
        append l [string repeat 0 [expr {[string length $l] % 32}]]
        foreach {a b c d e f g h} [split $l {}] {
	    append and [binary format B8 $a$b$c$d$e$f$g$h]
	}
    }
    return $and
}

proc ::ico::getXORFromColors {bpp colors} {
    set xor {}
    if {$bpp == 1} {
        foreach line $colors {
            foreach {a b c d e f g h} $line {
                foreach x {a b c d e f g h} {
                    if {[set $x] == ""} {set $x 0}
                }
                binary scan $a$b$c$d$e$f$g$h bbbbbbbb h g f e d c b a
                append xor [binary format b8 $a$b$c$d$e$f$g$h]
            }
        }
    } elseif {$bpp == 4} {
        foreach line $colors {
            foreach {a b} $line {
                if {$a == ""} {set a 0}
                if {$b == ""} {set b 0}
                binary scan $a$b b4b4 b a
                append xor [binary format b8 $a$b]
            }
        }
    } elseif {$bpp == 8} {
        foreach line $colors {
            foreach x $line {
                if {$x == ""} {set x 0}
                append xor [binary format c $x]
            }
        }
    } elseif {$bpp == 24} {
        foreach line $colors {
            foreach x $line {
                if {![llength $x]} {
		    append xor [binary format ccc 0 0 0]
		} else {
		    foreach {a b c n} $x {
			append xor [binary format ccc $c $b $a]
		    }
		}
            }
        }
    } elseif {$bpp == 32} {
        foreach line $colors {
            foreach x $line {
                if {![llength $x]} {
		    append xor [binary format cccc 0 0 0 0]
		} else {
		    foreach {a b c n} $x {
			if {$n == ""} {set n 0}
			append xor [binary format cccc $c $b $a $n]
		    }
		}
            }
        }
    }
    return $xor
}

proc ::ico::getColorsFromImage {img} {
    set w [image width $img]
    set h [image height $img]
    set r {}
    for {set y [expr $h - 1]} {$y > -1} {incr y -1} {
        set l {}
        for {set x 0} {$x < $w} {incr x} {
            if {[$img transparency get $x $y]} {
                lappend l {}
            } else {
                lappend l [$img get $x $y]
            }
        }
        lappend r $l
    }
    return $r
}

proc ::ico::getPaletteFromColors {colors} {
    set palette {}
    array set tpal {}
    set new {}
    set i 0
    foreach line $colors {
        set tline {}
        foreach x $line {
            if {$x == ""} {lappend tline {}; continue}
            if {![info exists tpal($x)]} {
                foreach {a b c n} $x {
		    append palette [binary format cccc $c $b $a 0]
		}
                set tpal($x) $i
                incr i
            }
            lappend tline $tpal($x)
        }
        lappend new $tline
    }
    return [list $i $palette $new]
}

proc ::ico::readDIB {fh w h bpp} {
    if {$bpp == 1 || $bpp == 4 || $bpp == 8} {
        set colors [read $fh [expr {1 << ($bpp + 2)}]]
    } elseif {$bpp == 16 || $bpp == 24 || $bpp == 32} {
        set colors {}
    } else {
        return -code error "unsupported color depth: $bpp"
    }

    set palette [list]
    foreach {b g r x} [split $colors {}] {
        lappend palette [formatColor $r $g $b]
    }

    set xor  [read $fh [expr {int(($w * $h) * ($bpp / 8.0))}]]
    set and1 [read $fh [expr {(($w * $h) + ($h * ($w % 32))) / 8}]]

    set and {}
    set row [expr {($w + abs($w - 32)) / 8}]
    set len [expr {$row * $h}]
    for {set i 0} {$i < $len} {incr i $row} {
        binary scan [string range $and1 $i [expr {$i + $row}]] B$w tmp
        append and $tmp
    }

    return [list $palette $xor $and]
}

proc ::ico::IconStatsICO {file} {
    set fh [open $file r]
    fconfigure $fh -translation binary
    if {"[getword $fh] [getword $fh]" != "0 1"} {
        return -code error "not an icon file"
    }
    set num [getword $fh]
    set r {}
    for {set i 0} {$i < $num} {incr i} {
        set info {}
        lappend info [scan [read $fh 1] %c] [scan [read $fh 1] %c]
        set bpp [scan [read $fh 1] %c]
        if {$bpp == 0} {
            set orig [tell $fh]
            seek $fh 9 current
            seek $fh [expr {[getdword $fh] + 14}] start
            lappend info [getword $fh]
            seek $fh $orig start
        } else {
            lappend info [expr {int(sqrt($bpp))}]
        }
        lappend r $info
        seek $fh 13 current
    }
    close $fh
    return $r
}

proc ::ico::extractIconICO {file index} {
    set fh [open $file r]
    fconfigure $fh -translation binary
    if {"[getword $fh] [getword $fh]" != "0 1"} {
	return -code error "not an icon file"
    }
    if {$index < 0 || $index >= [getword $fh]} {
	return -code error "index out of range"
    }

    seek $fh [expr {(16 * $index) + 12}] current
    seek $fh [getdword $fh] start

    binary scan [read $fh 16] iiiss s w h p bpp
    set h [expr {$h / 2}]
    seek $fh 24 current

    # readDIB returns: {palette xor and}
    set pxa [readDIB $fh $w $h $bpp]
    close $fh
    return [concat [list $w $h $bpp] $pxa]
}

proc ::ico::writeIconICO {file index w h bpp palette xor and} {
    if {![file exists $file]} {
        set fh [open $file w+]
        fconfigure $fh -translation binary
        bputs $fh sss 0 1 0
        seek $fh 0 start
    } else {
        set fh [open $file r+]
        fconfigure $fh -translation binary
    }
    if {[file size $file] > 4 && "[getword $fh] [getword $fh]" != "0 1"} {
	close $fh
	return -code error "not an icon file"
    }
    set num [getword $fh]
    if {$index == "end"} { set index $num }
    if {$index < 0 || $index > $num} {
	close $fh
	return -code error "index out of range"
    }
    set colors 0
    if {$bpp <= 8} {set colors [expr {1 << $bpp}]}
    set size [expr {[string length $palette] + [string length $xor] + [string length $and]}]
    if {$index == $num} {
        seek $fh -2 current
        bputs $fh s [expr {$num + 1}]
        seek $fh [expr {$num * 16}] current
        set olddata [read $fh]
        set cur 0
        while {$cur < $num} {
            seek $fh [expr {($cur * 16) + 18}] start
            set toff [getdword $fh]
            seek $fh -4 current
            bputs $fh i [expr {$toff + 16}]
            incr cur
        }
        bputs $fh ccccss $w $h $colors 0 1 $bpp
        bputs $fh ii [expr {$size + 40}] [expr {[string length $olddata] + [tell $fh] + 8}]
        puts -nonewline $fh $olddata
        bputs $fh iiissiiiiii 40 $w [expr {$h * 2}] 1 $bpp 0 $size 0 0 0 0
        puts -nonewline $fh $palette
        puts -nonewline $fh $xor
        puts -nonewline $fh $and
    } else {
        seek $fh [expr {($index * 16) + 8}] current
        set len [getdword $fh]
        set offset [getdword $fh]
        set cur [expr {$index + 1}]
        while {$cur < $num} {
            seek $fh [expr {($cur * 16) + 18}] start
            set toff [getdword $fh]
            seek $fh -4 current
            bputs $fh i [expr {$toff + (($size + 40) - $len)}]
            incr cur
        }
        seek $fh [expr {$offset + $len}] start
        set olddata [read $fh]
        seek $fh [expr {($index * 16) + 6}] start
        bputs $fh ccccssi $w $h $colors 0 1 $bpp [expr {$size + 40}]
        seek $fh $offset start
        bputs $fh iiissiiiiii 40 $w [expr {$h * 2}] 1 $bpp 0 $size 0 0 0 0
        puts -nonewline $fh $palette
        puts -nonewline $fh $xor
        puts -nonewline $fh $and
        puts -nonewline $fh $olddata
    }
    close $fh
}

proc ::ico::checkEXE {exe {mode r}} {
    set fh [open $exe $mode]
    fconfigure $fh -translation binary

    if {[read $fh 2] != "MZ"} {
	close $fh
	return -code error "not a DOS executable"
    }
    seek $fh 60 start
    seek $fh [getword $fh] start
    set sig [read $fh 4]
    if {$sig eq "PE\000\000"} {
        seek $fh 24 current
        seek $fh [getdword $fh] start
    } elseif {[string match "NE*" $sig]} {
        seek $fh 34 current
        seek $fh [getdword $fh] start
    } else {
	close $fh
	return -code error "executable header not found"
    }

    return $fh
}

proc ::ico::calcSize {w h bpp {offset 0}} {
    # calculate byte size of ICO.
    # often passed $w twice because $h is double $w in the binary data
    set s [expr {int(($w*$h) * ($bpp/8.0)) \
		     + ((($w*$h) + ($h*($w%32)))/8) + $offset}]
    if {$bpp <= 8} { set s [expr {$s + (1 << ($bpp + 2))}] }
    return $s
}

proc ::ico::SearchForIcos {file fh {index -1}} {
    variable ICONS	  ; # stores icos offsets by index, and [list w h bpp]
    variable maxIcoSearch ; # don't look farther than this for icos
    set readsize 512	  ; # chunked read size

    if {[info exists ICONS($file,$index)]} {
	return $ICONS($file,$index)
    }

    set last   0 ; # tell point of last ico found
    set idx   -1 ; # index of icos found
    set pos    0
    set offset [tell $fh]
    set data   [read $fh $readsize]

    while {1} {
	if {$pos > ($readsize - 20)} {
	    if {[eof $fh] || ($last && ([tell $fh]-$last) >= $maxIcoSearch)} {
		# set the -1 index to indicate we've read the whole file
		set ICONS($file,-1) $idx
		break
	    }

	    seek $fh [expr {$pos - $readsize}] current
	    set offset [tell $fh]
	    set pos 0
	    set data [read $fh $readsize]
	}

	binary scan [string range $data $pos [expr {$pos + 20}]] iiissi s w h p bpp comp
	if {$s == 40 && $p == 1 && $comp == 0 && $w == ($h / 2)} {
	    set ICONS($file,[incr idx]) [expr {$offset + $pos}]
	    set ICONS($file,$idx,data)	[list $w $w $bpp]
	    # stop if we found requested index
	    if {$index >= 0 && $idx == $index} { break }
	    incr pos [calcSize $w $w $bpp 40]
	    set last [expr {$offset + $pos}]
	} else {
	    incr pos 4
	}
    }

    return $idx
}

proc ::ico::IconStatsDLL   {args} {eval IconStatsEXE   $args}
proc ::ico::extractIconDLL {args} {eval extractIconEXE $args}
proc ::ico::writeIconDLL   {args} {eval writeIconEXE   $args}

proc ::ico::IconStatsICL   {args} {eval IconStatsEXE   $args}
proc ::ico::extractIconICL {args} {eval extractIconEXE $args}
proc ::ico::writeIconICL   {args} {eval writeIconEXE   $args}

proc ::ico::reset {{file {}}} {
    variable ICONS
    if {$file ne ""} {
	array unset ICONS $file,*
    } else {
	unset ICONS
	array set ICONS {}
    }
}

proc ::ico::IconStatsEXE {file} {
    variable ICONS

    set file [file normalize $file]
    set fh   [checkEXE $file]
    set cnt  [SearchForIcos $file $fh]
    #puts [time {set cnt  [SearchForIcos $file $fh]}]

    set icons [list]
    for {set i 0} {$i <= $cnt} {incr i} {
	lappend icons $ICONS($file,$i,data)
    }

    close $fh
    return $icons
}

proc ::ico::extractIconEXE {file index} {
    variable ICONS

    set file [file normalize $file]
    set fh   [checkEXE $file]
    set cnt  [SearchForIcos $file $fh $index]

    if {$cnt < $index} { return -code error "index out of range" }

    set idx $ICONS($file,$index)
    set ico $ICONS($file,$index,data)

    seek $fh [expr {$idx + 40}] start

    # readDIB returns: {palette xor and}
    set pxa [eval [list readDIB $fh] $ico] ; # $ico == $w $h $bpp
    close $fh
    return [concat $ico $pxa]
}

proc ::ico::writeIconEXE {file index w0 h0 bpp0 palette xor and} {
    variable ICONS

    set file [file normalize $file]
    set fh   [checkEXE $file r+]
    set cnt  [SearchForIcos $file $fh $index]

    if {$cnt < $index} { return -code error "index out of range" }

    set idx $ICONS($file,$index)
    set ico $ICONS($file,$index,data)
    foreach {w h bpp} $ico { break }

    seek $fh [expr {$idx + 40}] start

    if {$w0 != $w || $h0 != $h || $bpp0 != $bpp} {
	close $fh
	return -code error "icon format differs from original"
    }
    puts -nonewline $fh $palette
    puts -nonewline $fh $xor
    puts -nonewline $fh $and
    close $fh
}

proc ::ico::EXEtoICO {exeFile icoFile} {
    variable ICONS

    set file [file normalize $exeFile]
    set fh   [checkEXE $file]
    set cnt  [SearchForIcos $file $fh]

    for {set i 0} {$i <= $cnt} {incr i} {
	set idx $ICONS($file,$i)
	set ico $ICONS($file,$i,data)
	seek $fh $idx start
	eval [list lappend dir] $ico
	append data [read $fh [eval calcSize $ico 40]]
    }
    close $fh

    # write them out to a file
    set ifh [open $icoFile w+]
    fconfigure $ifh -translation binary

    bputs $ifh sss 0 1 [expr {$cnt + 1}]
    set offset [expr {6 + (($cnt + 1) * 16)}]
    foreach {w h bpp} $dir {
        set colors 0
        if {$bpp <= 8} {set colors [expr {1 << $bpp}]}
        set s [calcSize $w $h $bpp 40]
        lappend fix $offset $s
        bputs $ifh ccccssii $w $h $colors 0 1 $bpp $s $offset
        set offset [expr {$offset + $s}]
    }
    puts -nonewline $ifh $data
    foreach {offset size} $fix {
        seek $ifh [expr {$offset + 20}] start
        bputs $ifh i $s
    }
    close $ifh
}

proc ::ico::ShowInit {{root .}} {
    # Return immediately if ShowInit is ready
    variable icon_widget
    if {[info exists icon_widget]} {
	if { [winfo exists $icon_widget] } { return }
    }

    # Allow user to force a particular toplevel
    set wname $root
    if {$root == "."} { set wname {} }
    if {![winfo exists $root]} { toplevel $root }

    # Add icon box
    frame $wname.ico -relief sunken -borderwidth 1
    set icon_widget $wname.ico.text
    set s $wname.ico.scroll
    text $icon_widget -yscroll [list $s set] -state disabled -width 10 \
	-borderwidth 0 -relief flat
    $icon_widget tag conf HR -border 1 -relief raised -tab 10i \
	-foreground black -background pink
    scrollbar $s -command [list $icon_widget yview] -relief flat -borderwidth 0
    grid $icon_widget $s -sticky news
    grid rowconf $wname.ico 0 -weight 1
    grid columnconf $wname.ico 0 -weight 1

    # Add background colour choices
    set bkg $wname.bkg
    frame $bkg
    variable color lightgray
    $icon_widget conf -background $color
    foreach c {
	white lightgray darkgray black
	red orange yellow green cyan blue magenta
    } {
	radiobutton $bkg.$c  -indicatoron false -background $c \
		-variable [namespace current]::color -value $c \
		-command [list $icon_widget conf -back $c -fore black] \
		-relief sunken -offrelief raised -selectcolor $c -padx 5
	pack $bkg.$c -side left -expand yes -fill both
    }
    $bkg.black conf -command [list $icon_widget conf -fore white -back black]
	

    # Pack top level
    grid $wname.ico -sticky news
    grid $wname.bkg -sticky w
    grid rowconf $root 0 -weight 1
    grid columnconf $root 0 -weight 1

    # Magnifier $wname.mag $icon_widget
}

proc ::ico::Magnifier {w t} {

    package require Img
    if {[winfo exist $w]} {
	wm deiconify $w
	wm raise $w
    } else {
	toplevel $w
	wm title $w Magnifier
	variable mag_image
	set mag_image [image create photo -width 192 -height 192]
	grid [label $w.l -image $mag_image]
	bind $t <Motion> [namespace code {Magnify %W %x %y}]
    }
}
	
proc ::ico::Magnify { w x y } {

    variable mag_image
    set width [winfo width $w]
    set height [winfo height $w]
    if { $x < 12 } { set x 12 }
    if { $x > $width - 13 } { set x [expr {$width - 13}] }
    if { $y < 12 } { set y 12 }
    if { $y > $height - 13 } { set y [expr {$height - 13}] }

    set from [image create photo -format window -data $w]
    $mag_image copy $from -zoom 8 \
	-from [expr { $x - 12 } ] [expr {$y - 12} ] \
		[expr { $x + 12 } ] [expr {$y + 12} ] \
	-to 0 0 191 191
    rename $from {}
}
	

# Application level command: Find icons in a file and show them.
proc ::ico::Show {file {type {}}} {
    set file [file normalize $file]
    if {$type eq ""} {
	set type [string trimleft [string toupper [file extension $file]] .]
    }
    if {$type eq "DLL"} { set type "EXE" }
    set icos  [IconStats$type $file]
    set wname [string map {. _ : _} $file]

    # Add icons and descriptions
    ShowInit
    variable icon_widget
    $icon_widget conf -state normal
    if {![llength $icos]} {
	$icon_widget insert end "$file\t" HR "\n  no icons\n\n"
    } else {
        $icon_widget insert end "$file\t" HR "\n  [llength $icos] icons\n\n"

	# Fill in the icons
	for {set x 0} {$x < [llength $icos]} {incr x} {
	    # catch in case theres any icons with unsupported color
	    if {[catch {getIconImage $file $type $x} img]} {
		set txt "ERROR: $img"
		$icon_widget insert end "$txt\n\n"
	    } else {
		set txt [eval {format "$x: %sx%s %sbpp"} [lindex $icos $x]]
		$icon_widget insert end "$txt\n"
		$icon_widget image create end -image $img -align center
		$icon_widget insert end \n\n
	    }
	}
    }
    $icon_widget conf -state disabled
}

if {[info exists argv0] && [file tail [info script]]==[file tail $argv0]} {
    package require Tk
    foreach arg $argv { ::ico::Show $arg }
}

package provide ico 0.1

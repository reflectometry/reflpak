    # From the wiki
    # http://mini.net/tcl/sizer%20control
    # signed: <mail@kai-morich.de>
    package provide sizer 0.1

    namespace eval ::sizer {
        namespace export -clear sizer
    }

    proc ::sizer::sizer {win} {
        variable config
        variable f
        if {$win=="."} {
            set config($win-widget) .sizer
        } else {
            set config($win-widget) $win.sizer
        }
        canvas $config($win-widget) -width 16 -height 16 -cursor "size_nw_se" -bg SystemButtonFace
        foreach i {3 7 11} {
            # -width 2 means 2point on win98 and 2pixel on w2k
            $config($win-widget) create line [expr $i+2] 16 16 [expr $i+2] -width 1 -fill SystemButtonShadow
            $config($win-widget) create line [expr $i+1] 16 16 [expr $i+1] -width 1 -fill SystemButtonShadow
            $config($win-widget) create line       $i    16 16       $i    -width 1 -fill SystemButtonHighlight
        }

        set config($win-zoomed) 2 ;# not 0/1
        bind $config($win-widget) <Button-1>  [namespace code [list sizer_start $win %X %Y]]
        bind $config($win-widget) <B1-Motion> [namespace code [list sizer_move $win %X %Y]]
        bind $win                 <Configure> [namespace code [list sizer_update $win]]
    }

    proc ::sizer::sizer_update {win} {
        variable config
        set zoomed [string equal [wm state $win] "zoomed"]
        if {$zoomed!=$config($win-zoomed)} {
            set config($win-zoomed) $zoomed
            if {$zoomed} {
                place forget $config($win-widget)
            } else {
                set x [expr {-16+[$win cget -padx]}]
                set y [expr {-16+[$win cget -pady]}]
                place $config($win-widget) -relx 1.0 -rely 1.0 -x $x -y $y
            }
        }
    }

    proc ::sizer::sizer_start {win x y} {
        variable config
        set config($win-x) $x
        set config($win-y) $y
        scan [wm geometry $win] "%dx%d" config($win-width) config($win-height)
    }

    proc ::sizer::sizer_move {win x y} {
        variable config
        set width  [expr $config($win-width) +$x-$config($win-x)]
        set height [expr $config($win-height)+$y-$config($win-y)]
        catch {wm geometry $win ${width}x${height} }
    }

    namespace eval :: {namespace import -force ::sizer::sizer }

 # Extracted from http://mini.net/tcl/4238  Portable keystate  2005-05-13
 # added package provide and supressed demo unless wish keystate.tcl
 package provide keystate 0.1

 # Donald Arseneau writes:
 #  The preceding doesn't handle multiple modifier keys held down at the 
 #  same time. Nor does it work when a key is being held while the focus 
 #  enters the application. Here is the increased bookkeeping and binding 
 #  needed to make sense of those situations. But it still does not always 
 #  work. Better would be for Tk to provide portable mnemonics for keystate, 
 #  in addition to the numeric %s.

 #  Internal record of modifier-key states
 namespace eval KeyState {
    variable Control   0
    variable Control_L 0
    variable Control_R 0
    variable Alt     0
    variable Alt_L   0
    variable Alt_R   0
    variable Shift   0
    variable Shift_L 0
    variable Shift_R 0

    proc modPress {modifier RL} {
        #puts "$modifier pressed"
        set KeyState::${modifier}_${RL} 1
        set KeyState::${modifier} 1
    }

    proc modRelease {modifier RL} {
        #puts "$modifier released"
        set KeyState::${modifier}_${RL} 0
        set k [expr \
            { [set KeyState::${modifier}_R] || [set KeyState::${modifier}_L] } ]
        if { $k != [set KeyState::${modifier}] } {
            set KeyState::${modifier} $k
        }
    }

 }

 foreach {modifier RL} [list Control R Control L Shift R Shift L Alt R Alt L] {
    bind all <KeyPress-${modifier}_${RL}> [list + KeyState::modPress $modifier $RL]
    bind all <KeyRelease-${modifier}_${RL}> [list + KeyState::modRelease $modifier $RL]
 }

 # That is sufficient to keep track of the modifier keys while the application
 # has focus, but what if a user presses, and holds, Shift while working in
 # some other application?  Now we bind all combinations of the <Enter> event
 # (that's the mouse cursor entering a window, not the Enter key) to update the
 # status of modifier keys when the user returns attention to our application.
 #
 # We will only set the key-state variables when they actually *change*.
 # This means variable traces won't be firing every time the mouse moves
 # between widgets.
 #
 # We will bind to "all", but you may want to set the bindings for a particular
 # toplevel window or even a specific widget.  Note: these bindings are in
 # addition to previously existing bindings.
 #
 # These combinations could be done in an obscure loop, but let's be explicit.

 namespace eval KeyState {
    proc modEnterOneKey { key state } {
        if { [set KeyState::$key] != $state } {
            set KeyState::$key $state
        }
        if { $state == 0 } {
            set KeyState::${key}_L 0
            set KeyState::${key}_R 0
        }
    }

    proc modEnter { c s a } {
        modEnterOneKey Control $c
        modEnterOneKey Shift   $s
        modEnterOneKey Alt     $a
    }

    namespace export *
 }

 bind all <Control-Shift-Alt-Enter> {+KeyState::modEnter 1 1 1 }
 bind all <Control-Shift-Enter> {+KeyState::modEnter 1 1 0 }
 bind all <Control-Alt-Enter> {+KeyState::modEnter 1 0 1 }
 bind all <Shift-Alt-Enter> {+KeyState::modEnter 0 1 1 }
 bind all <Control-Enter> {+KeyState::modEnter 1 0 0 }
 bind all <Shift-Enter> {+KeyState::modEnter 0 1 0 }
 bind all <Alt-Enter> {+KeyState::modEnter 0 0 1 }
 bind all <Enter> {+KeyState::modEnter 0 0 0 }

 bind all <Enter> {+KeyState::modEnter 0 0 0 }

if {[info exists argv0] && [file tail [info script]]==[file tail $argv0]} {
 ##############################################################################
 #
 #  Demonstration:
 #  Control-Shift-Alt modifiers displayed by direct association (-variable and
 #  -textvariable) and by variable traces
 #
 ##############################################################################

 trace variable KeyState::Control w {showState .cl}
 trace variable KeyState::Shift   w {showState .sl}
 trace variable KeyState::Alt     w {showState .al}

 proc showState { win var nil op } {
    puts "Keystate for $var is now [set $var]"
    if { [set $var] } {
        $win configure -text "Pressed"
    } else {
        $win configure -text "Released"
    }
 }

 checkbutton .cc -justify left -variable KeyState::Control -text "Control"
 label .cl -width 12 -justify left -text "Released" -bd 2 -relief sunken
 label .cv -width 3 -textvariable KeyState::Control -bd 2 -relief sunken

 checkbutton .sc -justify left -variable KeyState::Shift -text "Shift"
 label .sl -width 12 -justify left -text "Released" -bd 2 -relief sunken
 label .sv -width 3 -textvariable KeyState::Shift -bd 2 -relief sunken

 checkbutton .ac -justify left -variable KeyState::Alt -text "Alt"
 label .al -width 12 -justify left -text "Released" -bd 2 -relief sunken
 label .av -width 3 -textvariable KeyState::Alt -bd 2 -relief sunken

 grid .cc -in .  -row 1 -column 1 -sticky w
 grid .cl -in .  -row 1 -column 2
 grid .cv -in .  -row 1 -column 3
 grid .sc -in .  -row 2 -column 1 -sticky w
 grid .sl -in .  -row 2 -column 2
 grid .sv -in .  -row 2 -column 3
 grid .ac -in .  -row 3 -column 1 -sticky w
 grid .al -in .  -row 3 -column 2
 grid .av -in .  -row 3 -column 3
}

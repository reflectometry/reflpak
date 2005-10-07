## This is the mlayer/gj2 resource file.
## Copy this file to ~/.mlayer and change the 
## bits that you want.

## XXX FIXME XXX move all of these to X11 resource specifications in
## tkmlayerrc/.tkmlayerrc

## The next couple of lines are here to protect against changes in
## requirements for the resource file.  If new definitions are
## required for future versions of mlayer, then RESOURCE_VERSION will
## be changed but your copy in ~/.mlayer will still contain the old
## VERSION and you will be warned.
set RESOURCE_VERSION 0.0.1
if { "$RESOURCE_VERSION" != "$VERSION" } {
    message -warn "~/.mlayer (v$RESOURCE_VERSION) does not match mlayer.tcl (v$VERSION) and so it will be ignored"
    return 0
}


## ==============================================================
## Arbitrary constants you may want to change

# how many digits of results to show in layer table and in the fit results
set ::digits 7

## Bitmap for roughness handle (the thing you click and drag to move
## or change the layer parameters).  The default is a 7x7 box.
bitmap define box {{7 7} { 0x7F 0x41 0x41 0x41 0x41 0x41 0x7F }}

# Set hidden(xxx) to 1 to hide the associated graph line (initially).  You
# can click on the legend entry to get it back.
if { $::MAGNETIC } {
    set hidden(qcsq) 0
    set hidden(mu) 1
    set hidden(mqcsq) 0
    set hidden(theta) 0
    set hidden(reflecta) 0
    set hidden(reflectb) 1
    set hidden(reflectc) 1
    set hidden(reflectd) 0
    set hidden(dataa) 0
    set hidden(datab) 1
    set hidden(datac) 1
    set hidden(datad) 0
} else {
    set hidden(qcsq) 0
    set hidden(mu) 1
    set hidden(reflect) 0
    set hidden(data) 0
}

# Colours for various lines and widget components
set color(depth) black
set color(qcsq) brown
set color(mu) blue
if { $::MAGNETIC } {
    set color(mdepth) purple
    set color(mqcsq) orange
    set color(theta) darkgreen
} else {
    set color(repeat) lightgray ;# background color for the repeating section
}


# dash patterns for printing to B&W printer
set dashes(qcsq) { 1 1 }
set dashes(mu)   { 4 2 }
if { $::MAGNETIC } {
    set dashes(mqcsq) { 3 1 1 1 }
    set dashes(theta) { 5 1 2 1 }
    set dashes(ra) { 1 1 }
    set dashes(rd) { 4 2 }
    set dashes(rb) { 3 1 1 1 }
    set dashes(rc) { 5 1 2 1 }
} else {
    set dashes(r)  { 1 1 }
}

# Whether dashes are used on screen
# You probably don't want this since BLT makes it look ugly
set use_dashes_on_screen 0

# Whether dashes are used on printer
# If your printer is black and white, you will want to use
# dashed lines when printing.
set use_dashes_on_printer 1
set use_color_on_printer 0

# Set the following based on the speed of your machine.  If it is
# fast, then you will be able to lower the numbers and get more
# responsive tracking of the profile and reflectivity graphs when
# your are dragging the controls with your mouse.  If your machine
# is slow, then you will need to increase the delays to get smooth
# dragging of the controls, but the graphs will not be updated
# unless you are moving very slowly.
set profile_delay 25
set reflectivity_delay 125

# Whether hovering on a profile handle displays the coords
# Note that hovering is slightly broken: it is stuck in
# hover mode even if you are dragging the widget and the
# coordinates are not cleared even when you leave the widget
set do_hover 0

return 1

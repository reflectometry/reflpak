option add *Scrollbar.width 12
option add *Text.background white
option add *Button.padY 0
#option add *iPadX 5
#option add *iPadY 5
#option add *SelectBorderWidth 0
option add *HighlightThickness 1
option add *Frame.highlightThickness 0
option add *Toplevel.highlightThickness 0
option add *Labelframe.highlightThickness 0
option add *Label.anchor w
#option add *BorderWidth 1
#option add *Labelframe.borderWidth 2
#option add *Menubutton.borderWidth 1
#option add *Button.borderWidth 2
#option add *Entry.selectBorderWidth 0
#option add *Listbox.selectBorderWidth 0
option add *HandleSize 0
option add *sashWidth 4
bind Button <Key-Return> {tk::ButtonInvoke %W}

option add *Hiertable.ResizeCursor size_we 81

option add *Graph.Legend.Font {Helvetica -8} widgetDefault

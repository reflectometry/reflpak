switch $tcl_platform(platform) {
    windows {
	option add *Scrollbar.width 12 widgetDefault
	option add *Text.background white widgetDefault
	option add *Button.padY 0 widgetDefault
	#option add *iPadX 5 widgetDefault
	#option add *iPadY 5 widgetDefault
	#option add *SelectBorderWidth 0 widgetDefault
	option add *HighlightThickness 1 widgetDefault
	option add *Frame.highlightThickness 0 widgetDefault
	option add *Toplevel.highlightThickness 0 widgetDefault
	option add *Labelframe.highlightThickness 0 widgetDefault
	option add *Label.anchor w widgetDefault
	#option add *BorderWidth 1 widgetDefault
	#option add *Labelframe.borderWidth 2 widgetDefault
	#option add *Menubutton.borderWidth 1 widgetDefault
	#option add *Button.borderWidth 2 widgetDefault
	#option add *Entry.selectBorderWidth 0 widgetDefault
	#option add *Listbox.selectBorderWidth 0 widgetDefault
	option add *HandleSize 0 widgetDefault
	option add *sashWidth 4 widgetDefault
	bind Button <Key-Return> {tk::ButtonInvoke %W}
	
	option add *Hiertable.ResizeCursor size_we 81 widgetDefault
	
	option add *Graph.Legend.Font {Helvetica -8} widgetDefault
    }
}

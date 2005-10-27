package ifneeded ncnrlib 0.1 [subst {
    # delayed loading of other packages
    tclPkgSetup [list $dir] ncnrlib 0.1 {
	{pan.tcl source pan}
	{ctext.tcl source ctext}
	{balloonhelp.tcl source balloonhelp}
	{tableentry.tcl souce tableentry}
	{htext.tcl source {htext hpage}}
	{print.tcl source PrintDialog}
        {sizer.tcl source sizer}
        {mousewheel.tcl source mousewheel }
	{ncnrgui.tcl source {
	    sashconf 
	    listbox_ordered_insert listbox_delete_by_name
	    scroll vscroll hscroll
	    text_replace text_append text_clear text_load
	    addfields init_gui
	    widget_browser winpath
	}}
	{graph.tcl source {
	    active_legend legend_hidden legend_set
	    active_axis active_graph zoom
	    graph_select graph_select_list
	    graph_error blt_errorbars
	}}
    }

    # immediate definition of some functions
    source [list [file join $dir ncnrlib.tcl]]
    # if Tk is present do the GUI setup
    # Note: protect the test against subst so it is executed when needed
    if {\[info exists ::tk_version]} { init_gui }
}]
package ifneeded octave 0.1 [list source [file join $dir octave.tcl]]
package ifneeded keystate 0.1 [list source [file join $dir keystate.tcl]]


sinclude Makeconf
ifndef ARCH
  $(error Link <arch>/Makeconf to Makeconf and try again.)
endif

bwidgetfiles=$(wildcard $(BWIDGET)/*.tcl $(BWIDGET)/images/* $(BWIDGET)/lang/*)
tktablefiles=$(TKTABLE)/pkgIndex.tcl $(TKTABLE)/tkTable.tcl $(TKTABLE_EXT) 
tkdndfiles=$(TKDND)/pkgIndex.tcl $(TKDND)/tkdnd.tcl $(TKDND_EXT)

# IRIX's /bin/sh does not accept 'for f in ; do' so we need to give it
# a blank line and hope that freewrap is clever enough to skip blanks
# in the manifest
ifndef TKTABLE
  tktablefiles=""
endif
ifndef TKDND
  tkdndfiles=""
endif

# Where to find source
VPATH=src

# Path to current directory; use ?= so Makeconf can override
topdir ?= $(shell pwd)
bindir ?= $(topdir)/$(ARCH)


libsrc=balloonhelp.tcl ctext.tcl htext.tcl pan.tcl \
	print.tcl tableentry.tcl help2html
fitsrc=mlayer.tcl defaults.tcl generic.tcl tkmlayerrc help.help \
	mlayer.help reflfit.help reflpolorient.gif
redsrc=viewrun.tcl reduce.tcl psd.tcl choose.tcl generic.tcl \
	NG7monitor.cal viewrun.help
redoctavesrc=psdslice.m run_include.m run_scale.m run_trunc.m \
	interp1err.m run_avg.m run_interp.m run_sub.m runlog.m \
	plotrunop.m run_div.m run_poisson_avg.m run_tol.m

libfiles=$(patsubst %,$(topdir)/lib/%,$(libsrc))
fitfiles=$(patsubst %,$(topdir)/tcl/%,$(fitsrc)) $(libfiles)
redfiles=$(patsubst %,$(topdir)/reflred/%,$(redsrc)) $(libfiles) \
	$(patsubst %,$(topdir)/reflred/octave/%,$(redoctavesrc))

GMLAYER=$(bindir)/gmlayer$(LDEXT)
FITBIN=$(ARCH)/reflfit$(EXE) 
REDBIN=$(ARCH)/reflred$(EXE)
FITSCRIPT=$(ARCH)/reflfit.tcl
REDSCRIPT=$(ARCH)/reflred.tcl

all: makegmlayer $(ARCH)/reflfit$(EXE) $(ARCH)/reflred$(EXE)

$(ARCH)/reflfit$(EXE): $(ARCH)/freewrapBLT $(GMLAYER) $(ARCH)/reflfit.manifest \
		$(ARCH)/reflfit.tcl $(ARCH)/options.tcl \
		freewrap/loadwrap.tcl $(redfiles)
	cd $(ARCH) && ./freewrapBLT -e reflfit.tcl -f reflfit.manifest

$(ARCH)/options.tcl:

$(ARCH)/reflfit.tcl: reflfit.tcl.in
	sed -e 's,@WISH@,$(WISH),' \
		-e 's,@OCTAVE@,$(OCTAVE),' \
		-e 's,@TKCON@,$(TKCON),' \
		-e 's,@TKDND@,$(TKDND),' \
		-e 's,@TKTABLE@,$(TKTABLE),' \
		-e 's,@BWIDGET@,$(BWIDGET),' \
		-e 's,@TOPDIR@,$(topdir),' \
		-e 's,@ARCH@,$(bindir),' \
		-e 's,@GMLAYER@,$(GMLAYER),' < $< > $@
	chmod a+x $@

$(ARCH)/reflfit.manifest: Makefile
	$(RM) $@
	echo "$(TKCON)" >> $@
	for f in $(bwidgetfiles); do echo "$$f" >> $@ ; done
	for f in $(tkdndfiles); do echo "$$f" >> $@ ; done
	for f in $(tktablefiles); do echo "$$f" >> $@ ; done
	for f in $(fitfiles); do echo "$$f" >> $@ ; done
	echo "$(bindir)/options.tcl" >> $@ 
	echo "$(gmlayer)" >> $@

$(ARCH)/reflred$(EXE): $(ARCH)/freewrapBLT $(ARCH)/reflred.manifest \
		$(ARCH)/reflred.tcl $(ARCH)/options.tcl \
		freewrap/loadwrap.tcl $(redfiles)
	cd $(ARCH) && ./freewrapBLT -e reflred.tcl -f reflred.manifest

$(ARCH)/reflred.tcl: reflred.tcl.in
	sed -e 's,@WISH@,$(WISH),' \
		-e 's,@OCTAVE@,$(OCTAVE),' \
		-e 's,@TKCON@,$(TKCON),' \
		-e 's,@TKDND@,$(TKDND),' \
		-e 's,@TKTABLE@,$(TKTABLE),' \
		-e 's,@BWIDGET@,$(BWIDGET),' \
		-e 's,@TOPDIR@,$(topdir),' \
		-e 's,@ARCH@,$(bindir),' \
		< $< > $@
	chmod a+x $@

$(ARCH)/reflred.manifest: Makefile
	$(RM) $@
	echo "$(TKCON)" >> $@
	for f in $(bwidgetfiles); do echo "$$f" >> $@ ; done
	for f in $(tkdndfiles); do echo "$$f" >> $@ ; done
	for f in $(tktablefiles); do echo "$$f" >> $@ ; done
	for f in $(redfiles); do echo "$$f" >> $@ ; done
	echo "$(bindir)/options.tcl" >> $@

freewrap: Makeconf.tcltk
	cd $(ARCH) && $(MAKE) -f Makefile.freewrap

Makeconf.tcltk:
	$(error Use ./tclConfig2Makeconf to build Makeconf.tcltk)

makegmlayer:
	cd $(ARCH) && $(MAKE) -f $(topdir)/src/Makefile

clean:
	$(RM) $(ARCH)/*.o core $(ARCH)/reflfit.manifest $(ARCH)/reflred.manifest

distclean: clean
	$(RM) $(ARCH)/reflfit.tcl $(ARCH)/reflfit$(EXE) $(ARCH)/reflred.tcl $(ARCH)/reflred$(EXE) $(GMLAYER)


sinclude Makeconf
ifndef ARCH
  $(error Link <arch>/Makeconf to Makeconf and try again.)
endif

bwidgetfiles=$(wildcard \
	$(drive)$(BWIDGET)/*.tcl \
	$(drive)$(BWIDGET)/images/* \
	$(drive)$(BWIDGET)/lang/*)
tktablefiles=\
	$(drive)$(TKTABLE)/pkgIndex.tcl \
	$(drive)$(TKTABLE)/tkTable.tcl \
	$(drive)$(TKTABLE)/$(TKTABLE_EXT)
tkdndfiles=\
	$(drive)$(TKDND)/pkgIndex.tcl \
	$(drive)$(TKDND)/tkdnd.tcl \
	$(drive)$(TKDND)/$(TKDND_EXT)

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

libfiles=$(patsubst %,$(drive)$(topdir)/lib/%,$(libsrc))
fitfiles=\
	$(patsubst %,$(drive)$(topdir)/tcl/%,$(fitsrc)) \
	$(drive)$(topdir)/freewrap/loadwrap.tcl \
	$(libfiles)
redfiles=\
	$(patsubst %,$(drive)$(topdir)/reflred/%,$(redsrc)) \
	$(patsubst %,$(drive)$(topdir)/reflred/octave/%,$(redoctavesrc)) \
	$(drive)$(topdir)/freewrap/loadwrap.tcl \
	$(libfiles)

all: makegmlayer $(ARCH)/reflfit$(EXE) $(ARCH)/reflred$(EXE)

$(ARCH)/reflfit$(EXE): $(ARCH)/freewrapBLT $(ARCH)/reflfit.manifest \
		$(ARCH)/reflfit.tcl $(ARCH)/options.tcl $(fitfiles) \
		$(ARCH)/gmlayer$(LDEXT)
	cd $(ARCH) && ./freewrapBLT -e reflfit.tcl -f reflfit.manifest

$(ARCH)/reflfit.tcl: reflfit.tcl.in Makefile Makeconf
	sed -e 's,@WISH@,$(WISH),' \
		-e 's,@OCTAVE@,$(OCTAVE),' \
		-e 's,@TKCON@,$(TKCON),' \
		-e 's,@TKDND@,$(TKDND),' \
		-e 's,@TKTABLE@,$(TKTABLE),' \
		-e 's,@BWIDGET@,$(BWIDGET),' \
		-e 's,@TOPDIR@,$(topdir),' \
		-e 's,@ARCH@,$(bindir),' \
		-e 's,@GMLAYER@,$(bindir)/gmlayer$(LDEXT),' < $< > $@
	chmod a+x $@

$(ARCH)/reflfit.manifest: Makefile Makeconf
	echo "$(TKCON)" > $@
	for f in $(bwidgetfiles); do echo "$$f" >> $@ ; done
	for f in $(tkdndfiles); do echo "$$f" >> $@ ; done
	for f in $(tktablefiles); do echo "$$f" >> $@ ; done
	for f in $(fitfiles); do echo "$$f" >> $@ ; done
	echo "$(bindir)/options.tcl" >> $@
	echo "$(bindir)/gmlayer$(LDEXT)" >> $@

$(ARCH)/reflred$(EXE): $(ARCH)/freewrapBLT $(ARCH)/reflred.manifest \
		$(ARCH)/reflred.tcl $(ARCH)/options.tcl $(redfiles)
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

$(ARCH)/reflred.manifest: Makefile Makeconf
	echo "$(TKCON)" > $@
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
	cd $(ARCH) && $(MAKE) -f ../src/Makefile

clean:
	$(RM) $(ARCH)/*.o core \
		$(ARCH)/reflfit.manifest $(ARCH)/reflred.manifest

distclean: clean
	$(RM) $(ARCH)/reflfit.tcl $(ARCH)/reflfit$(EXE) \
		$(ARCH)/reflred.tcl $(ARCH)/reflred$(EXE) \
		$(ARCH)/gmlayer$(LDEXT)

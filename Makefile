
sinclude Makeconf
ifndef ARCH
  $(error Link <arch>/Makeconf to Makeconf and try again.)
endif

bwidgetfiles=$(wildcard \
	$(drive)$(BWIDGET)/*.tcl \
	$(drive)$(BWIDGET)/images/* \
	$(drive)$(BWIDGET)/lang/*)
tkconfiles=\
	$(drive)$(TKCON)/pkgIndex.tcl \
	$(drive)$(TKCON)/tkcon.tcl
tktablefiles=\
	$(drive)$(TKTABLE)/pkgIndex.tcl \
	$(drive)$(TKTABLE)/tkTable.tcl \
	$(drive)$(TKTABLE)/$(TKTABLE_EXT)
tkdndfiles=\
	$(drive)$(TKDND)/pkgIndex.tcl \
	$(drive)$(TKDND)/tkdnd.tcl \
	$(drive)$(TKDND)/$(TKDND_EXT)
octavefiles=\
	$(drive)$(OCTAVE)/pkgIndex.tcl \
	$(drive)$(OCTAVE)/octave.tcl \
	$(drive)$(OCTAVE)/tclphoto.m \
	$(drive)$(OCTAVE)/tclsend.m

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
	print.tcl tableentry.tcl generic.tcl
fithelp=reflfit.help help.help mlayer.help gj2.help
fitfig=reflpolorient.gif
fitsrc=mlayer.tcl defaults.tcl tkmlayerrc
redhelp=reflred.help help.help
redfig=footprint.gif fpflat.gif fplinear.gif
redsrc=viewrun.tcl loadicp.tcl loaduxd.tcl loadreduced.tcl \
	reduce.tcl psd.tcl choose.tcl NG7monitor.cal tkviewrunrc 
redoctavesrc=psdslice.m run_include.m run_scale.m run_trunc.m \
	interp1err.m run_avg.m run_interp.m run_sub.m runlog.m \
	plotrunop.m run_div.m run_poisson_avg.m run_tol.m

fithelpdeps=$(patsubst %,tcl/%,$(fithelp) $(fitfig))
redhelpdeps=$(patsubst %,reflred/%,$(redhelp) $(redfig))

libfiles=$(patsubst %,$(drive)$(topdir)/lib/%,$(libsrc))
fitfiles=\
	$(patsubst %,$(drive)$(topdir)/tcl/%,$(fithelp)) \
	$(patsubst %,$(drive)$(topdir)/tcl/%,$(fitfig)) \
	$(patsubst %,$(drive)$(topdir)/tcl/%,$(fitsrc)) \
	$(drive)$(topdir)/freewrap/loadwrap.tcl \
	$(libfiles)
redfiles=\
	$(patsubst %,$(drive)$(topdir)/reflred/%,$(redhelp)) \
	$(patsubst %,$(drive)$(topdir)/reflred/%,$(redfig)) \
	$(patsubst %,$(drive)$(topdir)/reflred/%,$(redsrc)) \
	$(patsubst %,$(drive)$(topdir)/reflred/octave/%,$(redoctavesrc)) \
	$(drive)$(topdir)/freewrap/loadwrap.tcl \
	$(libfiles)

.PHONY: makegmlayer makegj2 freewrap 

all: makegmlayer makegj2 $(ARCH)/reflpol$(EXE) $(ARCH)/reflfit$(EXE) $(ARCH)/reflred$(EXE)

html: html/reflred/index.html html/reflfit/index.html

html/reflred/index.html: lib/help2html $(ARCH)/reflred$(EXE) $(redhelpdeps)
	rm -rf html/reflred
	lib/help2html reflred windows $(ARCH)/reflred_version.tcl $(redhelpdeps)

html/reflfit/index.html: lib/help2html $(ARCH)/reflfit$(EXE) $(fithelpdeps)
	rm -rf html/reflfit
	lib/help2html reflfit introduction $(ARCH)/reflfit_version.tcl $(fithelpdeps)

$(ARCH)/reflfit$(EXE): $(ARCH)/freewrapBLT $(ARCH)/reflfit.manifest \
		$(ARCH)/reflfit.tcl $(ARCH)/options.tcl $(fitfiles) \
		$(ARCH)/gmlayer$(LDEXT)
	cd $(ARCH) && echo "set app_version {Reflfit `date +%Y-%m-%d` for $(ARCH)}" > reflfit_version.tcl
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
	@echo "Building reflfit manifest"
	@for f in $(tkconfiles); do echo "$$f" >> $@ ; done
	@for f in $(bwidgetfiles); do echo "$$f" >> $@ ; done
	@for f in $(tkdndfiles); do echo "$$f" >> $@ ; done
	@for f in $(tktablefiles); do echo "$$f" >> $@ ; done
	@for f in $(fitfiles); do echo "$$f" >> $@ ; done
	@echo "$(bindir)/options.tcl" >> $@
	@echo "$(bindir)/reflfit_version.tcl" >> $@
	@echo "$(bindir)/gmlayer$(LDEXT)" >> $@

$(ARCH)/reflpol$(EXE): $(ARCH)/freewrapBLT $(ARCH)/reflpol.manifest \
		$(ARCH)/reflpol.tcl $(ARCH)/options.tcl $(fitfiles) \
		gj2/gj2$(LDEXT)
	cd $(ARCH) && echo "set app_version {Reflpol `date +%Y-%m-%d` for $(ARCH)}" > reflpol_version.tcl
	cd $(ARCH) && ./freewrapBLT -e reflpol.tcl -f reflpol.manifest

$(ARCH)/reflpol.tcl: reflpol.tcl.in Makefile Makeconf
	sed -e 's,@WISH@,$(WISH),' \
		-e 's,@OCTAVE@,$(OCTAVE),' \
		-e 's,@TKCON@,$(TKCON),' \
		-e 's,@TKDND@,$(TKDND),' \
		-e 's,@TKTABLE@,$(TKTABLE),' \
		-e 's,@BWIDGET@,$(BWIDGET),' \
		-e 's,@TOPDIR@,$(topdir),' \
		-e 's,@ARCH@,$(bindir),' \
		-e 's,@GJ2@,$(topdir)/gj2/gj2$(LDEXT),' < $< > $@
	chmod a+x $@

$(ARCH)/reflpol.manifest: Makefile Makeconf
	@echo "Building reflpol manifest"
	@for f in $(tkconfiles); do echo "$$f" >> $@ ; done
	@for f in $(bwidgetfiles); do echo "$$f" >> $@ ; done
	@for f in $(tkdndfiles); do echo "$$f" >> $@ ; done
	@for f in $(tktablefiles); do echo "$$f" >> $@ ; done
	@for f in $(fitfiles); do echo "$$f" >> $@ ; done
	@echo "$(bindir)/options.tcl" >> $@
	@echo "$(bindir)/reflpol_version.tcl" >> $@
	@echo "$(topdir)/gj2/gj2$(LDEXT)" >> $@


$(ARCH)/reflred$(EXE): $(ARCH)/freewrapBLT $(ARCH)/reflred.manifest \
		$(ARCH)/reflred.tcl $(ARCH)/options.tcl $(redfiles)
	cd $(ARCH) && echo "set app_version {Reflred `date +%Y-%m-%d` for $(ARCH)}" > reflred_version.tcl
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
	@echo "Building reflred manifest"
	@for f in $(tkconfiles); do echo "$$f" >> $@ ; done
	@for f in $(bwidgetfiles); do echo "$$f" >> $@ ; done
	@for f in $(tkdndfiles); do echo "$$f" >> $@ ; done
	@for f in $(tktablefiles); do echo "$$f" >> $@ ; done
	@for f in $(redfiles); do echo "$$f" >> $@ ; done
	@for f in $(octavefiles); do echo "$$f" >> $@ ; done
	@echo "$(bindir)/reflred_version.tcl" >> $@
	@echo "$(bindir)/options.tcl" >> $@

freewrap: Makeconf.tcltk
	cd $(ARCH) && $(MAKE) -f Makefile.freewrap

freewrapclean:
	cd $(ARCH) && $(MAKE) -f Makefile.freewrap distclean

Makeconf.tcltk:
	$(error Use ./tclConfig2Makeconf to build Makeconf.tcltk)

makegmlayer:
	cd $(ARCH) && $(MAKE) -f ../src/Makefile

makegj2:
	cd gj2 && $(MAKE)

clean:
	$(RM) $(ARCH)/*.o gj2/*.o core \
		$(ARCH)/reflfit.manifest $(ARCH)/reflred.manifest

distclean: clean
	$(RM) $(ARCH)/reflfit.tcl $(ARCH)/reflfit$(EXE) \
		$(ARCH)/reflred.tcl $(ARCH)/reflred$(EXE) \
		$(ARCH)/gmlayer$(LDEXT) gj2/gj2$(LDEXT) \
		$(ARCH)/refl{fit,red,pol}_version.tcl

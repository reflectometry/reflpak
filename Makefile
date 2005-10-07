
sinclude Makeconf
ifndef ARCH
  $(error Link <arch>/Makeconf to Makeconf and try again.)
endif

VERSION = $(shell date +-%Y.%m.%d)
VERSIONTAG = $(shell date +%Y%m%d)
TAR ?= tar
RC ?= windres
NCNRKIT ?= $(HOME)/bin/ncnrkit$(EXE)
SDXKIT ?= $(HOME)/bin/sdx.kit

pakicon=icons/yellowpack.ico
redicon=icons/Ryellow.ico
fiticon=icons/Fyellow.ico
policon=icons/Pyellow.ico
wishicon=icons/wish.ico

# Path to current directory; use ?= so Makeconf can override
topdir ?= $(shell pwd)
bindir ?= $(topdir)/$(ARCH)

scifunsrc=pkgIndex.tcl scifun$(LDEXT)

paksrc=pkgIndex.tcl reflpak.tcl wininstall.tcl
libsrc=balloonhelp.tcl ctext.tcl htext.tcl pan.tcl sizer.tcl \
	print.tcl tableentry.tcl ncnrlib.tcl ncnrgui.tcl pkgIndex.tcl \
	octave.tcl tclphoto.m tclsend.m keystate.tcl graph.tcl
fithelp=reflfit.help help.help mlayer.help gj2.help
fitfig=reflpolorient.gif
fitsrc=mlayer.tcl defaults.tcl tkmlayerrc pkgIndex.tcl \
	makeconstrain.tcl gmlayer$(LDEXT) gj2$(LDEXT)
redhelp=reflred.help help.help
redfig=footprint.gif fpflat.gif fplinear.gif
redsrc=viewrun.tcl loadicp.tcl loadice.tcl loaduxd.tcl loadreduced.tcl \
	reduce.tcl psd.tcl choose.tcl NG7monitor.cal tkviewrunrc \
	footprint.tcl monitor.tcl atten.tcl pkgIndex.tcl abfoot.tcl
redoctavesrc=psdslice.m run_include.m run_scale.m run_trunc.m \
	run_avg.m run_interp.m run_sub.m runlog.m \
	plotrunop.m run_div.m run_poisson_avg.m run_tol.m run_send.m \
	footprint_fit.m footprint_gen.m footprint_interp.m \
	reduce.m reduce_part.m run_send.m run_send_pol.m \
	polcor.m fitslits.m run_invscale.m 
octlib=common_values.m inputname.m polyconf.m qlfit.m wsolve.m \
	confidence.m qlconf.m wpolyfit.m interp1err.m

reflplotsrc=axis.tcl base.tcl meshplot.tcl pkgIndex.tcl  \
	reflplot.tcl plot$(LDEXT) joh00909.cg1 joh00916.cg1
snitsrc=snit.tcl pkgIndex.tcl

fithelpdeps=$(patsubst %,tcl/%,$(fithelp) $(fitfig))
redhelpdeps=$(patsubst %,reflred/%,$(redhelp) $(redfig))

scifunfiles=$(patsubst %,scifun/%,$(scifunsrc))
pakfiles=$(patsubst %,reflpak/%,$(paksrc))
libfiles=$(patsubst %,lib/%,$(libsrc))
fitfiles=$(patsubst %,tcl/%,$(fithelp) $(fitfig) $(fitsrc))
redfiles=$(patsubst %,reflred/%,$(redhelp) $(redfig) $(redsrc))
redoctavefiles=$(patsubst %,reflred/octave/%,$(redoctavesrc) $(octlib))
snitfiles=$(patsubst %,snit0.97/%,$(snitsrc))
reflplotfiles=$(patsubst %,meshplot/%,$(reflplotsrc))


macscripts=$(patsubst %,macosx/%.app,reflpak reflred reflfit reflpol)

SUBDIRS=src gj2 scifun meshplot

ifeq ($(ARCH),win)
  pakicons=reflpak/pak.ico reflpak/wish.ico
  fiticons=tcl/fit.ico tcl/pol.ico
  redicons=reflred/red.ico
  SUBDIRS+=winlink
  winlinksrc=pkgIndex.tcl winreg.tcl winlink$(LDEXT)
  winlinkfiles=$(patsubst %,winlink/%,$(winlinksrc))
  addwinlink=./vfslib reflpak winlink $(winlinkfiles)
else
  addwinlink=:
endif

icons=$(fiticons) $(pakicons) $(redicons)

.PHONY: $(SUBDIRS) ChangeLog

all: $(SUBDIRS) kit kit/reflpak$(EXE)

kit:
	mkdir kit

kit/reflpak.exe: kit/reflpak kit/reflpak.res win/bindres.sh
	cd kit && ../win/bindres.sh reflpak.exe reflpak.res

kit/reflpak.res: win/reflpak.rc $(icons)
	cd win && $(RC) reflpak.rc ../kit/reflpak.res

kit/copykit$(EXE): $(NCNRKIT)
	cp $(NCNRKIT) kit/copykit$(EXE)

ncnrpack$(EXE): kit/copykit$(EXE) ncnrpack.vfs/main.tcl
	kit/copykit $(SDXKIT) wrap ncnrpack$(EXE) -runtime $(NCNRKIT)
	touch ncnrpack ;# needed to trigger resource binding on ncnrpack.exe

kit/reflpak: $(fitfiles) $(redfiles) $(redoctavefiles) $(winlinkfiles) \
		$(snitfiles) $(reflplotfiles) \
		$(scifunfiles) $(libfiles) $(pakfiles) $(icons) \
		kit/copykit$(EXE) main.tcl Makefile vfslib
	./vfslib reflpak
	./vfslib reflpak ncnrlib $(libfiles)
	./vfslib reflpak scifun $(scifunfiles)
	./vfslib reflpak snit $(snitfiles)
	$(addwinlink)
	./vfslib reflpak reflfit $(fitfiles) $(fiticons) $(gmlayer) $(gj2)
	./vfslib reflpak reflred $(redfiles) $(redicons)
	./vfslib reflpak reflred/octave $(redoctavefiles)
	./vfslib reflpak reflpak $(pakfiles) $(pakicons)
	./vfslib reflpak reflplot $(reflplotfiles)
	echo "set ::app_version {`date +%Y-%m-%d` for $(ARCH)}" \
		> kit/reflpak.vfs/main.tcl
	cat main.tcl >> kit/reflpak.vfs/main.tcl
	cd kit && ./copykit $(SDXKIT) wrap reflpak$(EXE) -runtime $(NCNRKIT)
	touch kit/reflpak ;# needed to trigger resource binding on reflpak.exe

reflred/red.ico: $(redicon)
	cp $(redicon) $@

tcl/fit.ico: $(fiticon)
	cp $(fiticon) $@

tcl/pol.ico: $(policon)
	cp $(policon) $@

reflpak/pak.ico: $(pakicon)
	cp $(pakicon) $@

reflpak/wish.ico: $(wishicon)
	cp $(wishicon) $@

html: html/reflred/index.html html/reflfit/index.html

pdf: html

html/reflred/index.html: lib/help2html $(redhelpdeps)
	rm -rf html/reflred
	$(NCNRKIT) lib/help2html reflred windows $(redversion) $(redhelpdeps)

html/reflfit/index.html: lib/help2html $(fithelpdeps)
	rm -rf html/reflfit
	$(NCNRKIT) lib/help2html reflfit introduction $(fitversion) $(fithelpdeps)

Makeconf.tcltk:
	$(error Use ./tclConfig2Makeconf to build Makeconf.tcltk)

$(SUBDIRS):
	cd $@ && $(MAKE)

ChangeLog:
	cvs2cl.pl --fsf --file ChangeLog > /dev/null

tagdist:
	cvs rtag R$(VERSIONTAG) reflfit

srcdist: ChangeLog
	cvs -q export -r HEAD -d reflpak$(VERSION)-src reflfit >/dev/null
	cp ChangeLog reflpak$(VERSION)-src
	if test ! -d release ; then mkdir release ; fi
	tar czf release/reflpak$(VERSION)-src.tar.gz reflpak$(VERSION)-src
	$(RM) -rf reflpak$(VERSION)-src

datadist: release/reflpak-data.zip

release/reflpak-data.zip: DIR=reflpak-data
release/reflpak-data.zip: data/README data/ss02/*.ng1 data/ss02-fit/*
	if test -d $(DIR) ; then rm -rf $(DIR); fi
	mkdir $(DIR)
	cp -p README $(DIR)/README.ss02
	mkdir $(DIR)/ss02
	cp -p data/ss02/*.ng1 $(DIR)/ss02
	mkdir $(DIR)/ss02-fit
	cp -p data/ss02-fit/*.{staj,log} $(DIR)/ss02-fit
	zip -r $@ $(DIR)
	rm -rf $(DIR)

ifeq ($(ARCH),macosx)

dist: kit/reflpak $(macscripts) RELEASE-NOTES
	if test -d diskimage ; then rm -rf diskimage ; fi
	mkdir diskimage
	mkdir diskimage/reflpak$(VERSION)
	cp -p kit/reflpak RELEASE-NOTES diskimage/reflpak$(VERSION)
	ditto -rsrc $(macscripts) diskimage/reflpak$(VERSION)
	ditto -rsrc data diskimage/data
	ditto -rsrc macosx/README diskimage
	cd diskimage && ../macosx/dmgpack.sh reflpak$(VERSION) README reflpak$(VERSION) data
	if test ! -d release ; then mkdir release ; fi
	mv diskimage/reflpak$(VERSION).dmg release
	rm -rf diskimage

else
ifeq ($(ARCH),win)

dist: kit/reflpak$(EXE)
	if test ! -d release ; then mkdir release ; fi
	cp -a kit/reflpak$(EXE) release/reflpak$(VERSION)$(EXE)

else

dist: DIR=reflpak$(VERSION)-$(ARCH)
dist: kit/reflpak$(EXE) RELEASE-NOTES
	if test -d $(DIR) ; then rm -rf $(DIR); fi
	mkdir $(DIR)
	cp -p RELEASE-NOTES linux/README $(DIR)
	cp -p kit/reflpak $(DIR)/reflpak$(VERSION)
	cp -pR data $(DIR)/data
	sed -e "s,@VERSION@,$(VERSION),g;s,@PAR@,,g" \
		< linux/reflpak.in > $(DIR)/reflpak
	sed -e "s,@VERSION@,$(VERSION),g;s,@PAR@,red,g" \
		< linux/reflpak.in > $(DIR)/reflred
	sed -e "s,@VERSION@,$(VERSION),g;s,@PAR@,fit,g" \
		< linux/reflpak.in > $(DIR)/reflfit
	sed -e "s,@VERSION@,$(VERSION),g;s,@PAR@,pol,g" \
		< linux/reflpak.in > $(DIR)/reflpol
	chmod a+rx $(DIR)/refl{pak,red,fit,pol}
	if test ! -d release ; then mkdir release ; fi
	tar cf release/$(DIR).tar $(DIR)
	if test -f release/$(DIR).tar.gz; then rm release/$(DIR).tar.gz; fi
	gzip release/$(DIR).tar
	rm -rf $(DIR)

endif
endif

clean:
	$(RM) */*.o *~ */*~ core

distclean: clean
	$(RM) $(redbin) $(fitbin) $(polbin) $(gmlayer) $(gj2)

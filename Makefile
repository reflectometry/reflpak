
sinclude Makeconf
ifndef ARCH
  $(error Link <arch>/Makeconf to Makeconf and try again.)
endif

VERSION = $(shell date +%Y%m%d)
TAR ?= tar
RC ?= windres

pakicon=icons/yellowpack.ico
redicon=icons/Ryellow.ico
fiticon=icons/Fyellow.ico
policon=icons/Pyellow.ico

# Path to current directory; use ?= so Makeconf can override
topdir ?= $(shell pwd)
bindir ?= $(topdir)/$(ARCH)

scifunsrc=pkgIndex.tcl scifun$(LDEXT)

paksrc=pkgIndex.tcl reflpak.tcl wininstall.tcl
libsrc=balloonhelp.tcl ctext.tcl htext.tcl pan.tcl sizer.tcl \
	print.tcl tableentry.tcl generic.tcl options.tcl pkgIndex.tcl \
	octave.tcl tclphoto.m tclsend.m
fithelp=reflfit.help help.help mlayer.help gj2.help
fitfig=reflpolorient.gif
fitsrc=mlayer.tcl defaults.tcl tkmlayerrc pkgIndex.tcl \
	gmlayer$(LDEXT) gj2$(LDEXT)
redhelp=reflred.help help.help
redfig=footprint.gif fpflat.gif fplinear.gif
redsrc=viewrun.tcl loadicp.tcl loaduxd.tcl loadreduced.tcl \
	reduce.tcl psd.tcl choose.tcl NG7monitor.cal tkviewrunrc pkgIndex.tcl
redoctavesrc=psdslice.m run_include.m run_scale.m run_trunc.m \
	interp1err.m run_avg.m run_interp.m run_sub.m runlog.m \
	plotrunop.m run_div.m run_poisson_avg.m run_tol.m

fithelpdeps=$(patsubst %,tcl/%,$(fithelp) $(fitfig))
redhelpdeps=$(patsubst %,reflred/%,$(redhelp) $(redfig))

scifunfiles=$(patsubst %,scifun/%,$(scifunsrc))
pakfiles=$(patsubst %,reflpak/%,$(paksrc) pak.ico)
libfiles=$(patsubst %,lib/%,$(libsrc))
fitfiles=$(patsubst %,tcl/%,$(fithelp) $(fitfig) $(fitsrc) fit.ico pol.ico)
redfiles=$(patsubst %,reflred/%,$(redhelp) $(redfig) $(redsrc) red.ico)
redoctavefiles=$(patsubst %,reflred/octave/%,$(redoctavesrc))

macscripts=$(patsubst %,macosx/%.app,reflpak reflred reflfit reflpol)

SUBDIRS=src gj2 scifun

ifeq ($(EXE),.exe)
SUBDIRS+=winlink
winlinksrc=pkgIndex.tcl winreg.tcl winlink$(LDEXT)
winfiles=$(patsubst %,winlink/%,$(winlinksrc))
addwinlink=./vfslib reflpak winlink $(winfiles)
else
addwinlink=:
endif

icons = reflred/red.ico tcl/fit.ico tcl/pol.ico reflpak/pak.ico

.PHONY: $(SUBDIRS) 

all: $(SUBDIRS) kit/reflpak$(EXE)

kit/reflpak.exe: kit/reflpak kit/reflpak.res win/bindres.sh
	cd kit && ../win/bindres.sh reflpak.exe reflpak.res

kit/reflpak.res: win/reflpak.rc $(icons)
	cd win && $(RC) reflpak.rc ../kit/reflpak.res

kit/reflpak: $(fitfiles) $(redfiles) $(redoctavefiles) $(winfiles) \
		$(scifunfiles) $(libfiles) $(pakfiles) \
		kit/ncnrkit$(EXE) main.tcl Makefile vfslib
	./vfslib reflpak
	./vfslib reflpak ncnrlib $(libfiles)
	./vfslib reflpak scifun $(scifunfiles)
	$(addwinlink)
	./vfslib reflpak reflfit $(fitfiles) $(gmlayer) $(gj2)
	./vfslib reflpak reflred $(redfiles)
	./vfslib reflpak reflred/octave $(redoctavefiles)
	./vfslib reflpak reflpak $(pakfiles)
	echo "set ::app_version {`date +%Y-%m-%d` for $(ARCH)}" \
		> kit/reflpak.vfs/main.tcl
	cat main.tcl >> kit/reflpak.vfs/main.tcl
	cd kit && cp ncnrkit$(EXE) copykit$(EXE) && \
		./copykit sdx.kit wrap reflpak$(EXE) -runtime ncnrkit$(EXE)
	touch kit/reflpak ;# needed to trigger resource binding on reflpak.exe

reflred/red.ico: $(redicon)
	cp $(redicon) $@

tcl/fit.ico: $(fiticon)
	cp $(fiticon) $@

tcl/pol.ico: $(policon)
	cp $(policon) $@

reflpak/pak.ico: $(pakicon)
	cp $(pakicon) $@

html: html/reflred/index.html html/reflfit/index.html

pdf: html

html/reflred/index.html: lib/help2html $(redhelpdeps)
	rm -rf html/reflred
	lib/help2html reflred windows $(redversion) $(redhelpdeps)

html/reflfit/index.html: lib/help2html $(fithelpdeps)
	rm -rf html/reflfit
	lib/help2html reflfit introduction $(fitversion) $(fithelpdeps)

Makeconf.tcltk:
	$(error Use ./tclConfig2Makeconf to build Makeconf.tcltk)

$(SUBDIRS):
	cd $@ && $(MAKE)

ChangeLog:
	cvs2cl.pl --fsf --file ChangeLog

srcdist: ChangeLog
	cvs rtag R$(VERSION) reflfit
	cvs export -r R$(VERSION) reflpak$(VERSION)-src
	cp ChangeLog reflpak$(VERSION)-src
	if test ! -d release ; then mkdir release ; fi
	tar cjf release/reflpak$(VERSION)-src.tar.bz2 reflpak$(VERSION)-src
	$(RM) -rf reflpak$(VERSION)-src

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
else
ifeq ($(ARCH),win)
dist: kit/reflpak$(EXE)
	if test ! -d release ; then mkdir release ; fi
	cp -a kit/reflpak$(EXE) release/reflpak$(VERSION)$(EXE)
else
dist: kit/reflpak$(EXE) RELEASE-NOTES
	if test -d reflpak$(VERSION) ; then rm -rf reflpak$(VERSION); fi
	mkdir reflpak$(VERSION)
	cp -p RELEASE-NOTES reflpak$(VERSION)
	cp -p kit/reflpak reflpak$(VERSION)/reflpak$(VERSION)
	sed -e "s,@VERSION@,$(VERSION),g;s,@PAR@,,g" < linux/reflpak.in > reflpak$(VERSION)/reflpak
	sed -e "s,@VERSION@,$(VERSION),g;s,@PAR@,red,g" < linux/reflpak.in > reflpak$(VERSION)/reflred
	sed -e "s,@VERSION@,$(VERSION),g;s,@PAR@,fit,g" < linux/reflpak.in > reflpak$(VERSION)/reflfit
	sed -e "s,@VERSION@,$(VERSION),g;s,@PAR@,pol,g" < linux/reflpak.in > reflpak$(VERSION)/reflpol
	chmod a+rx
endif
endif

clean:
	$(RM) */*.o *~ */*~ core

distclean: clean
	$(RM) $(redbin) $(fitbin) $(polbin) $(gmlayer) $(gj2)

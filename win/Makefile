# This makefile is for use with msys.  Because of that, we need to do
# strange hacks, such as changing /c to C: because the Tcl we are using
# is compiled for windows.

# Rather than building our own freewrap, we are using the precompiled
# version.  To do otherwise would require recompiling all of Tcl/Tk
# since the ActiveState distribution does not provide static libraries.

# Debugging statements?
# DEBUG=-DEBUG

# Fortran compiler
F77=g77
FFLAGS=-O3 -g
FLIBS=-lg2c -lm

# We use the following values from tclConfig.sh.  If you have the
# same build environment as was used to create your Tcl distribution
# then you can simply include the associated tclConfig.sh.  This may
# not be true on Windows where the ActiveState distribution for example
# is built with VC++, but you may be using MinGW.
#
# Directories:
#
# TCL_PREFIX		platform independent files
# TCL_EXEC_PREFIX	platform dependent files
#
# Compiler:
#
# TCL_CC                C compiler
# TCL_CFLAGS_WARNING    compiler flags for warning messages
# TCL_CFLAGS_OPTIMIZE   compiler flags for optimization
# TCL_SHLIB_CFLAGS      compiler flags for loadable extensions
# TCL_INCLUDE_SPEC      tcl include files: -I.../include
#
# Linker:
#
# TCL_SHLIB_LD          link command for loadable extensions
# TCL_STUB_LIB_SPEC     stub library link options: -L.../lib -ltclstub#.#
# TCL_LIBS              additional tcl link options
# TCL_SHLIB_SUFFIX      .dll, .so or .dylib
# TCL_SHLIB_LD_LIBS     either '' or '${LIBS}'
#
# Not usings the following:
#
# TCL_DEFS              These report the results of ./configure, so they
#                       may be worthwhile, depending on the needs of the
#                       application.  So far, I don't think we need them.
# TCL_EXTRA_CFLAGS      Additionally defines e.g. -DMAC_OSX_TCL, but we
#                       aren't that platform specific.  Ignore for now.
#
# TCL_CC_SEARCH_FLAGS   These are for -rpath, which we won't need with stubs?
# TCL_LD_SEARCH_FLAGS
# TCL_COMPAT_OBS        posix functions missing from the platform

include Makeconf.tcltk

## Unless I'm compiling Tcl/Tk myself, tclConfig.sh is useless.
#CC=$(TCL_CC)
#CFLAGS=$(TCL_CFLAGS_OPTIMIZE) $(TCL_SHLIB_CFLAGS) $(TCL_CFLAGS_WARNING) $(TCL_INCLUDE_SPEC)
#LIBS:=$(TCL_STUB_LIB_SPEC) $(TCL_SHLIB_LD_LIBS)
#LD=$(TCL_SHLIB_LD)
#LDFLAGS=
#LDEXT=$(TCL_SHLIB_SUFFIX)

TCL_PREFIX=/c/Tcl
TCL_PREFIX_WIN=/Tcl
CC=gcc
CFLAGS=-O3 -Wall -I$(TCL_PREFIX)/include
LIBS=-L$(TCL_PREFIX)/lib -ltclstub$(TCL_MAJOR_VERSION)$(TCL_MINOR_VERSION)
LD=gcc -shared
LDFLAGS=
LDEXT=.dll

CFLAGS += -I../src
LIBS += $(FLIBS)


# Where to find source
VPATH=../src

EXE=.exe

# A flag to tell the generic make that we are running the arch-specific make
REFLFIT_ARCH = ok


bindir = $(shell pwd | sed -e "s,^/c/,/,")
tcldir = $(shell cd .. && pwd | sed -e "s,^/c/,/,")/tcl

all: reflfit$(EXE)

reflfit$(EXE): freewrapBLT$(EXE) gmlayer$(LDEXT) mkmanifest reflfit.tcl
	./freewrapBLT -e reflfit.tcl -f manifest

reflfit.tcl: reflfit.tcl.in
	sed -e 's,@WISH@,$(TCL_PREFIX)/bin/bltwish,' \
		-e 's,@TCL_PREFIX@,$(TCL_PREFIX_WIN),' \
		-e 's,@MLAYER_HOME@,$(tcldir),' \
		-e 's,@MLAYER_EXT@,$(bindir)/gmlayer$(LDEXT),' < reflfit.tcl.in > reflfit.tcl
	chmod a+x reflfit.tcl

BWIDGET=$(TCL_PREFIX)/lib/bwidget1.6
TKDND=$(TCL_PREFIX)/lib/tkdnd1.0
TKTABLE=$(TCL_PREFIX)/lib/Tktable2.8
mkmanifest: 
	$(RM) manifest.in
	for f in $(BWIDGET)/*.tcl $(BWIDGET)/images/* $(BWIDGET)/lang/* ; do echo "$$f" >> manifest.in ; done
	echo "$(TCL_PREFIX)/lib/tkcon.tcl" >> manifest.in
	echo "$(TKTABLE)/pkgIndex.tcl" >> manifest.in
	echo "$(TKTABLE)/Tktable28.dll" >> manifest.in
	echo "$(TKTABLE)/tkTable.tcl" >> manifest.in
	echo "$(TKDND)/pkgIndex.tcl" >> manifest.in
	echo "$(TKDND)/tkdnd.tcl" >> manifest.in
	echo "$(TKDND)/libtkdnd10.dll" >> manifest.in
	echo "$(bindir)/gmlayer$(LDEXT)" >> manifest.in
	for f in /c$(tcldir)/* ; do echo "$$f" >> manifest.in ; done
	sed -e 's,^/c/,/,' <manifest.in > manifest
	$(RM) manifest.in

include ../src/Makefile

freewrapBLT$(EXE):
	$(MAKE) -f Makefile.freewrap

clean:
	# $(MAKE) -f Makefile.freewrap clean
	$(RM) *.o core manifest

distclean: 
	# $(MAKE) -f Makefile.freewrap distclean
	$(RM) *.o core manifest Makeconf.tcltk
	$(RM) reflfit.tcl reflfit$(EXE) gmlayer$(LDEXT)

# Debugging statements?
# DEBUG=-DEBUG

# Fortran compiler
F77=f77
FFLAGS=-O3 -g
FLIBS=-lftn -lm

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
CC=$(TCL_CC)
CFLAGS=$(TCL_CFLAGS_OPTIMIZE) $(TCL_SHLIB_CFLAGS) $(TCL_CFLAGS_WARNING) $(TCL_INCLUDE_SPEC) -I../src
LIBS:=$(TCL_STUB_LIB_SPEC) $(TCL_LIBS) $(FLIBS) $(TCL_SHLIB_LD_LIBS)
LD=$(TCL_SHLIB_LD)
LDFLAGS=
LDEXT=$(TCL_SHLIB_SUFFIX)

# Where to find source
VPATH=../src

# A flag to tell the generic make that we are running the arch-specific make
REFLFIT_ARCH = macosx

bindir = $(shell pwd)
tcldir = $(shell cd .. && pwd)/tcl

all: reflfit

reflfit: freewrapBLT gmlayer$(LDEXT) manifest reflfit.tcl
	./freewrapBLT -e reflfit.tcl -f manifest

reflfit.tcl: reflfit.tcl.in
	sed -e 's,@WISH@,$(TCL_EXEC_PREFIX)/bin/bltwish,' \
		-e 's,@TCL_PREFIX@,$(TCL_PREFIX),' \
		-e 's,@MLAYER_HOME@,$(tcldir),' \
		-e 's,@MLAYER_EXT@,$(bindir)/gmlayer$(LDEXT),' < reflfit.tcl.in > reflfit.tcl
	chmod a+x reflfit.tcl

BWIDGET=$(TCL_PREFIX)/lib/bwidget1.6
manifest: 
	$(RM) manifest
	for f in $(BWIDGET)/*.tcl $(BWIDGET)/images/* $(BWIDGET)/lang/* ; do echo "$$f" >> manifest ; done
	echo "$(TCL_PREFIX)/lib/tkcon.tcl" >> manifest
	echo "$(bindir)/gmlayer$(LDEXT)" >> manifest
	for f in $(tcldir)/* ; do echo "$$f" >> manifest ; done

include ../src/Makefile

freewrapBLT:
	$(MAKE) -f Makefile.freewrap

clean:
	$(MAKE) -f Makefile.freewrap clean
	$(RM) *.o core manifest

distclean: 
	$(MAKE) -f Makefile.freewrap distclean
	$(RM) *.o core manifest Makeconf.tcltk
	$(RM) reflfit.tcl reflfit gmlayer$(LDEXT)

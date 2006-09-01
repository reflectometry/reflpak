USE_STUBS = 1
USE_X11 = 1
USE_ISIS = 1
include ../Makeconf

ifdef USE_STUBS
  CFLAGS += -DUSE_TCL_STUBS -DUSE_TK_STUBS
endif

# font support is needed for demos (recommend ftgl instead)
#DEFS	+= -DTOGL_USE_FONTS

## For double precision OpenGL functions use the following.
# CFLAGS += -DUSE_DOUBLE

CFLAGS += -DUSE_TCL

## Turn on profiler
#CFLAGS += -pg
#LDFLAGS += -pg

OBJS=togl_plot.o togl.o refl.o mx.o plot.o tclvector.o 

ifdef USE_NEXUS 
  OBJS += NXtofnref.o nexus_helper.o NXtofnref_tcl.o
  CFLAGS += -DUSE_NEXUS
else
  NEXUSINC=
  NEXUSLIB=
endif

ifdef USE_ISIS
  OBJS += isis_tofnref.o isis_tofnref_tcl.o
  CFLAGS += -DUSE_ISIS
endif


%.o: %.c; $(CC) $(CFLAGS) $(GLDEF) $(NEXUSINC) $(GLINC) -c $< -o $@
%.o: %.cc; $(CXX) $(CFLAGS) $(GLDEF) $(NEXUSINC) $(GLINC) -c $< -o $@

all: plot$(LDEXT)

plot$(LDEXT): $(OBJS)
	$(LD_CXX) $(LDFLAGS) -o $@ $(OBJS) $(GLLIBS) $(NEXUSLIB) $(LIBS)

plot.o: plot.h
togl_plot.o: plot.h togl.h mx_tcl.c mx.h refl_tcl.c refl.h tclvector.h
togl.o: togl.h
mx.o: mx.c mx.h
refl.o: refl.c refl.h mx.h
tclvector.o: tclvector.h


# Support for reading NeXus binary files
NXtofnref.o: NXtofnref.cc nexus_helper.h NXtofnref_keys.icc rebin.h transpose.h
NXtofnref_tcl.o: NXtofnref_tcl.cc NXtofnref.h
nexus_helper.o: nexus_helper.c nexus_helper.h



clean:
	rm -f *.o plot$(LDEXT) *~ \
	plottest$(EXE) isistest$(EXE) nexustest$(EXE) slicetest$(EXE)

distclean: clean


check:	rebintest$(EXE)
	./rebintest

# =============================================
# Various experimental and test codes

# Slicing code --- not yet used in the interface
slicetest$(EXE): slice.c
	$(CC) -DTEST slice.c -oslicetest$(EXE)

rebintest$(EXE): rebin_test.cc rebin.h
	$(CXX) $(CFLAGS) $< -o $@ -lm

rebinspeed$(EXE): rebin_test.cc rebin.h
	$(CXX) $(CFLAGS) $< -o $@ -lm -DSPEED_CHECK

# Support for reading ISIS binary files

isis_tofnref.o: isis_tofnref.cc isis_tofnref.h
isis_tofnref_tcl.o: isis_tofnref_tcl.cc isis_tofnref.h
isistest$(EXE): isis_tofnref.cc isis_tofnref.h
	$(CXX) $(CFLAGS) -DSTANDALONE $< -o $@ -lm

# ISIS to NeXus converter
isis2nexus.o: isis2nexus.cc nexus_helper.h isis_tofnref.h
isis2nexus$(EXE): isis2nexus.o isis_tofnref.o nexus_helper.o
	$(CXX) $(LDFLAGS) -o $@ isis2nexus.o isis_tofnref.o nexus_helper.o \
	    $(NEXUSLIB) -lm

# Test NeXus reader
nexustest.o: NXtofnref.cc NXtofnref.h nexus_helper.h NXtofnref_keys.icc
	$(CXX) $(CFLAGS) $(NEXUSINC) -DSTANDALONE -c $< -o $@
nexustest$(EXE): nexustest.o nexus_helper.o
	$(CXX) $(LDFLAGS) -o $@ nexustest.o nexus_helper.o $(NEXUSLIB) -lm

plottest$(EXE): plot.c
	$(CC) $(GLDEF) $(GLINC) $(GLUTINC) -DTEST plot.c -o plot$(EXE) \
	      $(GLUTLIBS) $(GLLIBS) -lm


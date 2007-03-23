USE_STUBS = 1
#USE_AGL = 1
USE_ISIS = 1
include ../Makeconf

TCLDEF = -DUSE_TCL
ifdef USE_STUBS
  TCLDEF += -DUSE_TCL_STUBS -DUSE_TK_STUBS
endif

# font support is needed for demos (recommend ftgl instead)
#DEFS	+= -DTOGL_USE_FONTS

## For double precision OpenGL functions use the following.
# CFLAGS += -DUSE_DOUBLE

## Turn on profiler
#CFLAGS += -pg
#LDFLAGS += -pg

OBJS=togl_plot.o togl.o refl.o mx.o plot.o tclvector.o mx_tcl.o refl_tcl.o \
	icp_tcl.o icpread.o

ifdef USE_NEXUS 
  OBJS += NXtofnref.o nexus_helper.o NXtofnref_tcl.o
  NEXUSINC += -DUSE_NEXUS
else
  NEXUSINC=
  NEXUSLIB=
endif

ifdef USE_ISIS
  OBJS += isis_tofnref.o isis_tofnref_tcl.o
  CFLAGS += -DUSE_ISIS
endif


%.o: %.c; $(CC) $(CFLAGS) $(TCLDEF) $(GLDEF) $(NEXUSINC) $(GLINC) -c $< -o $@
%.o: %.cc; $(CXX) $(CFLAGS) $(TCLDEF) $(GLDEF) $(NEXUSINC) $(GLINC) -c $< -o $@

all: plot$(LDEXT)

plot$(LDEXT): $(OBJS)
	$(LD_CXX) $(LDFLAGS) -o $@ $(OBJS) $(GLLIBS) $(NEXUSLIB) $(LIBS) $(ZLIB)

plot.o: plot.h
togl_plot.o: plot.h togl.h tclvector.h
refl_tcl.o: refl_tcl.c refl.h
icp_tcl.o: icp_tcl.c icpread.h mx.h tclvector.h
mx_tcl.o: mx_tcl.cc rebin.h rebin2D.h mx.h
togl.o: togl.h
mx.o: mx.c mx.h
refl.o: refl.c refl.h mx.h
tclvector.o: tclvector.h

icpread.o: icpread.c icpread.h
	$(CC) -c $(CFLAGS) $(ZINC) icpread.c -o $@


# Support for reading NeXus binary files
NXtofnref.o: NXtofnref.cc nexus_helper.h NXtofnref_keys.icc rebin.h \
	transpose.h progress.h
NXtofnref_tcl.o: NXtofnref_tcl.cc NXtofnref.h progress.h tclvector.h
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
slicetest$(EXE): slicetest.o mx.o
	$(CC) slicetest.o mx.o -oslicetest$(EXE)
slicetest.o: slicetest.c mx.h

# Rebinning code tests
rebintest$(EXE): rebin_test.cc rebin.h
	$(CXX) $(CFLAGS) $< -o $@ -lm

rebin2Dtest$(EXE): rebin2D_test.cc rebin2D.h
	$(CXX) $(CFLAGS) $< -o $@ -lm

rebinspeed$(EXE): rebin_test.cc rebin.h
	$(CXX) $(CFLAGS) $< -o $@ -lm -DSPEED_CHECK

rebin2Dspeed$(EXE): rebin2D_test.cc rebin2D.h
	$(CXX) $(CFLAGS) $< -o $@ -lm -DSPEED_CHECK

# icpreader example
icpread$(EXE): icpread.c icpread.h
	$(CC) -DTEST $(CFLAGS) $(ZINC) icpread.c -o $@ $(ZLIB)

# Support for reading ISIS binary files

isis_tofnref.o: isis_tofnref.cc isis_tofnref.h
isis_tofnref_tcl.o: isis_tofnref_tcl.cc isis_tofnref.h tclvector.h
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

progressdemo$(EXE): progressdemo.cc progress.h
	$(CXX) $(CFLAGS) -c $< -o $@

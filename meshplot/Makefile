include ../Makeconf

USE_STUBS = 1
USE_X11 = 1

GLDEF    = -DTOGL_X11
GLINC    = -I/usr/X11R6/include
GLLIBS   = -L/usr/X11R6/lib -lGL -lXmu -lXt -lX11
GLUTINC  = 
GLUTLIBS = -lglut
NEXUSINC = -I$(NEXUS)/include
NEXUSLIBS = -L$(NEXUS)/src/.libs -lNeXus -lmxml -lhdf5 -lmfhdf -ldf -ljpeg -lz -ldl


OS = $(shell uname -s)
ifeq ($(OS),CYGWIN_NT-5.0)
  OS=WINDOWS
  GLINC = -I/usr/include/w32api
endif
ifeq ($(OS),MINGW32_NT-5.0)
  OS=WINDOWS
  GLINC =
endif
ifeq ($(OS),MINGW32_NT-5.1)
  OS=WINDOWS
  GLINC =
endif

ifeq ($(OS),IRIX64)
  GLUTINC = -I/usr/freeware/include
  GLUTLIBS = -L/usr/freeware/lib32 -lglut
endif
ifeq ($(OS),WINDOWS)
  # You will need to find glut.h and glut32.dll to run the
  # simple plot test which does not use Togl or Tcl/Tk.  I
  # put glut32.dll in the current directory and glut.h in
  # the /mingw/include/GL directory.
  GLDEF = -DTOGL_WGL
  GLINC = 
  GLLIBS = -lglu32 -lopengl32 -lgdi32
  GLUTINC = 
  GLUTLIBS = -lglut32
endif
ifeq ($(OS),Darwin)
  ifndef USE_X11
    GLDEF = -DTOGL_AGL -DOSX
    GLINC =
    GLLIBS = -framework AGL -framework OpenGL -framework ApplicationServices
    GLUTINC =
    GLUTLIBS = -framework GLUT -framework Foundation

    # Build for AGL rather than private X11 version of Tk
    TCL_F = /Library/Frameworks/Tcl.framework
    TK_F = /Library/Frameworks/Tk.framework
    CC=gcc
    CFLAGS = -g -O2 \
	-I$(TCL_F)/Versions/8.4/Headers \
	-I$(TK_F)/Versions/8.4/Headers \
	-I$(TK_F)/Versions/8.4/PrivateHeaders \
	-I./macosx
    ifndef USE_STUBS
      LIBS = -F/Library/Frameworks -framework Tk -framework Tcl -lm
    else
      LIBS = -L$(TCL_F) -ltclstub8.4 -L$(TK_F) -ltkstub8.4 -lm
    endif
  else
    # Needed the following link in the current directory to find GL/glut.h
    #   ln -s /System/Library/Frameworks/GLUT.framework/Versions/Current/Headers/ GL
    GLUTINC = -I.
  endif # !USE_X11
endif # Darwin

ifdef USE_STUBS
  CFLAGS += -DUSE_TCL_STUBS -DUSE_TK_STUBS
endif

# font support is needed for demos (recommend ftgl instead)
#DEFS	+= -DTOGL_USE_FONTS

## For double precision OpenGL functions use the following.
# CFLAGS += -DUSE_DOUBLE

CFLAGS += -DUSE_TCL

#CFLAGS += -g
#LDFLAGS += -g

OBJS=togl_plot.o togl.o refl.o mx.o plot.o tclvector.o \
	NXtofnref.o nexus_helper.o NXtofnref_tcl.o

%.o: %.c; $(CC) $(CFLAGS) $(GLDEF) $(NEXUSINC) $(GLINC) -c $< -o $@
%.o: %.cc; $(CXX) $(CFLAGS) $(GLDEF) $(NEXUSINC) $(GLINC) -c $< -o $@

all: plot$(LDEXT) isis2nexus$(EXE)

plot$(LDEXT): $(OBJS)
	$(LD_CXX) $(LDFLAGS) -o $@ $(OBJS) $(GLLIBS) $(NEXUSLIBS) $(LIBS)

plot.o: plot.h
togl_plot.o: plot.h togl.h mx_tcl.c mx.h refl_tcl.c refl.h tclvector.h
togl.o: togl.h
mx.o: mx.c mx.h
refl.o: refl.c refl.h mx.h
tclvector.o: tclvector.h


# Support for reading NeXus binary files
NXtofnref.o: NXtofnref.cc nexus_helper.h
NXtofnref_tcl.o: NXtofnref_tcl.cc NXtofnref.h
nexus_helper.o: nexus_helper.c nexus_helper.h



clean:
	rm -f *.o plot$(LDEXT) *~ \
	plottest$(EXE) isistest$(EXE) nexustest$(EXE) slicetest$(EXE)

distclean: clean



# =============================================
# Various experimental and test codes

# Slicing code --- not yet used in the interface
slicetest$(EXE): slice.c
	$(CC) -DTEST slice.c -oslicetest$(EXE)


# Support for reading ISIS binary files

isis_tofnref.o: isis_tofnref.cc isis_tofnref.h
isis_tofnref_tcl.o: isis_tofnref_tcl.cc isis_tofnref.h
isistest$(EXE): isis_tofnref.cc isis_tofnref.h
	$(CXX) $(CFLAGS) -DSTANDALONE $< -o $@ -lm

# ISIS to NeXus converter
isis2nexus.o: isis2nexus.cc nexus_helper.h isis_tofnref.h
isis2nexus$(EXE): isis2nexus.o isis_tofnref.o nexus_helper.o
	$(CXX) $(LDFLAGS) -o $@ isis2nexus.o isis_tofnref.o nexus_helper.o \
	    $(NEXUSLIBS) -lm

# Test NeXus reader
nexustest.o: NXtofnref.cc NXtofnref.h nexus_helper.h
	$(CXX) $(CFLAGS) $(NEXUSINC) -DSTANDALONE -c $< -o $@
nexustest$(EXE): nexustest.o nexus_helper.o
	$(CXX) $(LDFLAGS) -o $@ nexustest.o nexus_helper.o $(NEXUSLIBS) -lm

plottest$(EXE): plot.c
	$(CC) $(GLDEF) $(GLINC) $(GLUTINC) -DTEST plot.c -o plot$(EXE) \
	      $(GLUTLIBS) $(GLLIBS) -lm


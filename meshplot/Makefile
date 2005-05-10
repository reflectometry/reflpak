include ../Makeconf

USE_STUBS = 1

GLDEF    = -DTOGL_X11
GLINC    = -I/usr/X11R6/include
GLLIBS   = -L/usr/X11R6/lib -lGLU -lGL -lXmu -lXt -lX11
GLUTINC  = 
GLUTLIBS = -lglut

OS = $(shell uname -s)
ifeq ($(OS),CYGWIN_NT-5.0)
  OS=WINDOWS
  GLINC = -I/usr/include/w32api
endif
ifeq ($(OS),MINGW32_NT-5.0)
  OS=WINDOWS
  GLINC =
endif

ifeq ($(OS),IRIX64)
  GLUTINC = -I/usr/freeware/include
  GLUTLIBS = -L/usr/freeware/lib32 -lglut
endif
ifeq ($(OS),WINDOWS)
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
      LIBS = -F/Library/Frameworks -framework Tk -framework Tcl
    else
      LIBS = -L$(TCL_F) -ltclstub8.4 -L$(TK_F) -ltkstub8.4
    endif
  endif # !USE_X11
endif # Darwin

ifdef USE_STUBS
  CFLAGS += -DUSE_TCL_STUBS -DUSE_TK_STUBS
endif

# font support is needed for demos (recommend ftgl instead)
#DEFS	+= -DTOGL_USE_FONTS

%.o: %.c; $(CC) $(CFLAGS) $(GLDEF) $(GLINC) -c $< -o $@

all: plot$(LDEXT)

plot$(EXE): plot.c
	$(CC) $(GLDEF) $(GLINC) $(GLUTINC) -DTEST plot.c -o plot$(EXE) \
	      $(GLUTLIBS) $(GLLIBS) -lm

plot$(LDEXT): togl_plot.o plot.o togl.o
	$(LD) $(LDFLAGS) -o $@ togl_plot.o plot.o togl.o $(GLLIBS) $(LIBS)

plot.o: plot.h
togl_plot.o: plot.h togl.h refl.c
togl.o: togl.h

clean:
	rm -f $(TOGL) *.o plot$(LDEXT) plot$(EXE) *~

distclean: clean

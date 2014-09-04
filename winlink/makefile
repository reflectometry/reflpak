# Makefile.vc
#
# This makefile builds tlink80.dll, an a dynamically loadable Tcl extension
# that implements the winlink::shortcut command.  This makefile is suitable for use with
# MinGW+MSys or Cygwin
#
# Copyright (c) 1997-1999 Sensus Consulting Ltd.
# $Header$
# 2004-02-20 Paul Kienzle
# * convert to gnu tools
#
PROJECT = winlink
VERSION = 12
#
# Project directories -- these may need to be customized for your site
#
# ROOT --               location of the example files.
# TCL --                location where Tcl is installed.
#
ROOT    	= .
# Tcl version to compile against.
TCL_VERSION	= 86
TCL     	= c:/Tcl
TCLSH		= $(TCL)/bin/tclsh$(TCL_VERSION)
BINDIR		= $(PROJECT)$(VERSION)
SRCDIR		= $(PROJECT)$(VERSION)-src
INSTALL_PATH    = $(TCL)/lib/$(BINDIR)

# comment the following line to compile with symbols
NODEBUG=1

##################
# Project settings
##################

OBJS = $(PROJECT).o

CC              = gcc
LD              = gcc

CP              = cp
RM              = rm -f
MKDIR           = mkdir
STRIP		= :

CFLAGS          = -I$(TCL)/include -O3 -Wall -DUSE_TCL_STUBS -c
LDFLAGS		= -shared
LIBS            = -L$(TCL)/lib -ltclstub$(TCL_VERSION) -lole32 -luuid

######################################################################
# Project specific targets
######################################################################
SRCFILES=README makefile makefile.vcc pkgIndex.tcl $(PROJECT).c $(PROJECT).htm $(PROJECT)test.tcl index.htm
BINFILES=$(PROJECT).dll $(PROJECT).htm pkgIndex.tcl $(PROJECT)test.tcl

all:  $(PROJECT).dll

test: $(PROJECT).dll
	@$(TCLSH) $(PROJECT)test.tcl

install: $(BINFILES)
	if test ! -d $(INSTALL_PATH) ; then $(MKDIR) $(INSTALL_PATH); fi
	$(CP) $(BINFILES) $(INSTALL_PATH)

dist: $(BINDIR).zip $(SRCDIR).zip

$(SRCDIR).zip: $(SRCFILES)
	rm -rf $(SRCDIR)
	mkdir $(SRCDIR)
	cp $(SRCFILES) $(SRCDIR)
	zip -9r $(SRCDIR).zip $(SRCDIR)
	rm -rf $(SRCDIR)

$(BINDIR).zip: $(BINFILES)
	rm -rf $(BINDIR)
	mkdir $(BINDIR)
	cp $(BINFILES) $(BINDIR)
	zip -9r $(BINDIR).zip $(BINDIR)
	rm -rf $(BINDIR)

$(PROJECT).dll: $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS) $(LIBS)
	$(STRIP) $@

clean:
	$(RM) $(OBJS) foo.lnk *~

distclean:
	$(RM) $(PROJECT).dll $(BINDIR).zip $(SRCDIR).zip

#######################################################################
# Implicit Targets
#######################################################################


# Implicit Targets

.c.o:
	$(CC) $(CFLAGS) $<


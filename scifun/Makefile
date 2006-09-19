VERSION=0.1
DEFS=-DUSE_TCL_STUBS=1
INSTALLDIR=scifun$(VERSION)

sinclude ../Makeconf
ifndef LDEXT
  $(error Link ../<ARCH>/Makeconf to ../Makeconf and try again.)
endif

ifeq ($(ARCH),win)
  # May need to compile routines in mingw subdirectory because the
  # current mingw libm is missing some of the posix standard functions.
  FDLIBM=$(patsubst %,mingw/%.o,e_acosh e_atanh e_log s_asinh s_expm1)
  CFLAGS:=$(CFLAGS) -Imingw
endif

C99 ?= $(CC)

all: scifun$(LDEXT) pkgIndex.tcl 

dist: all 
	-$(RM) -rf $(INSTALLDIR) 
	$(MKDIR) $(INSTALLDIR) 
	$(CP) pkgIndex.tcl README.txt scifun$(LDEXT) $(INSTALLDIR) 
	tar czf $(INSTALLDIR).tar.gz
	$(INSTALLDIR) $(RM) -rf $(INSTALLDIR)

pkgIndex.tcl: pkgIndex.tcl.in Makefile
	sed -e 's,@VERSION@,$(VERSION),;s,@LDEXT@,$(LDEXT),' \
		< pkgIndex.tcl.in > pkgIndex.tcl

scifun$(LDEXT): scifun.o $(FDLIBM)
	$(LD) $(LDFLAGS) -o $@ $< $(LIBS) $(FDLIBM)

%.o: %.c ; $(C99) $(CFLAGS) $(DEFS) -c $< -o $@ -DVERSION=$(VERSION)

clean:
	$(RM) *.o mingw/*.o

distclean:
	$(RM) *.o mingw/*.o *~ scifun$(LDEXT)

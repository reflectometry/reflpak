VERSION=0.1
DEFS=-DUSE_TCL_STUBS=1

sinclude ../Makeconf
ifndef LDEXT
  $(error Link ../<ARCH>/Makeconf to ../Makeconf and try again.)
endif

C99 ?= $(CC)

DEST=scifun$(VERSION)

all: $(DEST) $(DEST)/scifun$(LDEXT) $(DEST)/pkgIndex.tcl $(DEST)/README.txt

$(DEST):
	mkdir $(DEST)

$(DEST)/pkgIndex.tcl: pkgIndex.tcl.in Makefile
	sed -e 's,@VERSION@,$(VERSION),' < pkgIndex.tcl.in > $(DEST)/pkgIndex.tcl

$(DEST)/README.txt: README.txt
	cat < README.txt > $(DEST)/README.txt

$(DEST)/scifun$(LDEXT): scifun.o
	$(LD) $(LDFLAGS) -o $@ $< $(LIBS)

scifun.o: scifun.c
	$(C99) $(CFLAGS) $(DEFS) -c $< -o $@ -DVERSION=$(VERSION)

clean:
	$(RM) scifun.o

# You need to set up the following variables before continuing.  This
# is done by the various arch specific makefiles in ../<arch>/Makefile.
# I'm going to assume this is a tcl build, and drop support for non-Tcl
# targets.  For now it will be easy to add, but this will be less so
# as I strip the fluff from mlayer and reimplement it in Tcl scripts.
#
# CC			C compiler
# CFLAGS		C compile flags
# F77      		fortran compiler
# FFLAGS   		fortran compile flags
# FLIBS    		fortran link flags
# LD			linker
# LDFLAGS		linker flags
# LDEXT			shared library extension
# LIBS			usual link libraries
#
# DEBUG=-DEBUG		Build a debug version

sinclude ../Makeconf
ifndef LDEXT
  $(error Link ../xxx/Makeconf to ../Makeconf and try again.)
endif

DEFS=-DUSE_TCL_STUBS=1 -DMALLOC=gmlayer_alloc -DFREE=gmlayer_free $(DEBUG)

DATA=cdata.c genpsc.c genpsd.c genpsi.c genpsl.c genpsr.c clista.c glayd.c glayi.c genmem.c
HELPERS=badInput.c caps.c lenc.c lenpre.c noFile.c loadData.c allocData.c cleanFree.c gnuPlot.c loadParms.c stopFit.c stopMovie.c cleanUp.c setLayerParam.c unix.c ipc.c linebuf.c
MAIN=dofit.c getparams.c parms.c parseva.c plotit.c printinfo.c help.c
MODEL=calcStep.c delparm.c derf.c extres.c fgen.c fsgen.c gAverage.c genderiv.c generf.c genmlayers.c genmulti.c gensderiv.c genshift.c gensub.c gentanh.c genva.c genvac.c mlayer.c mancon.c dlconstrain.c mrqmin.c
CCOMPL=complex.c grefint.c grefamp.c makeQn.c

NONTCL=gmlayer.c queryString.c

CSRC=$(DATA) $(HELPERS) $(MAIN) $(MODEL)
FSRC=grefamp.f grefint.f newgrefint.f

LINTS=$(CSRC:.c=.ln)
FUZZIES=$(CSRC:.c=.fuzz)
PREPROCS=$(CSRC:.c=.i)

OOBJS=$(CSRC:.c=.o) $(FSRC:.f=.o)

.SUFFIXES:
.SUFFIXES: .fuzz .ln .c .f .o

.f.o:
	$(F77) $(FFLAGS) -I../src -c $< -o $@

.c.o:

	$(CC) $(CFLAGS) $(DEFS) -I../src -c $< -o $@

.c.i:
	$(CC) -P $(INCLUDES) -I../src $<

.c.fuzz .c.ln:
	$(LINT) -c $(INCLUDES) -I../src $< $(LIBS) > $*.fuzz


all: ../tcl/gmlayer$(LDEXT)

../tcl/gmlayer$(LDEXT): mlayertcl.o $(OOBJS)
	$(LD) $(LDFLAGS) -o $@ mlayertcl.o $(OOBJS) $(FLIBS) $(LIBS)

lint: $(FUZZIES)
	$(LINT) $(INCLUDES) $(LINTS) $(LIBS) > $@

skipdistclean: clean
	rm -rf mlayer  *~

skipclean: cleanlint
	rm -rf $(OOBJS) mlayertcl.o
	rm -rf $(PREPROCS)
	rm -rf core 

cleanlint:
	rm -rf $(LINTS)
	rm -rf $(FUZZIES)
	rm -rf lint

vars:
	@echo $(CSRC) $(FSRC)
	@echo $(PREPROCS)
	@echo $(LINTS) $(FUZZIES)

# DO NOT DELETE

allocData.o allocData.u: allocData.h cleanFree.h genmem.h common.h
badInput.o badInput.u: badInput.h
calcStep.o calcStep.u: calcStep.h
caps.o caps.u: caps.h
cdata.o cdata.u: cdata.h common.h parameters.h
cleanFree.o cleanFree.u: cleanFree.h
cleanUp.o cleanUp.u: cleanUp.h cleanFree.h dlconstrain.h common.h genmem.h
cleanUp.o cleanUp.u: genpsr.h parameters.h genpsi.h genpsc.h cparms.h cdata.h
clista.o clista.u: clista.h common.h parameters.h
delparm.o delparm.u: delparm.h constrain.h parameters.h genpsd.h common.h
derf.o derf.u: derf.h
dlconstrain.o dlconstrain.u: dlconstrain.h common.h constraincpp.h parameters.h
dlconstrain.o dlconstrin.u: static.h
dofit.o dofit.u: dofit.h genderiv.h gensderiv.h genshift.h parseva.h mrqmin.h
dofit.o dofit.u: parameters.h dynamic.h constrain.h loadData.h extres.h
dofit.o dofit.u: cleanFree.h cparms.h clista.h common.h genpsd.h genpsc.h
dofit.o dofit.u: genpsl.h genmem.h cdata.h fgen.h fsgen.h plotit.h
dofit.o dofit.u: queryString.h
extres.o extres.u: extres.h allocData.h genmem.h common.h static.h
fgen.o fgen.u: fgen.h constrain.h genshift.h genderiv.h parameters.h cparms.h
fgen.o fgen.u: clista.h common.h
fsgen.o fsgen.u: fsgen.h constrain.h genshift.h gensderiv.h parameters.h
fsgen.o fsgen.u: cparms.h clista.h common.h
gAverage.o gAverage.u: gAverage.h
genderiv.o genderiv.u: genderiv.h extres.h genmulti.h grefint.h delparm.h
genderiv.o genderiv.u: mancon.h parameters.h cparms.h genpsd.h common.h genpsi.h
genderiv.o genderiv.u: genpsl.h genpsc.h genmem.h glayd.h glayi.h
generf.o generf.u: generf.h derf.h calcStep.h static.h parameters.h
genmem.o genmem.u: genmem.h common.h
genmlayers.o genmlayers.u: genmlayers.h derf.h gAverage.h parameters.h glayd.h
genmlayers.o genmlayers.u: common.h glayi.h static.h
genmulti.o genmulti.u: genmulti.h genvac.h genmlayers.h gensub.h parameters.h
genmulti.o genmulti.u: genpsr.h common.h glayd.h glayi.h
genpsc.o genpsc.u: genpsc.h common.h cparms.h
genpsd.o genpsd.u: genpsd.h common.h parameters.h
genpsi.o genpsi.u: genpsi.h common.h
genpsl.o genpsl.u: genpsl.h common.h
genpsr.o genpsr.u: genpsr.h common.h parameters.h
gensderiv.o gensderiv.u: gensderiv.h extres.h genmulti.h grefint.h delparm.h
gensderiv.o gensderiv.u: mancon.h parameters.h cparms.h genpsd.h common.h
gensderiv.o gensderiv.u: genpsi.h genpsl.h genpsc.h genmem.h glayd.h glayi.h
genshift.o genshift.u: genshift.h parameters.h genpsd.h common.h genpsi.h
gensub.o gensub.u: gensub.h gAverage.h parameters.h glayd.h common.h glayi.h
gentanh.o gentanh.u:  gentanh.h calcStep.h parameters.h static.h
genva.o genva.u: genva.h parameters.h
genvac.o genvac.u: genvac.h gAverage.h parameters.h glayd.h common.h glayi.h
getparams.o getparams.u: getparams.h lenc.h caps.h gentanh.h generf.h
getparams.o getparams.u: badInput.h cparms.h genpsi.h common.h genpsr.h
getparams.o getparams.u: parameters.h static.h genpsd.h common.h setLayerParam.h
glayd.o glayd.u: glayd.h common.h parameters.h
glayi.o glayi.u: glayi.h common.h
gmlayer.o gmlayer.u: mlayer.h
gnuPlot.o gnuPlot.u: gnuPlot.h cparms.h
help.o hepl.u: help.h static.h queryString.h caps.h parameters.h cparms.h
lenc.o lenc.u: lenc.h
lenpre.o lenpre.u: lenpre.h
loadData.o loadData.u: loadData.h noFile.h cleanFree.h cparms.h cdata.h common.h
loadData.o loadData.u: parameters.h genpsc.h static.h
loadParms.o loadParms.u: loadParms.h parms.h dlconstrain.h common.h cparms.h
loadParms.o loadParms.u: clista.h parameters.h genpsd.h genpsi.h genpsc.h
loadParms.o loadParms.u: genpsl.h cdata.h
mancon.o mancon.u: mancon.h parameters.h cparms.h static.h
mlayer.o mlayer.u: mlayer.h parms.h gentanh.h generf.h caps.h genshift.h
mlayer.o mlayer.u: dlconstrain.h common.h badInput.h getparams.h printinfo.h
mlayer.o mlayer.u: loadData.h dofit.h plotit.h extres.h cparms.h cdata.h
mlayer.o mlayer.u: parameters.h genpsd.h genpsr.h genpsi.h genpsc.h genmem.h
mlayer.o mlayer.u: clista.h static.h queryString.h help.h unix.h
mrqmin.o mrqmin.u: mrqmin.h parameters.h dynamic.h genmem.h common.h static.h
noFile.o noFile.u: noFile.h
parms.o parms.u: parms.h lenc.h cparms.h static.h
parseva.o parseva.u: parseva.h parameters.h static.h
plotit.o plotit.u: plotit.h gnuPlot.h loadData.h extres.h parseva.h caps.h
plotit.o plotit.u: badInput.h setLayerParam.h queryString.h genderiv.h genvac.h
plotit.o plotit.u: genmulti.h stopMovie.h noFile.h genva.h dlconstrain.h
plotit.o plotit.u: parameters.h cparms.h cdata.h glayd.h glayi.h genmem.h
plotit.o plotit.u: genpsl.h genpsc.h genpsr.h genpsi.h genpsd.h
printinfo.o printinfo.u: printinfo.h badInput.h genvac.h genmulti.h grefamp.h
printinfo.o printinfo.u: grefint.h lenpre.h lenc.h extres.h genderiv.h
printinfo.o printinfo.u: gensderiv.h noFile.h parameters.h cparms.h cdata.h
printinfo.o printinfo.u: common.h genva.h genpsc.h genpsd.h genpsr.h genpsi.h
printinfo.o printinfo.u: genpsl.h clista.h glayd.h glayi.h static.h
queryString.o queryString.u: cparms.h queryString.h
setLayerParam.o setLayerParam.u: setLayerParam.h queryString.h badInput.h
setLayerParam.o setLayerParam.u: genpsd.h parameters.h common.h cparms.h caps.h
stopFit.o stopFit.u: stopFit.h common.h
stopMovie.o stopMovie.u: stopMovie.h common.h
unix.o unix.u: unix.h queryString.h genpsc.h common.h static.h


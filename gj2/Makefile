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
# FPP			flag to force a source file through preprocessor
# LD			linker
# LDFLAGS		linker flags
# LDEXT			shared library extension
# LIBS			usual link libraries
#
# DEBUG=-DEBUG		Build a debug version
#
# FPERROR		Object file which defines fperror and clear_fp_error


sinclude ../Makeconf
ifndef LDEXT
  $(error Link ../xxx/Makeconf to ../Makeconf and try again.)
endif

DEFS=-DUSE_TCL_STUBS=1 -Dmalloc=gmlayer_alloc -Dfree=gmlayer_free $(DEBUG)

#Next line is for a version which supports negative Q
MINUSQ=-DMINUSQ

DATA=cdata.c genpsc.c genpsd.c genpsi.c genpsl.c genpsr.c clista.c glayd.c glayi.c glayim.c glayin.c mglayd.c nglayd.c genmem.c
HELPERMACS=lenc.c lenlist.c lenpre.c
HELPERS=badInput.c caps.c sortq.c noFile.c loadData.c cleanFree.c copyBasename.c allocData.c stopFit.c stopMovie.c gnuPlot.c loadParms.c cleanUp.c setLayerParam.c unix.c linebuf.c
MAIN=dofit.c getparams.c gmagpro4.c magblocks4.c parms.c parseva.c plotit.c printinfo.c help.c ipc.c
MODEL=delparm.c derf.c extres.c fgenm4.c genderiv4.c generf.c genlayers.c mgenlayers.c ngenlayers.c genshift.c gentanh.c genva.c mancon4.c mrqmin.c calcStep.c calcReflec.c dlconstrain.c

NONTCL=gj2.c queryString.c

CSRC=$(DATA) $(HELPERS) $(MAIN) $(MODEL)
FSRC=r4x.f r4xa.f z_div.f

# Sources dependent on sign of q
OMQ=r4x.o r4xa.o sortq.o glayd.o calcReflec.o mancon4.o extres.o

LINTS=$(CSRC:.c=.ln)
FUZZIES=$(CSRC:.c=.fuzz)
PREPROCS=$(CSRC:.c=.i)

OOBJS=$(FSRC:.f=.o) $(FPERROR) $(CSRC:.c=.o)

.SUFFIXES:
.SUFFIXES: .f .c .o .i
.SUFFIXES: .fuzz .ln

.f.o:
	$(F77) $(MINUSQ) $(FFLAGS) -c -I../gj2 $(FPP) $< -o $@

.c.o:
	$(CC) $(MINUSQ) $(CFLAGS) $(DEFS) -c $(INCLUDES) -I../gj2 $< -o $@

.c.i:
	$(CC) $(MINUSQ) $(CFLAGS) -P $(INCLUDES) -I../gj2 $<

.c.fuzz .c.ln:
	$(LINT) -c $(INCLUDES) -I../gj2 $< $(LIBS) > $*.fuzz


all: gj2$(LDEXT)

gj2$(LDEXT): $(OOBJS) gj2tcl.o
	$(LD) $(LDFLAGS) -o $@ gj2tcl.o $(OOBJS) $(FLIBS) $(LIBS)

# if MINUSQ=-DMINUSQ changes in makefile, force rebuild of 
# all object files which care about -Q.
$(UMQ): Makefile

$(OMQ): Makefile

# r4xa is almost identical to r4x, except that it returns complex values
# rather than real values.  This minor difference is easily accomodated
# with a -DAMPLITUDE and a few #ifdef's inside.
r4xa.o: r4x.f
	$(F77) -DAMPLITUDE $(MINUSQ) $(FFLAGS) -c $(FPP) $< -o $@

lint: $(FUZZIES)
	$(LINT) $(INCLUDES) $(LINTS) $(TFLAGS) $(LIBS) > $@

distclean:
	rm -rf $(OOBJS) gj2tcl.o

clean: cleanlint
	rm -rf *.o $(PREPROCS) core

cleanlint:
	rm -rf $(LINTS) $(FUZZIES) lint
vars:
	@echo $(CSRC) $(FPPSRC) $(FSRC)
	@echo $(PREPROCS)
	@echo $(LINTS) $(FUZZIES)

# DO NOT DELETE

allocData.o allocData.u: allocData.h cleanFree.h genpsi.h common.h parameters.h
allocData.o allocData.u: genpsl.h genmem.h
badInput.o badInput.u: badInput.h
calcReflec.o calcReflec.u: calcReflec.h ngenlayers.h mgenlayers.h gmagpro4.h
calcReflec.o calcReflec.u: r4x.h r4xa.h glayi.h common.h parameters.h glayd.h
calcReflec.o calcReflec.u: genpsl.h genpsc.h cparms.h genpsr.h genpsi.h genpsd.h
calcStep.o calcStep.u: calcStep.h
caps.o caps.u: caps.h
cdata.o cdata.u: cdata.h common.h parameters.h cparms.h
cleanFree.o cleanFree.u: cleanFree.h
cleanUp.o cleanUp.u: cleanUp.h cleanFree.h dlconstrain.h common.h genmem.h
cleanUp.o cleanUp.u: parameters.h genpsr.h genpsi.h genpsc.h cparms.h cdata.h
clista.o clista.u: clista.h common.h parameters.h
constrain.o constrain.u: constrain.h common.h parameters.h
copyBasename.o copyBasename.u: copyBasename.h lenpre.h
delparm.o delparm.u: delparm.h dlconstrain.h common.h parameters.h genpsi.h
delparm.o delparm.u: genpsd.h
derf.o derf.u: derf.h
dlconstrain.o dlconstrain.u: dlconstrain.h common.h constraincpp.h parameters.h
dlconstrain.o dlconstrain.u: static.h
dofit.o dofit.u: dofit.h fgenm4.h mrqmin.h parameters.h dynamic.h loadData.h
dofit.o dofit.u: extres.h lenc.h parseva.h genderiv4.h genshift.h dlconstrain.h
dofit.o dofit.u: common.h noFile.h mancon4.h copyBasename.h cleanFree.h genva.h
dofit.o dofit.u: stopFit.h plotit.h queryString.h cparms.h clista.h cdata.h
dofit.o dofit.u: genmem.h genpsi.h genpsc.h genpsr.h genpsl.h genpsd.h static.h
extres.o extres.u: extres.h allocData.h genmem.h common.h parameters.h static.h
fgenm4.o fgenm4.u: fgenm4.h dlconstrain.h common.h genshift.h genderiv4.h
fgenm4.o fgenmr.u: parameters.h cparms.h clista.h genpsr.h genpsi.h genmem.h
fgenm4.o fgenmr.u: cdata.h
genderiv4.o genderiv4.u: genderiv4.h delparm.h extres.h calcReflec.h mancon4.h
genderiv4.o genderiv4.u: parameters.h cparms.h cdata.h common.h genmem.h
genderiv4.o genderiv4.u: genpsl.h genpsc.h genpsr.h genpsi.h genpsd.h static.h
generf.o generf.u: generf.h derf.h calcStep.h static.h parameters.h
genlayers.o genlayers.u: genlayers.h derf.h parameters.h static.h
genmem.o genmem.u: genmem.h common.h parameters.h
genpsc.o genpsc.u: genpsc.h common.h parameters.h cparms.h
genpsd.o genpsd.u: genpsd.h common.h parameters.h
genpsi.o genpsi.u: genpsi.h common.h parameters.h
genpsl.o genpsl.u: genpsl.h common.h parameters.h
genpsr.o genpsr.u: genpsr.h common.h parameters.h
genshift.o genshift.u: genshift.h parameters.h genpsd.h common.h
gentanh.o gentanh.u: gentanh.h calcStep.h parameters.h static.h
genva.o genva.u: genva.h parameters.h
getparams.o getparams.u: getparams.h badInput.h caps.h gentanh.h generf.h
getparams.o getparams.u: queryString.h setLayerParam.h genpsi.h common.h
getparams.o getparams.u: parameters.h genpsr.h genpsl.h cparms.h cdata.h
getparams.o getparams.u: static.h genpsd.h
gj2.o gj2.u: magblocks4.h lenc.h genpsc.h common.h parameters.h cparms.h
glayd.o glayd.u: glayd.h common.h parameters.h
glayi.o glayi.u: glayi.h common.h parameters.h
glayim.o glayim.u: glayim.h common.h parameters.h
glayin.o glayin.u: glayin.h common.h parameters.h
gmagpro4.o gmagpro4.u: gmagpro4.h parameters.h nglayd.h common.h mglayd.h
gmagpro4.o gmagpro4.u: glayd.h glayin.h glayim.h glayi.h genpsi.h
gnuPlot.o gnuPlot.u: gnuPlot.h cparms.h
help.o help.u: help.h queryString.h caps.h defStr.h parameters.h cparms.h
help.o help.u: static.h
lenc.o lenc.u: lenc.h
lenlist.o lenlist.u: lenlist.h
lenpre.o lenpre.u: lenpre.h
loadData.o loadData.u: loadData.h allocData.h lenc.h sortq.h noFile.h genpsi.h
loadData.o loadData.u: common.h parameters.h genpsc.h cparms.h genpsr.h cdata.h
loadParms.o loadParms.u: loadParms.h parms.h dlconstrain.h common.h cparms.h
loadParms.o loadParms.u: cdata.h parameters.h clista.h genpsl.h genpsc.h
loadParms.o loadParms.u: genpsi.h genpsd.h
magblocks4.o magblocks4.u: magblocks4.h loadData.h loadParms.h help.h
magblocks4.o magblocks4.u: getparams.h printinfo.h plotit.h dofit.h gentanh.h
magblocks4.o magblocks4.u: generf.h badInput.h dlconstrain.h common.h caps.h
magblocks4.o magblocks4.u: genshift.h parms.h queryString.h cleanUp.h unix.h
magblocks4.o magblocks4.u: parameters.h cparms.h cdata.h clista.h genmem.h
magblocks4.o magblocks4.u: genpsr.h genpsl.h genpsc.h genpsi.h genpsd.h static.h
mancon4.o mancon4.u: mancon4.h parameters.h cparms.h static.h
mgenlayers.o mgenlayers.u: mgenlayers.h genlayers.h derf.h parameters.h mglayd.h
mgenlayers.o mgenlayers.u: common.h glayim.h
mglayd.o mglayd.u: mglayd.h common.h parameters.h
mrqmin.o mrqmin.u: mrqmin.h parameters.h dynamic.h genmem.h common.h static.h
ngenlayers.o ngenlayers.u: ngenlayers.h genlayers.h derf.h parameters.h
ngenlayers.o ngenlayers.u: nglayd.h common.h glayin.h
nglayd.o nglayd.u: nglayd.h common.h parameters.h
noFile.o noFile.u: noFile.h
parms.o parms.u: parms.h lenc.h generf.h gentanh.h parameters.h cparms.h
parms.o parms.u: genpsr.h static.h
parseva.o parseva.u: parseva.h parameters.h static.h
plotit.o plotit.u: plotit.h loadData.h extres.h gnuPlot.h genlayers.h
plotit.o plotit.u: ngenlayers.h mgenlayers.h gmagpro4.h parseva.h caps.h
plotit.o plotit.u: badInput.h setLayerParam.h queryString.h genderiv4.h
plotit.o plotit.u: noFile.h genva.h stopMovie.h common.h dlconstrain.h cdata.h
plotit.o plotit.u: parameters.h cparms.h glayd.h glayi.h mglayd.h glayim.h
plotit.o plotit.u: nglayd.h glayin.h genpsc.h genpsr.h genpsi.h genpsl.h
plotit.o plotit.u: genpsd.h static.h
printinfo.o printinfo.u: printinfo.h genva.h genlayers.h ngenlayers.h
printinfo.o printinfo.u: mgenlayers.h gmagpro4.h calcReflec.h copyBasename.h
printinfo.o printinfo.u: loadData.h noFile.h genderiv4.h extres.h queryString.h
printinfo.o printinfo.u: cleanFree.h parameters.h cdata.h common.h cparms.h
printinfo.o printinfo.u: mglayd.h nglayd.h glayim.h glayin.h glayd.h glayi.h
printinfo.o printinfo.u: clista.h genpsr.h genpsl.h genpsc.h genpsi.h genpsd.h
printinfo.o printinfo.u: static.h
queryString.o queryString.u: cparms.h cdata.h queryString.h
setLayerParam.o setLayerParam.u: setLayerParam.h queryString.h caps.h
setLayerParam.o setLayerParam.u: badInput.h parseva.h cparms.h genpsd.h common.h
setLayerParam.o setLayerParam.u: parameters.h
sortq.o sortq.u: sortq.h static.h parameters.h
stopFit.o stopFit.u: stopFit.h common.h
stopMovie.o stopMovie.u: stopMovie.h common.h
unix.o unix.u: unix.h queryString.h genpsc.h common.h parameters.h cparms.h
unix.o unix.u: static.h

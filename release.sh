#!/bin/sh

# Build an official release of reflpak.  I'm assuming all the
# tools are in place on your machine, including perl and cvs2cl.pl

# Currently version is tied to date
VERSION="`date +-%Y.%m.%d`"

# I'm assuming this script is being run from one of the build
# machines.  In my case, this is windows since my windows box
# isn't set up for ssh operations.

# Here are my architecture specific build machines:
BUILD="jazz macng7 h122045"
# Grrr... irix machines need gmake rather than make...
makejazz="gmake"
# Each machine has already been set up with a build directory 
# in ~/cvs/reflfit and the appropriate Makeconf.
builddir="~/cvs/reflfit"

# The results are stored and shared in the following directories.
# These may be local or remote since scp doesn't care:
STORE=jazz:release
SHARE=jazz:samba

# The following directory will contain reflpak$VERSION and 
# reflpak-latest symlinked to relfpak$VERSION.
SHAREBIN=jazz:bin

# Rather than getting gif2png conversion to work under
# windows, export the problem to a machine with imagemagic
# and tclsh.
htmlmachine=h122045
# =========== End of configuration ============

echo "== local cvs update ============================"
cvs -q update -dP
for machine in $BUILD; do
    echo;echo "== cvs update on $machine: ===================";
    ssh $machine "cd $builddir && cvs -q update -dP"
done

echo; echo "Are all files committed that need to be?"
echo "Are any files not added that should be added?"
echo "Are the RELEASE-NOTES up to date, and tagged with today's date?"
ls -l RELEASE-NOTES
head -10 RELEASE-NOTES
echo -n "Press y to continue: "
read ans
test "$ans" != "y" && exit


echo; echo "== local build ========================"
make dist
echo; echo "== build html ========================="
ssh $htmlmachine "cd $builddir && make html"
ssh $htmlmachine "cd $builddir && make datadist"
echo; echo "== build source ======================="
make srcdist

for machine in $BUILD; do
    echo; echo "== build on $machine ========================"
    # if make$machine is a defined variable use it, otherwise use 'make'
    par=make$machine
    ssh $machine "cd $builddir && ${!par:-make} dist"
done

mkdir reflpak$VERSION
echo; echo "== gather local build results ====================="
cp release/reflpak$VERSION* reflpak$VERSION
echo; echo "== gather html ======================="
scp -r $htmlmachine:$builddir/html reflpak$VERSION
scp $htmlmachine:$builddir/release/reflpak-data.zip reflpak$VERSION
for machine in $BUILD; do
    echo; echo "== gather results from $machine ================="
    scp "$machine:$builddir/release/reflpak$VERSION*" reflpak$VERSION
done

echo; echo -n "Update server? [y for yes]: "
read ans
test "$ans" != "y" && exit

echo; echo "== updating $STORE, $SHARE and $SHAREBIN ================="
sed -e"s,@VERSION@,$VERSION,g" < INSTALL >reflpak$VERSION/index.html
cp RELEASE-NOTES reflpak$VERSION
tar cjf reflpak$VERSION.tar.bz2 reflpak$VERSION
scp reflpak$VERSION.tar.bz2 "$STORE"
scp -r reflpak$VERSION "$SHARE"
ssh ${SHARE%:*} "cd ${SHARE#*:} && rm reflpak && ln -s reflpak$VERSION reflpak"
ssh ${SHAREBIN%:*} "cd ${SHAREBIN#*:} && cp $builddir/kit/reflpak reflpak$VERSION && rm reflpak && ln -s reflpak$VERSION reflpak"
rm -rf reflpak$VERSION
echo; echo "Please check that $STORE and $SHARE contain what you want"

echo; echo -n "Tag the release? [y for yes]: "
read ans
test "$ans" = "y" && make tagdist

echo Update instrument computers, user room software and web.
echo On a linux box:
echo    scp ~/cvs/reflfit/kit/reflpak cg1@andr:bin/reflpak$VERSION
echo    scp ~/cvs/reflfit/kit/reflpak ng1@ng1refl:bin/reflpak$VERSION
echo    scp ~/cvs/reflfit/kit/reflpak ng7@ng7refl:bin/reflpak$VERSION
echo Also need to point to the latest via symlink.
echo Let users know a new version is available.

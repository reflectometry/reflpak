#!/bin/sh

# Usage: ./release.sh
#
# Build an official release of reflpak, tagged with the current date.
#
# To replace a previous version (e.g., from the previous day), use
#    VERSION=-yyyy.mm.dd ./release.sh
#
# This is highly dependent on my particular setup and must be run from
# the Windows machine.  perl and cvs2cl.pl must be present on this
# machine to perform 'make srcdist'. 
#
# FIXME document other required tools

# Currently version is tied to date
VERSION="-${VERSION:-`date +%Y.%m.%d`}"
echo "Creating relfpak$VERSION"
export VERSION

 
# I'm assuming this script is being run from one of the build
# machines.  In my case, this is windows since my windows box
# isn't set up for ssh operations.

# Here are my architecture specific build machines:
irix=jazz.ncnr.nist.gov
osx=macng7.ncnr.nist.gov
macintel=d121139.ncnr.nist.gov
linux3=h122045.ncnr.nist.gov
linux4=dave.ncnr.nist.gov
win=localhost
arches=irix osx linux4
BUILD="$irix $osx $linux3 $linux4"

# Grrr... irix machines need gmake rather than make...
gmake=$irix

# Rather than getting gif2png conversion to work under
# windows, export the problem to a machine with imagemagick
# and tclsh.
htmlmachine=h122045.ncnr.nist.gov

# Each machine has already been set up with a build directory 
# in ~/cvs/reflfit and the appropriate Makeconf.
builddir="~/danse/reflpak"

# The results are stored and shared in the following directories.
# These may be local or remote since scp doesn't care:
WEBDIR=webster.ncnr.nist.gov:software/release
WEBCP=scp

# The following directory will contain $arch/reflpak$VERSION and 
# a copy of the latest in $arch/reflpak
# MSYS cp to shared is broken for versions before 1.0.11
# We are using cygwin's cp instead.
BINDIR="//charlotte/public/Reflpak"
BINCP="/c/cygwin/bin/cp -r"

# =========== End of configuration ============

# Perform SVN updates on all machines
echo "== svn update ============================"
if false; then
svn update
for machine in $BUILD; do
    echo;echo "== svn update on $machine: ===================";
    ssh $machine "cd $builddir && svn update"
done
else
echo; echo "Automatic svn update is impossible; please make sure"
echo "the following machines are up to date by running update and status:"
echo "   localhost $BUILD"
fi

echo; echo "Are all files committed that need to be?"
echo "Have you done svn update on the local machine?"
echo -n "Press y to continue: "
read ans
test "$ans" != "y" && exit


# Check release notes
echo "Are any files not added that should be added?"
echo "Are the RELEASE-NOTES up to date, and tagged for reflpak$VERSION?"
ls -l RELEASE-NOTES
head -10 RELEASE-NOTES
echo -n "Press y to continue: "
read ans
test "$ans" != "y" && exit

# Do the local build
echo; echo "== build html ========================="
ssh $htmlmachine "cd $builddir && VERSION='$VERSION' make html"
ssh $htmlmachine "cd $builddir && VERSION='$VERSION' make datadist"
echo; echo "== build source ======================="
make srcdist

# Do the remote builds (strictly speaking these could be done
# in parallel but then we would need to deal with synchronization
for machine in $BUILD; do
    echo; echo "== build on $machine ========================"
    # if make$machine is a defined variable use it, otherwise use 'make'
    if test $machine == $gmake; then make=gmake; else make=make; fi
    ssh $machine "cd $builddir && VERSION='$VERSION' $make dist"
done

# Do the local build last since you need to type exit in the interpreter
# when it is complete.
echo; echo "== local build ========================"
make dist
echo; echo "Scroll back and check that the build was error free."
echo -n "Press y to continue: "
read ans
test "$ans" != "y" && exit

# Gather results for the web distribution
rm -rf web; mkdir web
echo; echo "== gather html ======================="
scp -r $htmlmachine:$builddir/html web
scp $htmlmachine:$builddir/release/reflpak-data.zip web

echo; echo "== gather local build results ====================="
cp release/reflpak$VERSION-src.tar.gz web
cp release/reflpak$VERSION.exe web
for machine in $BUILD; do
    echo; echo "== gather results from $machine ================="
    scp "$machine:$builddir/release/reflpak$VERSION*" web
done
sed -e"s,@VERSION@,$VERSION,g" < INSTALL >web/index.html
cp RELEASE-NOTES web

# Gather results for the binary server
rm -rf bin; mkdir bin
for arch in $arches; do
   mkdir bin/$arch
   scp ${!arch}:$builddir/kit/reflpak bin/$arch/reflpak$VERSION
done
mkdir bin/win
cp release/reflpak$VERSION.exe bin/win
cp RELEASE-NOTES bin
cp ChangeLog bin


# Check if we should put the current build on the servers
echo; echo "Check web and bin are free from errors."
echo -n "Update server? [y for yes]: "
read ans
test "$ans" != "y" && exit
echo; echo "== updating $WEBDIR and $BINDIR =="

echo; echo "Copying to $WEBDIR"
if test -d $WEBDIR/reflpak$VERSION; then
    echo; echo "Replace $WEBDIR/reflpak$VERSION? [y for yes]: "
    read ans
    test "$ans" != "y" && exit
    rm -rf $WEBDIR/reflpak$VERSION
fi
$WEBCP -r web "$WEBDIR/reflpak$VERSION"
echo; echo "Copying to $BINDIR"
$BINCP bin/* "$BINDIR"

# Check if we should make the current build an official release
echo; echo "Check $WEBDIR and $BINDIR"
echo; echo -n "Tag the release? [y for yes]: "
read ans
if test "$ans" = "y"; then
    # Tag the cvs tree for the current release
    make tagdist

    # Make the web release current
    ssh ${WEBDIR%:*} "cd ${WEBDIR#*:} && rm reflpak && ln -s reflpak$VERSION reflpak"

    # Make the binary release current
    for arch in $arches; do
	$BINCP bin/$arch/reflpak$VERSION "$BINDIR/$arch/reflpak"
    done
    $BINCP bin/win/reflpak$VERSION.exe "$BINDIR/win/reflpak.exe"
fi

# Make sure the instrument computers are updated.
echo
echo Update instrument computers, user room software and web.
echo    scp bin/linux3/reflpak cg1@andr:bin/reflpak$VERSION
echo    scp bin/linux3/reflpak ng7@ng7refl:bin/reflpak$VERSION
echo    scp bin/linux4/reflpak ng1@ng1refl:bin/reflpak$VERSION
echo Also need to point to the latest via symlink.
echo Let users know a new version is available.

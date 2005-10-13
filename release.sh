#!/bin/sh

# Build an official release of reflpak.  I'm assuming all the
# tools are in place on your machine, including perl and cvs2cl.pl

# Currently version is tied to date
VERSION="`date +-%Y.%m.%d`"

# I'm assuming this script is being run from one of the build
# machines.  In my case, this is windows since my windows box
# isn't set up for ssh operations.

# Here are my architecture specific build machines:
irix=jazz
osx=macng7
linux3=h122045
linux4=dave
win=localhost
BUILD="$irix $osx $linux3 $linux4"

# Grrr... irix machines need gmake rather than make...
makejazz="gmake"

# Rather than getting gif2png conversion to work under
# windows, export the problem to a machine with imagemagick
# and tclsh.
htmlmachine=h122045

# Each machine has already been set up with a build directory 
# in ~/cvs/reflfit and the appropriate Makeconf.
builddir="~/cvs/reflfit"

# The results are stored and shared in the following directories.
# These may be local or remote since scp doesn't care:
WEBDIR=webster:software/release
WEBCP=scp

# The following directory will contain $arch/reflpak$VERSION and 
# a copy of the latest in $arch/reflpak
# MSYS cp to shared is broken for versions before 1.0.11
# We are using cygwin's cp instead.
BINDIR="//charlotte/public/Reflpak"
BINCP="/c/cygwin/bin/cp -r"

# =========== End of configuration ============

# Perform CVS updates on all machines
echo "== cvs update ============================"
cvs -q update -dP
for machine in $BUILD; do
    echo;echo "== cvs update on $machine: ===================";
    ssh $machine "cd $builddir && cvs -q update -dP"
done
echo; echo "Are all files committed that need to be?"
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
ssh $htmlmachine "cd $builddir && make html"
ssh $htmlmachine "cd $builddir && make datadist"
echo; echo "== build source ======================="
make srcdist

# Do the remote builds (strictly speaking these could be done
# in parallel but then we would need to deal with synchronization
for machine in $BUILD; do
    echo; echo "== build on $machine ========================"
    # if make$machine is a defined variable use it, otherwise use 'make'
    par=make$machine
    ssh $machine "cd $builddir && ${!par:-make} && ${!par:-make} dist"
done

# Do the local build last since you need to type exit in the interpreter
# when it is complete.
echo; echo "== local build ========================"
make && make dist
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
cp release/reflpak$VERSION.exe web
for machine in $BUILD; do
    echo; echo "== gather results from $machine ================="
    scp "$machine:$builddir/release/reflpak$VERSION*" web
done
sed -e"s,@VERSION@,$VERSION,g" < INSTALL >web/index.html
cp RELEASE-NOTES web

# Gather results for the binary server
rm -rf bin; mkdir bin
for arch in irix osx linux3 linux4; do
   mkdir bin/$arch
   scp ${!arch}:$builddir/kit/reflpak bin/$arch/reflpak$VERSION
done
mkdir bin/win
cp release/reflpak$VERSION.exe bin/win


# Check if we should put the current build on the servers
echo; echo "Check web and bin are free from errors."
echo -n "Update server? [y for yes]: "
read ans
test "$ans" != "y" && exit
echo; echo "== updating $WEBDIR and $BINDIR =="

echo; echo "Copying to $WEBDIR"
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
    for arch in irix osx linux3 linux4; do
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

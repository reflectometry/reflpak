#! /bin/bash

# Build an official release of reflpak.  Currently version is
# tied to date

VERSION=`date +%Y%m%d`

# I'm assuming this script is being run from one of the build
# machines.  In my case, this is windows since my windows box
# isn't set up for ssh operations.

# Here are my architecture specific build machines.  Each has
# already been set up with a build directory and the appropriate
# Makeconf.  I'm building in ~/cvs/reflfit:
BUILD="jazz bt7motor h122145"
builddir=~/cvs/reflfit
gatherdir=~/release/reflpak$VERSION

# The results are stored and shared in the following directories.
# These may be local or remote since scp doesn't care:
STORE=jazz:release
SHARE=jazz:samba

dir=`pwd`

echo local cvs update 
cd $builddir; cvs -q update -dP; cd $dir
for machine in $BUILD; do
    echo cvs update on $machine:
    ssh $machine "cd $builddir && cvs -q update -dP"
done

echo "Does everything look okay? [y to continue]"
read ans
test "$ans" != "y" && exit


cd $builddir
echo local build
make dist
echo build html
make html
echo build source
make srcdist
cd $dir

for machine in $BUILD; do
    echo build on $machine
    ssh $machine "cd $builddir && make dist"
done

mkdir $gatherdir
echo gather local build results
cp $builddir/release/reflpak$VERSION* $gatherdir
cp -a $builddir/html $gatherdir
for machine in $BUILD; do
    echo gather results from $machine
    scp $machine:$builddir/release/reflpak$VERSION* $DIR
done

cd $gatherdir/..
tar cjf release-reflpak$VERSION.tar.gz reflpak$VERSION
scp release-reflpak$VERSION.tar.gz $STORE
scp -r $gatherdir $SHARE
cd ~dir

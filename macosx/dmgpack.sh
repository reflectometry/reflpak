#/bin/bash

# dmgpack volume [file|dir]+
#
#    Copy a group of files/directories to a compressed disk image.
#    The resulting image is stored in volume.dmg.
#
#    Files are copied with 'ditto' to preserve resource forks.  For
#    convenience we also call FixupResourceForks after copying.  This
#    allows you to use /Developer/Tools/SplitFork on your tree and 
#    manipulate it with CVS, tar, etc.  Don't forget the -kb option 
#    when adding or committing app and ._app files to CVS!
#
#    This command will fail if a volume of the given name is already
#    mounted.  It could also fail if the size of the resource forks
#    is large compared to the size of the data forks. Change the
#    scale factor internally from 11/10 to a more appropriate number
#    if it complains it is running out of space.
#

test $# -lt 2 && echo "usage: $0 diskname [file|dir]+" && exit 1
set -x
NAME=${1%.dmg} ; shift
DISK=/tmp/dmgpack$$.dmg
COMPRESSED=$NAME.dmg
VOLUME=$NAME
# compute needed image size; scale it by 10%
SIZE=$(du -ck $* | tail -1 | sed -e 's/ *total//')
SIZE=$(echo $SIZE*11/10 | bc)
test $SIZE -lt 4200 && SIZE=4200
# create the disk
rm -f $DISK
hdiutil create -size ${SIZE}k $DISK -layout NONE
# create a file system on the disk
DEVICE=$(hdid -nomount $DISK)
newfs_hfs -v $VOLUME $DEVICE
hdiutil eject $DEVICE
# copy stuff to the disk and fixup resource forks
hdid $DISK
for f in $*; do 
	ditto -rsrc $f /Volumes/$VOLUME/$f; 
	test -d $f && /System/Library/CoreServices/FixupResourceForks /Volumes/$VOLUME/$f
done
hdiutil eject $DEVICE
# compress the disk and make it read only
rm -f $COMPRESSED
hdiutil convert -format UDZO $DISK -o $COMPRESSED
rm -f $DISK

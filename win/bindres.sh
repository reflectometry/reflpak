#!/bin/sh

target=$1
resources=$2
if test "x$1" == x -o "x$2" == x ; then
    echo "usage: bindres.sh file.exe vericon.res"
    exit
fi

UPX=/c/Source/ncnrkit/bin/upx
RESHACK=/c/Source/ncnrkit/bin/ResHacker

# cp $target $target-orig
set -x
$UPX -d $target
$RESHACK -delete $target , temp1.exe , icongroup,,
$RESHACK -delete temp1.exe , temp2.exe , versioninfo,,
$RESHACK -add temp2.exe , $target , $resources , ,,
$UPX --compress-icons=0 $target
rm -rf temp1.exe temp2.exe

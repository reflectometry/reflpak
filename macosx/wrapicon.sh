#!/bin/sh

test $# -ne 1 && echo "usage: $0 iconfile" &&  exit 1
iconpath=$1
iconfile=${iconpath##*/}
appdir=${iconfile%.*}.app

mkdir $appdir || exit 1
mkdir $appdir/Contents || exit 1
cat >$appdir/Contents/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>CFBundleIconFile</key>
        <string>$iconfile</string>
</dict>
</plist>
EOF
mkdir $appdir/Contents/Resources || exit 1
cp "$iconpath" $appdir/Contents/Resources
echo "Icon is now in `pwd`/$appdir"

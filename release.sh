VERSION=0.2.0
DATE=`date +%Y-%m-%d`

# base name of the project
PROJECT=reflfit

# use Ryyyy-mm-dd as the tag for revision yyyy.mm.dd
TAG=R$DATE
ROOT=$PROJECT-`date +%Y.%m.%d`

# Update the version number and version date in the appropriate spots
mv tcl/reflfit.help .
sed -e"s,Reflfit v[.].*$,Reflfit v. $VERSION $DATE," <reflfit.help >tcl/reflfit.help
rm reflfit.help 

# Update the repository with the changed files
cvs commit -m "$TAG release" tcl/reflfit.help 

# tag the CVS tree with the revision number
cvs rtag $TAG $PROJECT

# extract the tree into a tagged directory
cvs export -r $TAG -d $ROOT $PROJECT

# generate the ChangeLog for the release tarball ; don't bother
# storing the ChangeLog on CVS.  Otherwise, move this line up
# before commit command, and generate ChangeLog rather than $ROOT/ChangeLog
cvs2cl.pl --fsf --file ChangeLog.tmp
echo "# Automatically generated file --- DO NOT EDIT" | cat - ChangeLog.tmp > $ROOT/ChangeLog
rm -f ChangeLog.tmp

# build the tar ball
tar czf $ROOT.tar.gz $ROOT

# remove the tagged directory
rm -rf $ROOT

# build the documentation
rm -rf html/reflfit
tcl/help2html tcl/*.help

# build the source+binary+doc distribution
tar czf $ROOT-dist.tar.gz $ROOT.tar.gz html bin

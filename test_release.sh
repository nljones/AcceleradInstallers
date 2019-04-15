#!/bin/bash
# This script tests a release tar file for Accelerad.

# Set names
major="0"
minor="7"
target="accelerad_$major$minor"
if [[ $OSTYPE == darwin* ]]; then
    target+="_beta_mac"
    archive="$target.dmg"
    nest="$(pwd)/$target/accelerad"
else
    target+="_beta_linux"
    archive="$target.tar.gz"
    nest="$(pwd)/$target/usr/local/accelerad"
fi
bin="$nest/bin"
lib="$nest/lib"
demo="$nest/demo"

# Create directories
if [[ $OSTYPE != darwin* ]]; then
    rm -rf $target
    tar -zxvf $archive
#else
    #mkdir $target
    #hdiutil mount -quiet $archive
    ##cp -R "/Volumes/Accelerad $major.$minor/Accelerad/" $nest
    #sudo installer -pkg /Volumes/Accelerad $major.$minor/Accelerad.pkg -target $target
    #hdiutil unmount -quiet "/Volumes/Accelerad $major.$minor/"
fi

# Set paths
export PATH=/bin:$bin
export LD_LIBRARY_PATH=$bin
export RAYPATH=$lib
echo "PATH = $PATH"
echo "LD_LIBRARY_PATH = $LD_LIBRARY_PATH"
echo "RAYPATH = $RAYPATH"

# Run tests
pushd $demo
bash test_accelerad_rpict.sh
bash test_accelerad_rtrace.sh
bash test_accelerad_rcontrib.sh
popd

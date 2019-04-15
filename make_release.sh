#!/bin/bash
# This script builds a release package for Accelerad.
# For Linux, it builds a tar file.
# Fpr Mac, it builds a .dmg installer.

# Set names
major="0"
minor="7"
target="accelerad_$major$minor"

# Set library versions
cuda="10.1"
optix="6.0.0"
if [[ $OSTYPE == darwin* ]]; then
    target+="_beta_mac"
    archive="$target.dmg"
    nest="$target/accelerad"
    accelerad_src=~/Accelerad/src
    accelerad_bin=~/Accelerad64/bin/Release
    accelerad_lib=~/Accelerad64/lib
    optix_lib=/Developer/OptiX/lib64/liboptix.$optix.dylib
    cuda_lib=/Developer/NVIDIA/CUDA-$cuda/lib/libcudart.$cuda.dylib
else
    target+="_beta_linux"
    archive="$target.tar.gz"
    nest="$target/usr/local/accelerad"
    accelerad_src=/media/nathaniel/DATA/Accelerad/src
    accelerad_bin=/media/nathaniel/DATA/AcceleradLinux/bin
    accelerad_lib=/media/nathaniel/DATA/AcceleradLinux/lib
    optix_lib=~/NVIDIA-OptiX-SDK-$optix-linux64/lib64/liboptix.so.$optix
    cuda_lib=/usr/local/cuda-$cuda/lib64/libcudart.so.$cuda
fi
bin="$nest/bin"
lib="$nest/lib"
demo="$nest/demo"

# Create directories
rm -f $archive
rm -rf $target
mkdir -p {$bin,$lib,$demo}

# Populate bin directory
cp $accelerad_bin/rpict $bin/accelerad_rpict
cp $accelerad_bin/rtrace $bin/accelerad_rtrace
cp $accelerad_bin/rcontrib $bin/accelerad_rcontrib
cp $accelerad_bin/rfluxmtx $bin/accelerad_rfluxmtx
cp $accelerad_src/util/genBSDF.pl $bin/accelerad_genBSDF.pl
cp $optix_lib $bin
cp $cuda_lib $bin

# Populate lib directory
cp $accelerad_lib/*.ptx $lib
rm -f $lib/{fisheye,material_diffuse,rvu}.ptx
cp $accelerad_lib/rayinit.cal $lib

# Populate demo directory
cp demo/test.oct $demo
cp demo/test.inp $demo
cp demo/test_accelerad_rpict.sh $demo
cp demo/test_accelerad_rtrace.sh $demo
cp demo/test_accelerad_rcontrib.sh $demo

# Populate parent directory
cp license/license.txt $nest
#cp license/OptiX_EndUserLicense.pdf $nest
#cp license/CUDA_EULA.pdf $nest
cp README.pdf $nest

# Create package
if [[ $OSTYPE == darwin* ]]; then
    # Add link to Applications folder
    #ln -s /Applications $target/Applications

    pkg="AcceleradPkg.pkg"
    product="Accelerad.pkg"

    local=~/$target
    cp -R $target $local
    chmod -R 755 $local
    pkgbuild --identifier com.mit.accelerad --version $major.$minor --scripts osx_scripts/ --install-location /usr/local --root $local $pkg
    productbuild --identifier com.mit.accelerad --version $major.$minor --resources . --distribution accelerad.xml $product
    hdiutil create $archive -volname "Accelerad $major.$minor" -srcfolder $product -size 9m
    rm -rf $local
    rm -f $pkg
else
    tar -pczf $archive $target
fi

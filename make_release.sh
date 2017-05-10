#!/bin/bash
# This script builds a release package for Accelerad.
# For Linux, it builds a tar file.
# Fpr Mac, it builds a .dmg installer.

# Set names
major="0"
minor="6"
target="accelerad_$major$minor"
if [[ $OSTYPE == darwin* ]]; then
    target+="_beta_mac"
    archive="$target.dmg"
    nest="$target/accelerad"
    accelerad_src=~/Accelerad/src
    accelerad_bin=~/Accelerad64/bin/Release
    optix_lib=/Developer/OptiX/lib64/liboptix.1.dylib
    cuda_lib=/Developer/NVIDIA/CUDA-7.5/lib/libcudart.7.5.dylib
else
    target+="_beta_linux"
    archive="$target.tar.gz"
    nest="$target/usr/local/accelerad"
    accelerad_src=~/Accelerad/src
    accelerad_bin=~/Accelerad64/bin
    optix_lib=~/NVIDIA-OptiX-SDK-3.9.1-linux64/lib64/liboptix.so.1
    cuda_lib=/usr/local/cuda-7.5/lib64/libcudart.so.7.5
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
cp ~/Accelerad64/src/rt/*.ptx $lib
rm -f $lib/cuda_compile_ptx_generated_{fisheye,diffuse_normal,rvu_generator}.cu.ptx
cp $accelerad_src/rt/rayinit.cal $lib

# Populate demo directory
cp demo/test.oct $demo
cp demo/test.inp $demo
cp demo/test_accelerad_rpict.sh $demo
cp demo/test_accelerad_rtrace.sh $demo
cp demo/test_accelerad_rcontrib.sh $demo

# Populate parent directory
cp license/license.txt $nest
cp license/OptiX_EndUserLicense.pdf $nest
cp license/CUDA_EULA.pdf $nest
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

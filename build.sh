#!/bin/sh

rm -rf Binaries
mkdir Binaries

cd crypto-cpp

mkdir Headers
cp src/starkware/crypto/ffi/*.h Headers/

Targets=('arm64-apple-ios15.5' 'x86_64-apple-ios15.2-simulator' 'arm64-apple-ios15.5-simulator')

SDKs=('iphoneos15.5' 'iphonesimulator15.5' 'iphonesimulator15.5')

TargetsSize=${#Targets[@]}

export CMAKE_CROSSCOMPILING="1"
export CMAKE_CXX_COMPILER="clang++"

for (( i=0; i < $TargetsSize; i++ )); do
    SDKPath=$(xcrun --sdk "${SDKs[i]}" --show-sdk-path -f)
    
    if [[ "${Targets[i]}" == *"arm64"* ]]; then
        echo "Compiling for arm64"
        export CMAKE_SYSTEM_PROCESSOR="arm64"
    else
        echo "Compiling for x86_64"
        export CMAKE_SYSTEM_PROCESSOR="x86_64"
    fi
    
    sed -i'.original' "s^\${CMAKE_CXX_FLAGS} -std=c++17 -Werror -Wall -Wextra -fno-strict-aliasing -fPIC^\${CMAKE_CXX_FLAGS} -std=c++17 -Werror -Wall -Wextra -fno-strict-aliasing -fPIC -arch ${CMAKE_SYSTEM_PROCESSOR} -target ${Targets[i]} -isysroot ${SDKPath}^" CMakeLists.txt
    
    cat CMakeLists.txt
    
    rm -rf build
    mkdir -p build/Release
    
    cd build/Release
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER="${CMAKE_CXX_COMPILER}" -DCMAKE_CXX_FLAGS="-Wno-type-limits -Wno-range-loop-analysis -Wno-unused-parameter" ../..
    cd ../..
    
    make -C build/Release
    if [ $? -ne 0 ]; then exit 1; fi
    
    cp build/Release/src/starkware/crypto/ffi/libcrypto_c_exports.dylib ../Binaries/${Targets[i]}/libcrypto.dylib
done

cd ../..

xcodebuild -create-xcframework -library Binaries/arm64-apple-ios15.5/libcrypto.dylib -headers crypto-cpp/Headers -library Binaries/x86_64-apple-ios15.2-simulator/libcrypto.dylib -headers crypto-cpp/Headers -library Binaries/arm64-apple-ios15.5-simulator/libcrypto.dylib -headers crypto-cpp/Headers -output CCryptoCppStatic.xcframework

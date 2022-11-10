#/usr/bin/env bash

ios_version="16.1"

targets=(
  "arm64-apple-ios$ios_version"
  "arm64-apple-ios$ios_version-simulator"
  # "x86_64-apple-ios$ios_version-simulator"
)

sdk_names=(
  "iphoneos$ios_version"
  "iphonesimulator$ios_version"
  # "iphonesimulator$ios_version"
)

mkdir -p Binaries
mkdir -p Headers

pushd crypto-cpp
echo $(pwd)

# rm -r Build/

targets_size=${#targets[@]}

for (( i=0; i < $targets_size; i++ )); do
  mkdir -p Build/${targets[i]}

  pushd Build/${targets[i]}

  flags="--sysroot $(xcrun --sdk ${sdk_names[i]} --show-sdk-path) -target ${targets[i]}"

  cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="${flags}" \
    -DCMAKE_CROSSCOMPILING="1" \
    -DCMAKE_C_COMPILER_WORKS="1" \
    -DCMAKE_CXX_COMPILER_WORKS="1" \
    -DCMAKE_SYSTEM_NAME="iOS" \
    ../..

  popd

  make -C Build/${targets[i]}

  mkdir -p ../Binaries/${targets[i]}
  cp Build/${targets[i]}/src/starkware/crypto/ffi/libcrypto_c_exports.dylib ../Binaries/${targets[i]}/libcrypto.dylib

done

popd

cp crypto-cpp/src/starkware/crypto/ffi/*.h Headers

build_command="xcodebuild -create-xcframework"

for target in ${targets[*]}; do
  build_command+=" -library Binaries/$target/libcrypto.dylib -headers Headers"
done

build_command+=" -output ccryptocpp.xcframework"

rm -r ccryptocpp.xcframework
eval $build_command

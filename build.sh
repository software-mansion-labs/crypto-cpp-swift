#/usr/bin/env bash

ios_version="16.1"

targets=(
  "arm64-apple-ios$ios_version"
  "arm64-apple-ios$ios_version-simulator"
  "x86_64-apple-ios$ios_version-simulator"
)

sdk_names=(
  "iphoneos$ios_version"
  "iphonesimulator$ios_version"
  "iphonesimulator$ios_version"
)

mkdir -p Binaries
mkdir -p Headers

pushd crypto-cpp

targets_size=${#targets[@]}

for (( i=0; i < $targets_size; i++ )); do
  mkdir -p Build/${targets[i]}

  pushd Build/${targets[i]}

  sdk_sysroot="$(xcrun --sdk ${sdk_names[i]} --show-sdk-path)"

  flags="--sysroot $sdk_sysroot -target ${targets[i]}"

  cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="${flags}" \
    -DCMAKE_CROSSCOMPILING="1" \
    -DCMAKE_C_COMPILER_WORKS="1" \
    -DCMAKE_CXX_COMPILER_WORKS="1" \
    -DCMAKE_SYSTEM_NAME="iOS" \
    -DCMAKE_OSX_SYSROOT="$sdk_sysroot" \
    ../..

  popd

  make -C Build/${targets[i]}

  mkdir -p ../Binaries/${targets[i]}
  cp Build/${targets[i]}/src/starkware/crypto/ffi/libcrypto_c_exports.dylib ../Binaries/${targets[i]}/libcrypto_c_exports.dylib
done

popd

rm Headers/*.h
cp crypto-cpp/src/starkware/crypto/ffi/{ecdsa.h,pedersen_hash.h} Headers

build_command="xcodebuild -create-xcframework"

mkdir -p Binaries/ios
mkdir -p Binaries/iossimulator

lipo -create \
  Binaries/${targets[0]}/libcrypto_c_exports.dylib \
  -output Binaries/ios/libcrypto_c_exports.dylib

lipo -create  \
  Binaries/${targets[1]}/libcrypto_c_exports.dylib \
  Binaries/${targets[2]}/libcrypto_c_exports.dylib \
  -output Binaries/iossimulator/libcrypto_c_exports.dylib

output_binaries=(
  "ios"
  "iossimulator"
)

for target in ${output_binaries[*]}; do
  build_command+=" -library Binaries/$target/libcrypto_c_exports.dylib -headers Headers"
done

build_command+=" -output ccryptocpp.xcframework"

rm -r ccryptocpp.xcframework || true
eval $build_command

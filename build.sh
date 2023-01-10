#/usr/bin/env bash

set -e

ios_version=$(xcrun --sdk iphoneos --show-sdk-platform-version)
macosx_version=$(xcrun --sdk macosx --show-sdk-platform-version)

# When changing targets or sdk_names array, make sure you update
# indexes in fat binary creation at the end of the file.

targets=(
  "arm64-apple-ios$ios_version"
  "arm64-apple-ios$ios_version-simulator"
  "x86_64-apple-ios$ios_version-simulator"
  "arm64-apple-darwin$macosx_version"
  "x86_64-apple-darwin$macosx_version"
)

sdk_names=(
  "iphoneos$ios_version"
  "iphonesimulator$ios_version"
  "iphonesimulator$ios_version"
  "macosx$macosx_version"
  "macosx$macosx_version"
)

mkdir -p Binaries
mkdir -p Headers

pushd crypto-cpp

targets_size=${#targets[@]}

for (( i=0; i < $targets_size; i++ )); do
  mkdir -p Build/${targets[i]}

  pushd Build/${targets[i]}

  sdk_sysroot="$(xcrun --sdk ${sdk_names[i]} --show-sdk-path)"

  if [[ sdk_names[i] == macosx* ]]; then
    system_name="Darwin";
  else 
    system_name="iOS";
  fi

  flags="--sysroot $sdk_sysroot -target ${targets[i]}"

  cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="${flags}" \
    -DCMAKE_CROSSCOMPILING="1" \
    -DCMAKE_C_COMPILER_WORKS="1" \
    -DCMAKE_CXX_COMPILER_WORKS="1" \
    -DCMAKE_SYSTEM_NAME="$system_name" \
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

# Please note, that getting values from arrays below is fixed, so make sure to update
# it when doing changes to targets or sdk_names arrays.

mkdir -p FatBinaries/{"${sdk_names[0]}","${sdk_names[1]}","${sdk_names[3]}"}

lipo -create \
  Binaries/${targets[0]}/libcrypto_c_exports.dylib \
  -output FatBinaries/${sdk_names[0]}/libcrypto_c_exports.dylib

lipo -create  \
  Binaries/${targets[1]}/libcrypto_c_exports.dylib \
  Binaries/${targets[2]}/libcrypto_c_exports.dylib \
  -output FatBinaries/${sdk_names[1]}/libcrypto_c_exports.dylib

lipo -create \
  Binaries/${targets[3]}/libcrypto_c_exports.dylib \
  Binaries/${targets[4]}/libcrypto_c_exports.dylib \
  -output FatBinaries/${sdk_names[3]}/libcrypto_c_exports.dylib

for binary in $(printf "%s\n" "${sdk_names[@]}" | sort -u); do
  build_command+=" -library FatBinaries/$binary/libcrypto_c_exports.dylib -headers Headers"
done

build_command+=" -output ccryptocpp.xcframework"

rm -r ccryptocpp.xcframework || true
eval $build_command

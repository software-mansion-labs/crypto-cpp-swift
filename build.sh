#/usr/bin/env bash

set -e

ios_version=$(xcrun --sdk iphoneos --show-sdk-platform-version)
macosx_version=$(xcrun --sdk macosx --show-sdk-platform-version)

ios_min_version="13.0"
macosx_min_version="12.0"

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
    min_version="$macosx_min_version";
  else 
    system_name="iOS";
    min_version="$ios_min_version";
  fi

  # Get the architecture prefix from the target triple
  arch=$(echo ${targets[i]} | cut -d'-' -f 1)

  cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="${flags}" \
    -DCMAKE_CROSSCOMPILING="1" \
    -DCMAKE_C_COMPILER_WORKS="1" \
    -DCMAKE_CXX_COMPILER_WORKS="1" \
    -DCMAKE_SYSTEM_NAME="$system_name" \
    -DCMAKE_OSX_SYSROOT="$sdk_sysroot" \
    -DCMAKE_OSX_ARCHITECTURES="$arch" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$min_version" \
    ../..

  popd

  make -C Build/${targets[i]}

  mkdir -p ../Binaries/${targets[i]}
  cp Build/${targets[i]}/src/starkware/crypto/ffi/libcrypto_c_exports.dylib ../Binaries/${targets[i]}/libcrypto_c_exports.dylib
done

popd

rm Headers/*.h || true
cp crypto-cpp/src/starkware/crypto/ffi/{ecdsa.h,pedersen_hash.h} Headers

build_command="xcodebuild -create-xcframework"

# Please note, that getting values from arrays below is fixed, so make sure to update
# it when doing changes to targets or sdk_names arrays.

mkdir -p Frameworks/{"${sdk_names[0]}/libcrypto_c_exports.framework","${sdk_names[1]}/libcrypto_c_exports.framework","${sdk_names[3]}/libcrypto_c_exports.framework"}

lipo -create \
  Binaries/${targets[0]}/libcrypto_c_exports.dylib \
  -output Frameworks/${sdk_names[0]}/libcrypto_c_exports.framework/libcrypto_c_exports

lipo -create  \
  Binaries/${targets[1]}/libcrypto_c_exports.dylib \
  Binaries/${targets[2]}/libcrypto_c_exports.dylib \
  -output Frameworks/${sdk_names[1]}/libcrypto_c_exports.framework/libcrypto_c_exports

lipo -create \
  Binaries/${targets[3]}/libcrypto_c_exports.dylib \
  Binaries/${targets[4]}/libcrypto_c_exports.dylib \
  -output Frameworks/${sdk_names[3]}/libcrypto_c_exports.framework/libcrypto_c_exports

plist_cmd="/usr/libexec/PlistBuddy"

for binary in $(printf "%s\n" "${sdk_names[@]}" | sort -u); do
  install_name_tool -id @rpath/libcrypto_c_exports.framework/libcrypto_c_exports ./Frameworks/$binary/libcrypto_c_exports.framework/libcrypto_c_exports

  mkdir -p ./Frameworks/$binary/libcrypto_c_exports.framework/Headers

  cp ./Headers/*.h ./Frameworks/$binary/libcrypto_c_exports.framework/Headers
  cp ./Info.plist ./Frameworks/$binary/libcrypto_c_exports.framework/Info.plist

  if [[ binary == macosx* ]]; then
    min_version="$macosx_min_version";
  else 
    min_version="$ios_min_version";
  fi

  $plist_cmd -c "Add :MinimumOSVersion string $min_version" ./Frameworks/$binary/libcrypto_c_exports.framework/Info.plist

  build_command+=" -framework Frameworks/$binary/libcrypto_c_exports.framework"
done

build_command+=" -output ccryptocpp.xcframework"

rm -r ccryptocpp.xcframework || true
eval $build_command

#!/usr/bin/env bash

# -x echos commands. -u exits if an unintialized variable is used.
# -e exits if a command returns an error.
set -x -u -e

BASE_DIR=$(cd "$(dirname "$0")" ; pwd -P)
cd ${BASE_DIR}

# The location of the final framework build
BUILD_DIR="${BASE_DIR}/build"

VALID_IOS_ARCHS="arm64 armv7 armv7s"
VALID_SIMULATOR_ARCHS="x86_64"

FRAMEWORK_XCODE_PROJECT=${BASE_DIR}/PsiCashLib/PsiCashLib.xcodeproj/

# Clean previous output
rm -rf "${BUILD_DIR}"
rm -rf "${BUILD_DIR}-SIMULATOR"

# Build the framework for phones...
xcodebuild clean build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO" -configuration Release -sdk iphoneos ONLY_ACTIVE_ARCH=NO -project ${FRAMEWORK_XCODE_PROJECT} CONFIGURATION_BUILD_DIR="${BUILD_DIR}"
rc=$?; if [[ $rc != 0 ]]; then
  echo "FAILURE: xcodebuild iphoneos"
  exit $rc
fi

# ...and for the simulator.
xcodebuild clean build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO" -configuration Release -sdk iphonesimulator ARCHS=x86_64 VALID_ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO -project ${FRAMEWORK_XCODE_PROJECT} CONFIGURATION_BUILD_DIR="${BUILD_DIR}-SIMULATOR"
rc=$?; if [[ $rc != 0 ]]; then
  echo "FAILURE: xcodebuild iphonesimulator"
  exit $rc
fi

# Add the simulator x86_64 binary into the main framework binary.
lipo -create "${BUILD_DIR}/PsiCashLib.framework/PsiCashLib" "${BUILD_DIR}-SIMULATOR/PsiCashLib.framework/PsiCashLib" -output "${BUILD_DIR}/PsiCashLib.framework/PsiCashLib"
rc=$?; if [[ $rc != 0 ]]; then
  echo "FAILURE: lipo create"
  exit $rc
fi

# Delete the temporary simulator build files.
rm -rf "${BUILD_DIR}-SIMULATOR"

# Jenkins loses symlinks from the framework directory, which results in a build
# artifact that is invalid to use in an App Store app. Instead, we will zip the
# resulting build and use that as the artifact.
cd "${BUILD_DIR}"
zip --recurse-paths --symlinks build.zip * --exclude "*.DS_Store"

echo "BUILD DONE"

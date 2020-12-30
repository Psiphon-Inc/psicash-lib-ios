#!/usr/bin/env bash

# -x echos commands. -u exits if an unintialized variable is used.
# -e exits if a command returns an error.
set -x -u -e

BASE_DIR=$(cd "$(dirname "$0")" ; pwd -P)
cd ${BASE_DIR}

# The location of the final framework build
BUILD_DIR="${BASE_DIR}/build"

# Clean previous build.
rm -rf "${BUILD_DIR}"

VALID_IOS_ARCHS="arm64 armv7 armv7s"
VALID_SIMULATOR_ARCHS="x86_64"

FRAMEWORK_XCODE_PROJECT=${BASE_DIR}/PsiCashLib/PsiCashLib.xcodeproj/

# Build the framework for iOS,
xcodebuild clean archive \
-project "${FRAMEWORK_XCODE_PROJECT}" \
-scheme "PsiCashLib" \
-configuration "Release" \
-sdk iphoneos \
-archivePath "${BUILD_DIR}/ios.xcarchive" \
CODE_SIGN_IDENTITY="" \
CODE_SIGNING_REQUIRED="NO" \
CODE_SIGN_ENTITLEMENTS="" \
CODE_SIGNING_ALLOWED="NO" \
ONLY_ACTIVE_ARCH="NO" \
BUILD_LIBRARIES_FOR_DISTRIBUTION="YES" \
SKIP_INSTALL="NO"

# build the framework for iOS Simulator,
xcodebuild clean archive \
-project "${FRAMEWORK_XCODE_PROJECT}" \
-scheme "PsiCashLib" \
-configuration "Release" \
-sdk iphonesimulator \
-archivePath "${BUILD_DIR}/ios-simulator.xcarchive" \
CODE_SIGN_IDENTITY="" \
CODE_SIGNING_REQUIRED="NO" \
CODE_SIGN_ENTITLEMENTS="" \
CODE_SIGNING_ALLOWED="NO" \
ONLY_ACTIVE_ARCH="NO" \
BUILD_LIBRARIES_FOR_DISTRIBUTION="YES" \
SKIP_INSTALL="NO"

# # and build the framework for MacCatalyst.
# xcodebuild clean archive \
# -project "${FRAMEWORK_XCODE_PROJECT}" \
# -scheme "PsiCashLib" \
# -configuration "Release" \
# -archivePath "${BUILD_DIR}/catalyst.xcarchive" \
# -destination 'platform=macOS,arch=x86_64,variant=Mac Catalyst' \
# SUPPORTS_MACCATALYST="YES" \
# CODE_SIGN_IDENTITY="" \
# CODE_SIGNING_REQUIRED="NO" \
# CODE_SIGN_ENTITLEMENTS="" \
# CODE_SIGNING_ALLOWED="NO" \
# ONLY_ACTIVE_ARCH="NO" \
# BUILD_LIBRARIES_FOR_DISTRIBUTION="YES" \
# SKIP_INSTALL="NO"

# Creates a single xcframework from both frameworks and their dSYMs.
xcodebuild -create-xcframework \
-framework "${BUILD_DIR}/ios.xcarchive/Products/Library/Frameworks/PsiCashLib.framework" \
-debug-symbols "${BUILD_DIR}/ios.xcarchive/dSYMs/PsiCashLib.framework.dSYM" \
-framework "${BUILD_DIR}/ios-simulator.xcarchive/Products/Library/Frameworks/PsiCashLib.framework" \
-debug-symbols "${BUILD_DIR}/ios-simulator.xcarchive/dSYMs/PsiCashLib.framework.dSYM" \
-output "${BUILD_DIR}/PsiCashLib.xcframework"
# -framework "${BUILD_DIR}/catalyst.xcarchive/Products/Library/Frameworks/PsiCashLib.framework" \
# -debug-symbols "${BUILD_DIR}/catalyst.xcarchive/dSYMs/PsiCashLib.framework.dSYM" \

# Removes frameworks used to build the xcframework
rm -rf "${BUILD_DIR}/ios.xcarchive"
rm -rf "${BUILD_DIR}/ios-simulator.xcarchive"


# Jenkins loses symlinks from the framework directory, which results in a build
# artifact that is invalid to use in an App Store app. Instead, we will zip the
# resulting build and use that as the artifact.
cd "${BUILD_DIR}"
zip --recurse-paths --symlinks build.zip * --exclude "*.DS_Store"

echo "BUILD DONE"

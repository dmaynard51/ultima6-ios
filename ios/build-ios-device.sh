#!/bin/bash
# Build + sign Nuvie (Ultima 6) for a physical iPhone/iPad and install it.
#
# Prereqs:
#   - Xcode signed in with the Apple ID that owns the development team.
#   - iPhone connected by cable, unlocked, and "Trust This Computer" accepted.
#   - cmake (brew install cmake).
#
# Usage: ios/build-ios-device.sh <AppleTeamID> /path/to/ultima6-game-data
#   e.g. ios/build-ios-device.sh ABCDE12345 "/path/to/ULTIMA6"
# Find your Team ID with: security find-identity -v -p codesigning
set -euo pipefail

NUVIE_SRC="$(cd "$(dirname "$0")/.." && pwd)"
TEAM="${1:?Usage: build-ios-device.sh <AppleTeamID> /path/to/ultima6-data}"
U6_GAMEDIR="${2:?Usage: build-ios-device.sh <AppleTeamID> /path/to/ultima6-data}"
WORK="${NUVIE_SRC}/ios/build"
SDL_VER="2.30.10"
# Bundle id must match your provisioning profile. Override via env var.
BUNDLE_ID="${NUVIE_IOS_BUNDLE_ID:-info.nuvie.ultima6}"

mkdir -p "$WORK"; cd "$WORK"

# 1. SDL2 static for the device (iphoneos arm64), built once.
if [ ! -f "$WORK/sdl2-device/Release-iphoneos/libSDL2.a" ]; then
  [ -d "SDL2-${SDL_VER}" ] || {
    curl -L -o SDL2.tar.gz \
      "https://github.com/libsdl-org/SDL/releases/download/release-${SDL_VER}/SDL2-${SDL_VER}.tar.gz"
    tar xzf SDL2.tar.gz
  }
  rm -rf sdl2-device && mkdir sdl2-device && cd sdl2-device
  cmake "../SDL2-${SDL_VER}" -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
    -DSDL_STATIC=ON -DSDL_SHARED=OFF -DSDL_TEST=OFF
  xcodebuild -project SDL2.xcodeproj -target SDL2-static -configuration Release \
    -sdk iphoneos -arch arm64 CODE_SIGNING_ALLOWED=NO
  xcodebuild -project SDL2.xcodeproj -target SDL2main -configuration Release \
    -sdk iphoneos -arch arm64 CODE_SIGNING_ALLOWED=NO
  cd "$WORK"
fi

SDL_SRC="$WORK/SDL2-${SDL_VER}"
SDL_LIBDIR="$WORK/sdl2-device/Release-iphoneos"

# 2. Configure + build the signed app for the device.
rm -rf nuvie-device && mkdir nuvie-device && cd nuvie-device
cmake "$NUVIE_SRC" -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DSDL2_INCLUDE_DIR="$SDL_SRC/include" \
  -DSDL2_LIBRARY="$SDL_LIBDIR/libSDL2.a" \
  -DSDL2MAIN_LIBRARY="$SDL_LIBDIR/libSDL2main.a" \
  -DNUVIE_U6_GAMEDIR="$U6_GAMEDIR" \
  -DNUVIE_IOS_TEAM="$TEAM" \
  -DNUVIE_IOS_BUNDLE_ID="$BUNDLE_ID"

# -allowProvisioningUpdates lets Xcode create/refresh the provisioning profile
# for the bundle id on your personal team automatically.
xcodebuild -project nuvie.xcodeproj -target nuvie -configuration Release \
  -sdk iphoneos -arch arm64 -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM"

APP="$WORK/nuvie-device/Release-iphoneos/nuvie.app"
echo; echo "Signed app: $APP"

# 3. Install + launch on the connected device (first available).
DEVICE_ID="$(xcrun devicectl list devices 2>/dev/null \
  | awk '/available/ && /iPhone|iPad/ {print $3; exit}')"
if [ -n "${DEVICE_ID:-}" ]; then
  echo "Installing to device $DEVICE_ID ..."
  xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
  xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"
else
  echo "No available device found. Connect+unlock your iPhone and run:"
  echo "  xcrun devicectl device install app --device <id> '$APP'"
fi

#!/bin/bash
# Build Nuvie (Ultima 6) as a native iOS app for the iOS Simulator.
#
# Prereqs: Xcode + command-line tools, cmake (brew install cmake).
# Usage:   ios/build-ios-sim.sh /path/to/ultima6-game-data
#
# The game-data directory is the folder containing the original Ultima 6 files
# (MAP, CHUNKS, OBJTILES.VGA, CONVERSE.A, MAPTILES.VGA, ...).
set -euo pipefail

NUVIE_SRC="$(cd "$(dirname "$0")/.." && pwd)"
U6_GAMEDIR="${1:?Usage: build-ios-sim.sh /path/to/ultima6-game-data}"
WORK="${NUVIE_SRC}/ios/build"
SDL_VER="2.30.10"
ARCH="arm64"   # arm64 simulator (Apple Silicon); use x86_64 on Intel Macs.

mkdir -p "$WORK"
cd "$WORK"

# 1. Fetch + build SDL2 static lib for the iOS Simulator (once).
if [ ! -f "$WORK/sdl2-build/Release-iphonesimulator/libSDL2.a" ]; then
  [ -d "SDL2-${SDL_VER}" ] || {
    curl -L -o SDL2.tar.gz \
      "https://github.com/libsdl-org/SDL/releases/download/release-${SDL_VER}/SDL2-${SDL_VER}.tar.gz"
    tar xzf SDL2.tar.gz
  }
  rm -rf sdl2-build && mkdir sdl2-build && cd sdl2-build
  cmake "../SDL2-${SDL_VER}" -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES="${ARCH}" -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
    -DSDL_STATIC=ON -DSDL_SHARED=OFF -DSDL_TEST=OFF
  xcodebuild -project SDL2.xcodeproj -target SDL2-static -configuration Release \
    -sdk iphonesimulator -arch "${ARCH}"
  xcodebuild -project SDL2.xcodeproj -target SDL2main -configuration Release \
    -sdk iphonesimulator -arch "${ARCH}"
  cd "$WORK"
fi

SDL_SRC="$WORK/SDL2-${SDL_VER}"
SDL_LIBDIR="$WORK/sdl2-build/Release-iphonesimulator"

# 2. Configure + build Nuvie as an iOS app bundle (data is bundled post-build).
rm -rf nuvie-build && mkdir nuvie-build && cd nuvie-build
cmake "$NUVIE_SRC" -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_ARCHITECTURES="${ARCH}" -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DSDL2_INCLUDE_DIR="$SDL_SRC/include" \
  -DSDL2_LIBRARY="$SDL_LIBDIR/libSDL2.a" \
  -DSDL2MAIN_LIBRARY="$SDL_LIBDIR/libSDL2main.a" \
  -DNUVIE_U6_GAMEDIR="$U6_GAMEDIR"
xcodebuild -project nuvie.xcodeproj -target nuvie -configuration Release \
  -sdk iphonesimulator -arch "${ARCH}" CODE_SIGNING_ALLOWED=NO

APP="$WORK/nuvie-build/Release-iphonesimulator/nuvie.app"
echo
echo "Built: $APP"
echo "Run with:"
echo "  xcrun simctl boot 'iPhone 15' 2>/dev/null; open -a Simulator"
echo "  xcrun simctl install booted '$APP'"
echo "  xcrun simctl launch booted info.nuvie.daniel.ultima6"

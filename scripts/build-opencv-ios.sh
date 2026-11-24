#!/usr/bin/env bash
set -euo pipefail
# OpenCV objdetect includes ArUco in 4.10; contrib is included for ChArUco support.
REPO_ROOT="$PWD"
OPENCV_VERSION=4.10.0
mkdir -p "$CM_BUILD_DIR/opencv-src"
cd "$CM_BUILD_DIR/opencv-src"
git clone --depth 1 --branch "$OPENCV_VERSION" https://github.com/opencv/opencv.git
git clone --depth 1 --branch "$OPENCV_VERSION" https://github.com/opencv/opencv_contrib.git
python3 opencv/platforms/ios/build_framework.py "$CM_BUILD_DIR/opencv-output" \
  --contrib "$CM_BUILD_DIR/opencv-src/opencv_contrib" \
  --xcframework \
  --iphoneos_archs arm64 \
  --iphonesimulator_archs arm64 \
  --build_only_specified_archs
FOUND=$(find "$CM_BUILD_DIR/opencv-output" -name '*.xcframework' -type d -print -quit)
test -n "$FOUND"
cp -R "$FOUND" "$REPO_ROOT/OpenCV.xcframework"
# Codemagic normally checks out repository under CM_BUILD_DIR.

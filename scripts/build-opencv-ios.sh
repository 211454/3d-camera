#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$PWD"
OPENCV_VERSION=4.10.0
mkdir -p "$CM_BUILD_DIR/opencv-src"
cd "$CM_BUILD_DIR/opencv-src"
git clone --depth 1 --branch "$OPENCV_VERSION" https://github.com/opencv/opencv.git
git clone --depth 1 --branch "$OPENCV_VERSION" https://github.com/opencv/opencv_contrib.git
python3 opencv/platforms/ios/build_framework.py "$CM_BUILD_DIR/opencv-output" \
  --contrib "$CM_BUILD_DIR/opencv-src/opencv_contrib" \
  --iphoneos_archs arm64 \
  --iphonesimulator_archs '' \
  --build_only_specified_archs
FOUND=$(find "$CM_BUILD_DIR/opencv-output" -name 'opencv2.framework' -type d -print -quit)
test -n "$FOUND" || { echo "ERROR: opencv2.framework not found"; exit 1; }
cp -R "$FOUND" "$REPO_ROOT/opencv2.framework"

HEADERS="$REPO_ROOT/opencv2.framework/Headers"
for header in core.hpp imgproc.hpp objdetect/aruco_detector.hpp objdetect/aruco_dictionary.hpp; do
  test -f "$HEADERS/$header" || { echo "ERROR: Missing OpenCV header: $HEADERS/$header"; exit 1; }
done
echo "OpenCV framework headers verified"

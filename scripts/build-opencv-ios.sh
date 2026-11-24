#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$PWD"
OPENCV_VERSION=4.10.0
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
if [[ "${1:-iphoneos}" == "iphoneos" ]]; then
  curl --fail --location --retry 3 -o "$WORK_DIR/opencv.zip" "https://github.com/opencv/opencv/releases/download/$OPENCV_VERSION/opencv-$OPENCV_VERSION-ios-framework.zip"
  echo "cbd21c62a4cfdd4cfe7e69c8601d23976e2d2bd05a912d0759debb3052c257db  $WORK_DIR/opencv.zip" | shasum -a 256 -c -
  ditto -x -k "$WORK_DIR/opencv.zip" "$WORK_DIR/extracted"
  FOUND=$(find "$WORK_DIR/extracted" -name opencv2.framework -type d -print -quit)
else
  git clone --depth 1 --branch "$OPENCV_VERSION" https://github.com/opencv/opencv.git "$WORK_DIR/opencv"
  python3 "$WORK_DIR/opencv/platforms/ios/build_framework.py" "$WORK_DIR/output" --iphoneos_archs '' --iphonesimulator_archs arm64 --build_only_specified_archs --disable-bitcode --iphoneos_deployment_target 16.0
  FOUND=$(find "$WORK_DIR/output" -name opencv2.framework -type d -print -quit)
fi
test -n "$FOUND" || { echo "ERROR: opencv2.framework not found"; exit 1; }
rm -rf "$REPO_ROOT/opencv2.framework"
ditto "$FOUND" "$REPO_ROOT/opencv2.framework"
HEADERS="$REPO_ROOT/opencv2.framework/Headers"
for header in core.hpp imgproc.hpp objdetect/aruco_detector.hpp objdetect/aruco_dictionary.hpp; do
  test -f "$HEADERS/$header" || { echo "ERROR: Missing OpenCV header: $HEADERS/$header"; exit 1; }
done
lipo -verify_arch arm64 "$REPO_ROOT/opencv2.framework/opencv2"
echo "OpenCV framework headers and arm64 verified"

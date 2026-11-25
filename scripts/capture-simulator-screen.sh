#!/usr/bin/env bash
set -euo pipefail
# Capture the ACTUAL built app UI, not a generated mockup.
OUT="${CM_BUILD_DIR:-$PWD}/screenshots"
APP="${CM_BUILD_DIR:-$PWD}/SimulatorDerivedData/Build/Products/Debug-iphonesimulator/AUTOKLINIKCamera.app"
mkdir -p "$OUT"
test -d "$APP" || { echo "Simulator .app missing: $APP"; exit 1; }
DEVICE="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; a=[x["udid"] for group in d.values() for x in group if "iPhone" in x["name"] and x["state"]=="Booted"]; b=[x["udid"] for group in d.values() for x in group if "iPhone" in x["name"] and x["state"]=="Shutdown"]; print((a+b)[0] if a+b else "")')"
test -n "$DEVICE" || { echo "No available iPhone simulator"; exit 1; }
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" de.autoklinik.camera3dtest
sleep 4
xcrun simctl io "$DEVICE" screenshot "$OUT/autoklinik-actual-simulator.png"
test -s "$OUT/autoklinik-actual-simulator.png"
echo "Real simulator screenshot: $OUT/autoklinik-actual-simulator.png"

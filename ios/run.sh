#!/bin/zsh
# Rebuild the Fuel iOS app and relaunch it in the open simulator.
# Usage:  ./run.sh            (Debug build — talks to your Mac's local backend)
#         ./run.sh release    (Release build — talks to the deployed Render backend)
set -e
cd "$(dirname "$0")"

CONFIG=Debug
[[ "$1" == "release" ]] && CONFIG=Release
DEVICE="iPhone 17 Pro"
DD="$HOME/Library/Developer/Xcode/DerivedData/Fuel-run"

echo "▸ building ($CONFIG)…"
xcodebuild -project Fuel.xcodeproj -scheme Fuel -configuration "$CONFIG" \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DD" -quiet build

xcrun simctl bootstatus "$DEVICE" -b > /dev/null
open -a Simulator
xcrun simctl install "$DEVICE" "$DD/Build/Products/$CONFIG-iphonesimulator/Fuel.app"
xcrun simctl terminate "$DEVICE" com.omarstate.fuel 2>/dev/null || true
xcrun simctl launch "$DEVICE" com.omarstate.fuel > /dev/null
echo "✓ Fuel ($CONFIG) is running in the simulator"

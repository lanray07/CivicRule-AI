#!/bin/bash
set -euo pipefail
APP=build/DerivedData/Build/Products/Debug-iphonesimulator/CivicRule.app
RUNTIME=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; a=[x for x in json.load(sys.stdin)["runtimes"] if x.get("isAvailable") and "iOS" in x["name"]]; print(max(a,key=lambda x:tuple(map(int,x["version"].split("."))))["identifier"])')
for DEVICE in iphone ipad; do
  if [ "$DEVICE" = iphone ]; then
    TYPE=com.apple.CoreSimulator.SimDeviceType.iPhone-11-Pro-Max
  else
    TYPE=$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys; d=json.load(sys.stdin)["devicetypes"]; print(next(x["identifier"] for x in d if "iPad Pro 13-inch" in x["name"]))')
  fi
  UDID=$(xcrun simctl create "CivicRule-$DEVICE" "$TYPE" "$RUNTIME")
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b
  xcrun simctl status_bar "$UDID" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
  xcrun simctl ui "$UDID" appearance light
  xcrun simctl install "$UDID" "$APP"
  mkdir -p "build/screenshots/$DEVICE"
  for SCENE in welcome overview checklist voice documents lease; do
    xcrun simctl terminate "$UDID" com.civicrule.ios >/dev/null 2>&1 || true
    xcrun simctl launch "$UDID" com.civicrule.ios --screenshot-scene "$SCENE"
    sleep 3
    xcrun simctl io "$UDID" screenshot "build/screenshots/$DEVICE/$SCENE.png"
  done
  xcrun simctl shutdown "$UDID"
done

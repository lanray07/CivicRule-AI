#!/bin/bash
set -euo pipefail
APP=build/DerivedData/Build/Products/Debug-iphonesimulator/CivicRule.app
run_timeout() {
  local seconds="$1"
  shift
  python3 - "$seconds" "$@" <<'PY'
import subprocess, sys
subprocess.run(sys.argv[2:], check=True, timeout=int(sys.argv[1]))
PY
}
launch_scene() {
  local udid="$1"
  local scene="$2"
  if run_timeout 60 xcrun simctl launch "$udid" com.civicrule.ios --screenshot-scene "$scene"; then
    return
  fi
  echo "Initial launch timed out for $scene; allowing simulator services to settle and retrying"
  sleep 10
  xcrun simctl terminate "$udid" com.civicrule.ios >/dev/null 2>&1 || true
  run_timeout 90 xcrun simctl launch "$udid" com.civicrule.ios --screenshot-scene "$scene"
}
RUNTIME=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; a=[x for x in json.load(sys.stdin)["runtimes"] if x.get("isAvailable") and "iOS" in x["name"]]; print(max(a,key=lambda x:tuple(map(int,x["version"].split("."))))["identifier"])')
for DEVICE in iphone ipad; do
  echo "Preparing $DEVICE simulator"
  if [ "$DEVICE" = iphone ]; then
    TYPE=com.apple.CoreSimulator.SimDeviceType.iPhone-11-Pro-Max
  else
    TYPE=$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys; d=json.load(sys.stdin)["devicetypes"]; print(next(x["identifier"] for x in d if "iPad Pro 13-inch" in x["name"]))')
  fi
  UDID=$(xcrun simctl create "CivicRule-$DEVICE" "$TYPE" "$RUNTIME")
  xcrun simctl boot "$UDID"
  run_timeout 240 xcrun simctl bootstatus "$UDID" -b
  xcrun simctl status_bar "$UDID" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
  xcrun simctl ui "$UDID" appearance light
  xcrun simctl install "$UDID" "$APP"
  mkdir -p "build/screenshots/$DEVICE"
  for SCENE in welcome overview checklist voice documents lease permits sources privacy address; do
    echo "Capturing $DEVICE/$SCENE"
    xcrun simctl terminate "$UDID" com.civicrule.ios >/dev/null 2>&1 || true
    launch_scene "$UDID" "$SCENE"
    sleep 3
    run_timeout 30 xcrun simctl io "$UDID" screenshot "build/screenshots/$DEVICE/$SCENE.png"
  done
  run_timeout 30 xcrun simctl shutdown "$UDID"
  xcrun simctl delete "$UDID" || true
done

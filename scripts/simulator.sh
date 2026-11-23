#!/bin/bash
# Runs the Debug build in an iPhone simulator: self-test first, then one screenshot per screen.
set -uo pipefail
APP=build/dd/Build/Products/Debug-iphonesimulator/Volna.app
ID=com.neoss75.volna.swift
mkdir -p shots
# macOS has no "timeout": every simulator command gets a limit, so a stuck simulator cannot hang the job
t() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$s" "$@"; }
say() { echo "[$(date +%T)] $*"; }

RUNTIME=$(xcrun simctl list runtimes | grep -E '^iOS 26' | tail -n 1 | grep -oE 'com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9-]+')
[ -n "$RUNTIME" ] || { echo "::error::no iOS 26 simulator here"; xcrun simctl list runtimes; exit 1; }
TYPE=$(xcrun simctl list devicetypes | grep -E 'iPhone 1[67] Pro Max' | tail -n 1 | grep -oE 'com\.apple\.CoreSimulator\.SimDeviceType\.[A-Za-z0-9-]+')
echo "$RUNTIME $TYPE"
DEV=$(xcrun simctl create volna "$TYPE" "$RUNTIME")
say boot
xcrun simctl boot "$DEV"
t 420 xcrun simctl bootstatus "$DEV" -b | tail -n 3
say booted
xcrun simctl ui "$DEV" appearance dark
xcrun simctl status_bar "$DEV" override --time 9:41 --batteryState charged --batteryLevel 100 || true
t 120 xcrun simctl install "$DEV" "$APP"

say self-test
t 120 xcrun simctl launch --stdout="$PWD/shots/out.txt" --stderr="$PWD/shots/selftest.txt" "$DEV" $ID -demo -selftest
for _ in $(seq 1 170); do
  grep -q 'SELFTEST done' shots/selftest.txt 2>/dev/null && break
  sleep 1
done
grep -o 'SELFTEST.*' shots/selftest.txt
grep -vE 'SELFTEST' shots/selftest.txt | grep -iE 'exception|fatal|crash|error' | head -20
RESULT=0
grep -q 'SELFTEST done' shots/selftest.txt || { echo "::error::the self-test did not finish"; RESULT=1; }
grep -q 'SELFTEST FAIL' shots/selftest.txt && { echo "::error::self-test failures"; RESULT=1; }
xcrun simctl terminate "$DEV" $ID || true
if [ $RESULT != 0 ]; then find ~/Library/Logs/DiagnosticReports -name 'Volna*' -exec cp {} shots/ \; 2>/dev/null; fi
xcrun simctl uninstall "$DEV" $ID
xcrun simctl install "$DEV" "$APP"

shot() { # shot <name> <arguments…>
  local name="$1"; shift
  say "$name"
  t 60 xcrun simctl launch "$DEV" $ID -demo "$@" > /dev/null
  sleep 7
  t 30 xcrun simctl io "$DEV" screenshot "shots/$name.png" > /dev/null 2>&1
  t 30 xcrun simctl terminate "$DEV" $ID > /dev/null 2>&1 || true
}
# the first start after installing is slow: warm up
t 60 xcrun simctl launch "$DEV" $ID -demo > /dev/null; sleep 25; t 30 xcrun simctl terminate "$DEV" $ID > /dev/null 2>&1
shot 01-player
shot 02-list -panel list
shot 02a-albums -folder -panel list -tab albums
shot 02b-album -folder -panel list -tab albums -album
shot 02c-artists -folder -panel list -tab artists
shot 02d-folders -folder -panel list -tab folders
shot 03-queue -panel queue
shot 04-eq -panel eq -eqrock
shot 05-settings -panel fx
shot 05a-sound -panel fx -page sound
shot 05b-playback -panel fx -page playback
shot 05c-hires -panel fx -page hires
shot 05d-viz -panel fx -page viz
shot 05e-library -panel fx -page library
shot 06-stats -panel stats
shot 07-lyrics -lyrics
shot 08-ring -viz ring
shot 09-vu -viz vu
shot 10-light -theme light
shot 11-widgets -widgets -theme dark
for f in shots/*.png; do sips -Z 1100 "$f" > /dev/null; done
exit $RESULT

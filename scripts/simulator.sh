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
for _ in $(seq 1 290); do
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

# Only the screens touched by the current change, all of them take 20 minutes: ONLY='.'
ONLY='^(01|70)-'
shot() { # shot <name> <arguments…>
  local name="$1"; shift
  [[ "$name" =~ $ONLY ]] || return 0
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
shot 02e-lossless -lossless
shot 02f-lossless-list -lossless -panel list
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
shot 12-land-bars -landscape -theme dark -viz bars
shot 13-land-ring -landscape -viz ring
shot 14-land-vu -landscape -viz vu
shot 15-land-lyrics -landscape -viz bars -lyrics
shot 16-land-list -landscape -panel list
shot 17-land-lossless -landscape -lossless
shot 18-saver-bars -saver -viz bars -theme light
shot 19-saver-ring -saver -viz ring -theme dark
shot 20-saver-vu -saver -viz vu
shot 21-saver-led -saver -viz led
shot 22-saver-land-bars -landscape -saver -viz bars
shot 23-saver-land-ring -landscape -saver -viz ring
shot 24-saver-land-vu -landscape -saver -viz vu
shot 25-gallery -vizgallery -theme dark
shot 26-gallery-light -vizgallery -theme light
shot 27-level-bars -viz bars -colors level -theme dark
shot 28-level-ring -viz ring -colors level
shot 29-rainbow-ring -viz ring -colors rainbow
shot 31-saver-sparks -saver -viz sparks -colors fire
shot 32-saver-pulse -saver -viz pulse -colors neon
shot 33-saver-stars -saver -viz stars -colors level
shot 34-saver-flower -saver -viz flower -colors neon
shot 35-saver-ridges -saver -viz ridges -colors level
shot 36-saver-scope -saver -viz scope -colors level
shot 37-saver-land-ribbons -landscape -saver -viz ribbons -colors neon
shot 38-saver-land-dots -landscape -saver -viz dots -colors level
shot 50-saver-kaleido -saver -viz kaleido -colors level -theme dark
shot 51-saver-flows -saver -viz flows -colors neon
shot 52-saver-tiles -saver -viz tiles -colors level
shot 53-saver-drop -saver -viz drop -colors neon
shot 54-saver-confetti -saver -viz confetti -colors rainbow
shot 55-saver-aurora -saver -viz aurora -colors rainbow
shot 56-saver-land-kaleido -landscape -saver -viz kaleido -colors neon
shot 57-saver-land-tiles -landscape -saver -viz tiles -colors fire
shot 70-path -panel fx -page path
shot 74-siri -panel fx -page siri
shot 71-path-usb -lossless -port usb -panel fx -page path
shot 72-path-bt -port bt -panel fx -page path
shot 73-path-en -lang en -port bt -panel fx -page path
for l in uk en; do
  shot 60-$l-player -lang $l
  shot 61-$l-list -lang $l -panel list
  shot 62-$l-settings -lang $l -panel fx
  shot 63-$l-playback -lang $l -panel fx -page playback
  shot 64-$l-viz -lang $l -panel fx -page viz
  shot 65-$l-language -lang $l -panel fx -page language
  shot 66-$l-stats -lang $l -panel stats
  shot 67-$l-eq -lang $l -panel eq
  shot 68-$l-hires -lang $l -panel fx -page hires
done
for f in shots/*-land-*.png; do W=$(sips -g pixelWidth "$f" | awk '/pixelWidth/{print $2}'); H=$(sips -g pixelHeight "$f" | awk '/pixelHeight/{print $2}'); [ "$W" -lt "$H" ] && sips -r 270 "$f" > /dev/null; done
for f in shots/*.png; do sips -Z 1100 "$f" > /dev/null; done
exit $RESULT

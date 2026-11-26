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

# Ogg Vorbis and Ogg Opus files for the self-test: three seconds of a tone, with a title
say "ogg test files"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_ENV_HINTS=1
command -v oggenc > /dev/null && command -v opusenc > /dev/null || t 400 brew install --quiet vorbis-tools opus-tools > /dev/null 2>&1 || true
mkdir -p build
python3 - << 'PY'
import math, struct, wave
with wave.open("build/tone.wav", "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(44100)
    w.writeframes(b"".join(struct.pack("<hh", int(16000 * math.sin(2 * math.pi * 440 * i / 44100)), int(16000 * math.sin(2 * math.pi * 660 * i / 44100))) for i in range(44100 * 3)))
PY
DOCS="$(xcrun simctl get_app_container "$DEV" $ID data)/Documents"
mkdir -p "$DOCS"
oggenc -Q -q 3 -t "Тест Vorbis" -a "Волна" -o "$DOCS/Тест Vorbis.ogg" build/tone.wav || echo "::warning::no oggenc"
opusenc --quiet --title "Тест Opus" --artist "Волна" build/tone.wav "$DOCS/Тест Opus.opus" || echo "::warning::no opusenc"
ls -l "$DOCS"

say self-test
t 400 xcrun simctl launch --stdout="$PWD/shots/out.txt" --stderr="$PWD/shots/selftest.txt" "$DEV" $ID -demo -selftest
for _ in $(seq 1 900); do
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
ONLY='^(01-player|05a-sound|05e-library|05j-lyrics|74-siri)'
# The touch tests take 4-8 minutes: TOUCH=1 only when buttons or gestures change
TOUCH=0
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
shot 01b-loop -loop
shot 01c-loop-uk -loop -lang uk
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
shot 05f-theme -panel fx -page theme
shot 05d-viz -panel fx -page viz
shot 05e-library -panel fx -page library
shot 05g-covers -panel fx -page covers
shot 05h-backup -panel fx -page backup
shot 05j-lyrics -panel fx -page lyrics
shot 05i-backup-waiting -panel fx -page backup -waiting
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
shot 90-phones -buds 'Redmi Buds 6 Pro' -panel fx -page headphones
shot 91-phones-profile -buds 'Redmi Buds 6 Pro' -profile -panel fx -page headphones
shot 92-phones-other -buds 'AirPods Pro (Андрей )' -profile -panel fx -page headphones
shot 93-phones-path -buds 'AirPods Pro (Андрей )' -panel fx -page path
shot 94-phones-editor -buds 'AirPods Pro (Андрей )' -panel fx -page headphones -editor
shot 95-cue -cue
shot 96-cue-list -cue -panel list
shot 97-wifi -panel fx -page wifi -wifisent
# the same page as the computer sees it: Safari in the simulator, while the app keeps receiving
if [[ "97-wifi" =~ $ONLY ]]; then
  say 98-wifi-browser
  t 60 xcrun simctl launch "$DEV" $ID -demo -panel fx -page wifi -wifisent > /dev/null
  sleep 12
  t 30 xcrun simctl openurl "$DEV" "http://127.0.0.1:8080/" || true
  sleep 10
  t 30 xcrun simctl io "$DEV" screenshot "shots/98-wifi-browser.png" > /dev/null 2>&1
  t 30 xcrun simctl terminate "$DEV" $ID > /dev/null 2>&1 || true
fi
shot 80-radio -radio
shot 81-radio-list -radio -panel radio
shot 87-radio-check -radio -stationcheck -panel radio
shot 88-radio-uk -lang uk -radio
shot 89a-radio-cover -radio -radioextras
shot 89b-radio-lyrics -radio -radioextras -lyrics
shot 89c-radio-lyrics-off -radio -lyrics
shot 89d-radio-ring -radio -radioextras -viz ring
shot 82-radio-land -landscape -radio
shot 83-radio-empty -panel radio
shot 84-radio-new -panel radio -newstation
shot 85-radio-path -radio -panel fx -page path
shot 86-radio-light -radio -theme light -viz ring
shot 74-siri -panel fx -page siri
shot 71-path-usb -lossless -port usb -panel fx -page path
shot 72-path-bt -port bt -panel fx -page path
shot 75-path-aac-bt -aac -port bt -panel fx -page path
shot 76-path-aac -aac -panel fx -page path
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
if [ "$TOUCH" = 1 ]; then
  say "real touches"
  t 900 xcodebuild test-without-building -xctestrun "$(ls build/dd/Build/Products/*.xctestrun | head -n 1)" \
    -destination "id=$DEV" -retry-tests-on-failure -test-iterations 2 > shots/uitest.txt 2>&1 || { echo "::error::the touch tests failed"; RESULT=1; }
  grep -E "error:|Test Case .*(passed|failed)|TEST EXECUTE" shots/uitest.txt
else
  echo "touch tests skipped (TOUCH=0)" > shots/uitest.txt
fi
for f in shots/*-land-*.png; do W=$(sips -g pixelWidth "$f" | awk '/pixelWidth/{print $2}'); H=$(sips -g pixelHeight "$f" | awk '/pixelHeight/{print $2}'); [ "$W" -lt "$H" ] && sips -r 270 "$f" > /dev/null; done
for f in shots/*.png; do sips -Z 1100 "$f" > /dev/null; done
exit $RESULT

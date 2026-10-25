#!/usr/bin/env bash
# Generates App Store screenshots via XCUITest (scheme HeartsScoreboardScreenshots).
#
#   scripts/screenshots.sh [--devices iphone,iphone-6.3,ipad,duo-folded,duo-open]
#                          [--locales en,de] [--non-interactive]
#
# Devices (default: all):
#   iphone       iPhone 17 Pro Max (6.9")      -> screenshots/iOS 6.9          1320x2868
#   iphone-6.3   iPhone 17 Pro (6.3")          -> screenshots/iOS 6.3          1206x2622
#   ipad         iPad Pro 13-inch (M5)         -> screenshots/iPadOS 13        2064x2752
#   duo-folded   iPhone Duo, outer display     -> screenshots/iPhone Duo Folded 1398x2034
#   duo-open     iPhone Duo, inner display     -> screenshots/iPhone Duo Open   2007x2853
#                (needs a human to unfold the Duo in DeviceHub; skipped with --non-interactive)
# Locales other than "en" are saved under screenshots/<locale>/<folder>/.
# Simulators are dedicated "HS Screenshots ..." devices (created if missing): Duo on iOS 27.1, others on iOS 27.0
# (the 27.1 runtime only supports the Duo device type).
# Output PNGs are re-encoded without an alpha channel (App Store requirement).
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# The iOS 27.1 runtime currently supports only the iPhone Duo device type; everything else runs on iOS 27.0.
RUNTIME_DUO="com.apple.CoreSimulator.SimRuntime.iOS-27-1"
RUNTIME_STD="com.apple.CoreSimulator.SimRuntime.iOS-27-0"
SCHEME="HeartsScoreboardScreenshots"
SCENES=("1 - Main" "2 - Round Input" "3 - Game Summary" "4 - Settings" "5 - Dark")
WORK="${TMPDIR:-/tmp}/hs-screenshots"

DEVICES="iphone,iphone-6.3,ipad,duo-folded,duo-open"
LOCALES="en"
INTERACTIVE=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --devices) DEVICES="$2"; shift 2 ;;
    --locales) LOCALES="$2"; shift 2 ;;
    --non-interactive) INTERACTIVE=0; shift ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

die() { echo "ERROR: $*" >&2; exit 1; }

# device key -> "<simulator name>|<device type id>|<folder>|<width>x<height>"
spec() {
  case "$1" in
    iphone)     echo "HS Screenshots iPhone 17 Pro Max|com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max|iOS 6.9|1320x2868" ;;
    iphone-6.3) echo "HS Screenshots iPhone 17 Pro|com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro|iOS 6.3|1206x2622" ;;
    ipad)       echo "HS Screenshots iPad Pro 13|com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB|iPadOS 13|2064x2752" ;;
    duo-folded) echo "HS Screenshots iPhone Duo|com.apple.CoreSimulator.SimDeviceType.iPhone-Duo|iPhone Duo Folded|1398x2034" ;;
    duo-open)   echo "HS Screenshots iPhone Duo|com.apple.CoreSimulator.SimDeviceType.iPhone-Duo|iPhone Duo Open|2007x2853" ;;
    *) die "unknown device '$1' (use iphone, iphone-6.3, ipad, duo-folded, duo-open)" ;;
  esac
}

# Finds (or creates) the simulator with this name on the 27.1 runtime; prints its UDID.
ensure_sim() {
  local name="$1" type="$2" RUNTIME="$3" udid
  udid="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name, runtime = sys.argv[1], sys.argv[2]
for d in json.load(sys.stdin)["devices"].get(runtime, []):
    if d["name"] == name:
        print(d["udid"]); break
' "$name" "$RUNTIME")"
  if [[ -z "$udid" ]]; then
    udid="$(xcrun simctl create "$name" "$type" "$RUNTIME")" || die "could not create simulator '$name' (is the runtime installed?)"
    echo "Created simulator '$name' ($udid)" >&2
  fi
  echo "$udid"
}

# Re-encodes a PNG without alpha, then verifies.
strip_alpha() {
  local f="$1"
  if [[ "$(sips -g hasAlpha "$f" | awk '/hasAlpha/ {print $2}')" == "yes" ]]; then
    swift "$ROOT/scripts/strip_alpha.swift" "$f" || die "failed to strip alpha from $f"
  fi
  [[ "$(sips -g hasAlpha "$f" | awk '/hasAlpha/ {print $2}')" == "no" ]] || die "$f still has an alpha channel"
}

capture() {
  local key="$1" locale="$2" udid="$3" folder="$4" size="$5"
  local bundle="$WORK/$key-$locale.xcresult" out="$WORK/$key-$locale-attachments"
  rm -rf "$bundle" "$out"; mkdir -p "$out"

  echo "==> [$key/$locale] running screenshot tests"
  TEST_RUNNER_SCREENSHOT_LOCALE="$([[ "$locale" == en ]] && echo "" || echo "$locale")" \
  xcodebuild test -project HeartsScoreboard.xcodeproj -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$udid" \
    -resultBundlePath "$bundle" -quiet >"$WORK/$key-$locale.log" 2>&1 \
    || { tail -40 "$WORK/$key-$locale.log" >&2; die "xcodebuild failed for $key (log: $WORK/$key-$locale.log)"; }

  xcrun xcresulttool export attachments --path "$bundle" --output-path "$out" >/dev/null

  local dest="$ROOT/screenshots"
  [[ "$locale" == en ]] || dest="$dest/$locale"
  dest="$dest/$folder"; mkdir -p "$dest"

  python3 - "$out" "$dest" "${SCENES[@]}" <<'PY'
import json, shutil, sys, os, re
out, dest, *scenes = sys.argv[1:]
manifest = json.load(open(os.path.join(out, "manifest.json")))
found = {}
for test in manifest:
    for a in test.get("attachments", []):
        human = a.get("suggestedHumanReadableName", "")
        for s in scenes:
            if human == s or human.startswith(s + "_"):
                found[s] = a["exportedFileName"]
missing = [s for s in scenes if s not in found]
if missing:
    sys.exit("missing attachments: %s" % missing)
for s, f in found.items():
    shutil.copyfile(os.path.join(out, f), os.path.join(dest, s + ".png"))
PY

  local scene w h
  for scene in "${SCENES[@]}"; do
    local f="$dest/$scene.png"
    strip_alpha "$f"
    w="$(sips -g pixelWidth "$f" | awk '/pixelWidth/ {print $2}')"
    h="$(sips -g pixelHeight "$f" | awk '/pixelHeight/ {print $2}')"
    [[ "${w}x${h}" == "$size" ]] || die "$f is ${w}x${h}, expected $size"
  done
  echo "    saved 5 screenshots ($size) to ${dest#$ROOT/}"
}

mkdir -p "$WORK"
IFS=',' read -r -a DEVICE_LIST <<<"$DEVICES"
IFS=',' read -r -a LOCALE_LIST <<<"$LOCALES"

for key in "${DEVICE_LIST[@]}"; do
  IFS='|' read -r name type folder size <<<"$(spec "$key")"
  if [[ "$key" == duo-open && $INTERACTIVE -eq 0 ]]; then
    echo "WARNING: skipping duo-open (needs a human to unfold the Duo; rerun without --non-interactive)" >&2
    continue
  fi
  runtime="$RUNTIME_STD"; [[ "$type" == *Duo ]] && runtime="$RUNTIME_DUO"
  udid="$(ensure_sim "$name" "$type" "$runtime")"
  echo "==> $key: $name ($udid)"
  if [[ "$key" == duo-open ]]; then
    # DeviceHub can only show (and unfold) a simulator it booted itself; a
    # headless `simctl boot` makes its Start fail with "current state: Booted".
    # So only shut down a Duo this run booted (duo-folded); leave one the user
    # already started in DeviceHub alone.
    if [[ "${headless_booted:-}" == *"$udid"* ]]; then
      xcrun simctl shutdown "$udid" 2>/dev/null || true
    fi
    echo
    echo ">>> In DeviceHub, start '$name' (if not already running), unfold it, then press Enter."
    read -r _
  else
    xcrun simctl boot "$udid" 2>/dev/null && headless_booted="${headless_booted:-} $udid" || true
  fi
  xcrun simctl bootstatus "$udid" -b >/dev/null
  # Fixed local 9:41 on a fixed date so iPad's status-bar date is stable too.
  # simctl only accepts ISO strings with fractional seconds, in UTC.
  sb_time="$(date -u -r "$(date -j -f '%Y-%m-%d %H:%M' '2026-01-13 09:41' +%s)" +%Y-%m-%dT%H:%M:%S.000Z)"
  xcrun simctl status_bar "$udid" override --time "$sb_time" --dataNetwork wifi --wifiBars 3 \
    --cellularBars 4 --batteryState charged --batteryLevel 100
  open -g -a Simulator >/dev/null 2>&1 || true

  for locale in "${LOCALE_LIST[@]}"; do
    capture "$key" "$locale" "$udid" "$folder" "$size"
  done
done
echo "Done."

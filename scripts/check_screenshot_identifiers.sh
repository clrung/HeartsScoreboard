#!/usr/bin/env bash
# Fast static check: every accessibility identifier that the screenshot UI tests
# look up (app.buttons["..."], app.descendants(matching: .any)["..."], ...) must
# still be set via .accessibilityIdentifier(...) somewhere in the app sources.
# Interpolated identifiers on either side are handled: the app's
# "roundInput.quick.\(player.name)" matches the test's "roundInput.quick.Ava",
# and a test id like "row.\(i)" matches by its literal prefix.
#
#   scripts/check_screenshot_identifiers.sh [repo-root]   (default: this repo)
#
# Exits 1 and lists the missing identifiers if any are not found.
set -euo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
TESTS="$ROOT/HeartsScoreboardUITests/ScreenshotTests.swift"
APP="$ROOT/HeartsScoreboard"
[[ -f "$TESTS" ]] || { echo "ERROR: $TESTS not found" >&2; exit 2; }
[[ -d "$APP" ]] || { echo "ERROR: $APP not found" >&2; exit 2; }

python3 -I - "$TESTS" "$APP" <<'PY'
import os, re, sys
tests, app = sys.argv[1:]

# Identifiers used by the tests: string literals in a subscript, e.g. buttons["x"].
test_src = open(tests, encoding="utf-8").read()
test_ids = sorted(set(re.findall(r'\[\s*"((?:[^"\\]|\\.)*)"\s*\]', test_src)))
# Ignore dictionary lookups such as environment["SCREENSHOT_LOCALE"].
test_ids = [t for t in test_ids if not re.fullmatch(r'[A-Z][A-Z0-9_]+', t)]
if not test_ids:
    sys.exit("ERROR: found no identifiers in %s (extraction broken?)" % tests)

# Identifiers set by the app.
app_ids = []
for d, _, files in os.walk(app):
    for f in files:
        if f.endswith(".swift"):
            src = open(os.path.join(d, f), encoding="utf-8").read()
            app_ids += re.findall(r'\.accessibilityIdentifier\(\s*"((?:[^"\\]|\\.)*)"\s*\)', src)

interp = re.compile(r'\\\((?:[^()]|\([^()]*\))*\)')
def _split(s):
    # alternate literal / interpolation pieces
    out, pos = [], 0
    for m in interp.finditer(s):
        out += [s[pos:m.start()], "I"]; pos = m.end()
    out.append(s[pos:])
    return out
def pattern(s):
    return re.compile("".join(".+" if p == "I" and i % 2 else re.escape(p)
                              for i, p in enumerate(_split(s))) + r"\Z")

app_patterns = [pattern(a) for a in app_ids]
missing = []
for t in test_ids:
    if interp.search(t):
        prefix = t[:interp.search(t).start()]
        ok = any(a.startswith(prefix) or prefix.startswith(a.split("\\(")[0]) for a in app_ids)
    else:
        ok = any(p.match(t) for p in app_patterns)
    if not ok:
        missing.append(t)
if missing:
    print("ERROR: screenshot tests use accessibility identifiers that the app no longer sets:", file=sys.stderr)
    for m in missing:
        print("  - " + m, file=sys.stderr)
    print("Fix the rename (or update HeartsScoreboardUITests/ScreenshotTests.swift).", file=sys.stderr)
    sys.exit(1)
print("OK: all %d screenshot-test identifiers exist in the app (%d identifiers scanned)." % (len(test_ids), len(app_ids)))
PY

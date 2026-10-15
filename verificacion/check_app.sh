#!/usr/bin/env bash
# Static verification of the Flutter app on a machine without the Flutter SDK.
#
#   Flutter does not publish an SDK for Linux ARM64, so `flutter analyze` and
#   `flutter test` cannot run here. This script instead:
#
#     1. copies app/lib and app/test into a harness package whose dependencies
#        are REAL http/intl (from pub.dev) plus small path stubs for the
#        Flutter-only packages (flutter/foundation, shared_preferences,
#        flutter_test);
#     2. runs `dart analyze --format=json` over the copy;
#     3. splits the diagnostics into:
#          - syntax errors          -> must be 0
#          - errors in the non-UI layer (config, models, utils, services, state
#            and the tests) -> must be 0 (these files only import real or
#            stubbed packages, so their types are fully resolved)
#          - cascades in screens/, widgets/, theme/, main.dart, caused by the
#            unresolved package:flutter/material.dart -> expected here
#
# Usage: verificacion/check_app.sh [--quiet]
set -uo pipefail

ROOT=/opt/data/workspace/tp-electiva2
DART="$ROOT/.dart-sdk/dart-sdk/bin/dart"
APP="$ROOT/app"
HARNESS="$ROOT/verificacion/app_static_check"
OUT="${1:-/tmp/app_analyze.json}"

echo "== dart --version =="
"$DART" --version

echo
echo "== syncing app/ into the harness =="
rm -rf "$HARNESS/lib" "$HARNESS/test"
cp -r "$APP/lib" "$HARNESS/lib"
cp -r "$APP/test" "$HARNESS/test"
find "$HARNESS/lib" "$HARNESS/test" -name '*.dart' | wc -l | xargs echo "dart files copied:"

echo
echo "== dart pub get (harness) =="
(cd "$HARNESS" && "$DART" pub get >/tmp/harness_pub_get.log 2>&1) || {
  echo "pub get failed"; tail -20 /tmp/harness_pub_get.log; exit 1;
}
grep -E '^\+ (http|intl)' /tmp/harness_pub_get.log || true

echo
echo "== dart analyze --format=json =="
(cd "$HARNESS" && "$DART" analyze --format=json . >"$OUT" 2>/tmp/harness_analyze.err)
echo "raw diagnostics written to $OUT"

python3 "$ROOT/verificacion/report_analyze.py" "$OUT"

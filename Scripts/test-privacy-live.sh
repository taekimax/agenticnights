#!/bin/zsh
# Explicitly opt-in: briefly blacks out and dims physical displays.
set -euo pipefail
project_root="${0:A:h:h}"
mkdir -p "$project_root/.build/tests" "$project_root/.build/ModuleCache"
xcrun swiftc -swift-version 5 -num-threads 2 \
  -module-cache-path "$project_root/.build/ModuleCache" \
  "$project_root/Sources/DisplayBlackout.swift" "$project_root/Sources/DisplayBrightness.swift" \
  "$project_root/Sources/KeyboardBacklight.swift" \
  "$project_root/Sources/PhysicalClickMonitor.swift" "$project_root/Sources/PrivacyLockController.swift" \
  "$project_root/Tests/PrivacyLiveTests.swift" \
  -framework AppKit -framework LocalAuthentication \
  -o "$project_root/.build/tests/privacy-live-tests"
output="${1:-$project_root/.build/privacy-live}"
if (( $# > 0 )); then shift; fi
"$project_root/.build/tests/privacy-live-tests" "$output" "$project_root/Resources/Translations/ko.json" "$@"

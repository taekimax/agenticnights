#!/bin/zsh
# Explicitly opt-in: briefly blanks physical displays and blocks physical input.
set -euo pipefail
project_root="${0:A:h:h}"
mkdir -p "$project_root/.build/tests" "$project_root/.build/ModuleCache"
xcrun swiftc -swift-version 5 -num-threads 2 \
  -module-cache-path "$project_root/.build/ModuleCache" \
  "$project_root/Sources/DisplayBlackout.swift" "$project_root/Sources/PhysicalInputFilter.swift" \
  "$project_root/Sources/UnlockPassword.swift" "$project_root/Sources/PrivacyLockController.swift" \
  "$project_root/Sources/Shortcut.swift" "$project_root/Sources/GlobalShortcut.swift" "$project_root/Sources/Schedule.swift" \
  "$project_root/Sources/SettingsWindow.swift" \
  "$project_root/Tests/PrivacyLiveTests.swift" \
  -framework AppKit -framework Carbon -framework Security \
  -o "$project_root/.build/tests/privacy-live-tests"
"$project_root/.build/tests/privacy-live-tests" "${1:-$project_root/.build/privacy-live}" "$project_root/Resources/Translations/ko.json"

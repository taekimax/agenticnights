#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h}"
mkdir -p "$project_root/.build/tests" "$project_root/.build/ModuleCache"
xcrun swiftc -swift-version 5 -num-threads 2 \
  -target "$(uname -m)-apple-macosx13.0" \
  -module-cache-path "$project_root/.build/ModuleCache" \
  "$project_root/Sources/Shortcut.swift" "$project_root/Sources/GlobalShortcut.swift" \
  "$project_root/Sources/Localization.swift" \
  "$project_root/Tests/InteractionTests.swift" -framework AppKit -framework Carbon \
  -o "$project_root/.build/tests/interaction-tests"
"$project_root/.build/tests/interaction-tests"
xcrun swiftc -swift-version 5 -num-threads 2 \
  -module-cache-path "$project_root/.build/ModuleCache" \
  "$project_root/Sources/SettingsWindow.swift" "$project_root/Sources/Schedule.swift" \
  "$project_root/Sources/Shortcut.swift" "$project_root/Sources/GlobalShortcut.swift" \
  "$project_root/Tests/SettingsWindowTests.swift" -framework AppKit -framework Carbon \
  -o "$project_root/.build/tests/settings-window-tests"
"$project_root/.build/tests/settings-window-tests" "$project_root/Resources/Translations"

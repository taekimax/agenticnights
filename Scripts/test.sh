#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h}"
mkdir -p "$project_root/.build/tests" "$project_root/.build/ModuleCache"
xcrun swiftc -swift-version 5 -num-threads 2 \
  -module-cache-path "$project_root/.build/ModuleCache" \
  "$project_root/Sources/Shortcut.swift" "$project_root/Sources/Schedule.swift" "$project_root/Sources/UserActivity.swift" "$project_root/Tests/ScheduleTests.swift" \
  -o "$project_root/.build/tests/schedule-tests"
"$project_root/.build/tests/schedule-tests"
xcrun swiftc -swift-version 5 -num-threads 2 \
  -module-cache-path "$project_root/.build/ModuleCache" \
  "$project_root/Sources/Localization.swift" "$project_root/Tests/LocalizationTests.swift" \
  -o "$project_root/.build/tests/localization-tests"
"$project_root/.build/tests/localization-tests" "$project_root/Resources/Translations"
xcrun swiftc -swift-version 5 -num-threads 2 \
  -module-cache-path "$project_root/.build/ModuleCache" \
  "$project_root/Sources/UnlockPassword.swift" "$project_root/Tests/UnlockPasswordTests.swift" \
  -framework Security -o "$project_root/.build/tests/unlock-password-tests"
"$project_root/.build/tests/unlock-password-tests"

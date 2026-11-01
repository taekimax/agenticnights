#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h}"
mkdir -p "$project_root/.build/tests" "$project_root/.build/ModuleCache"
compile=(xcrun swiftc -swift-version 5 -num-threads 2 -module-cache-path "$project_root/.build/ModuleCache")
"${compile[@]}" "$project_root/Sources/Shortcut.swift" "$project_root/Sources/Schedule.swift" "$project_root/Sources/UserActivity.swift" "$project_root/Sources/SleepPrevention.swift" "$project_root/Tests/ScheduleTests.swift" -o "$project_root/.build/tests/schedule-tests"
"$project_root/.build/tests/schedule-tests"
"${compile[@]}" "$project_root/Sources/Localization.swift" "$project_root/Tests/LocalizationTests.swift" -o "$project_root/.build/tests/localization-tests"
"$project_root/.build/tests/localization-tests" "$project_root/Resources/Translations"
"${compile[@]}" "$project_root/Sources/DisplayBrightness.swift" "$project_root/Tests/DisplayBrightnessTests.swift" -o "$project_root/.build/tests/display-brightness-tests"
"$project_root/.build/tests/display-brightness-tests"
"${compile[@]}" "$project_root/Sources/DisplayBlackout.swift" "$project_root/Sources/PhysicalClickMonitor.swift" "$project_root/Tests/PhysicalClickTests.swift" -framework AppKit -o "$project_root/.build/tests/physical-click-tests"
"$project_root/.build/tests/physical-click-tests"

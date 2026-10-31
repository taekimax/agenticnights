# Development

User instructions: [README](README.md). The app uses Swift and AppKit, targets macOS 13+, and has no external package dependencies.

## Build and verify

Run from the repository root with Xcode Command Line Tools installed. Build and test scripts use two compiler threads. Builds target the current Mac’s architecture and use a local ad-hoc signature.

| Command | Scope |
| --- | --- |
| `./Scripts/test.sh` | 33 schedule/settings/input-timing tests and 10 localization tests |
| `./Scripts/test-interactions.sh` | 2 tests using in-process AppKit events and Carbon shortcut registration |
| `./Scripts/build.sh` | Compile `.build/agenticnights.app` and verify its signature |
| `./Scripts/install.sh` | Quit the installed app, retain it in Trash, copy the build, verify signature and full payload equality |
| `open /Applications/agenticnights.app` | Launch the installed bundle |

Build output and tests stay in Git-ignored `.build/`. Preserve existing changes before updating a checkout; use SSH for authenticated Git operations.

Automated tests cover five-minute input resets, continued use, already-idle launch, wake/session time caps, separate schedules, pending and persisted stop deadlines, settings migration, and translations. Synthetic events do not prove physical mouse/keyboard/trackpad behavior. Check physical input, menus, shortcut capture, multiple displays, and actual sleep separately. Report build, installation, launch, automated tests, and live behavior as separate outcomes.

## Code and timing

| File | Responsibility |
| --- | --- |
| [UserActivity.swift](Sources/UserActivity.swift) | Read elapsed input time; exclude elapsed sleep/inactive-session time after resume |
| [Schedule.swift](Sources/Schedule.swift) | Shared idle threshold, blackout scheduling, settings persistence model, awake deadline |
| [main.swift](Sources/main.swift) | One-second polling, settings/menu integration, session notifications, status output |
| [CoverController.swift](Sources/CoverController.swift) | Black windows and input dismissal |
| [SleepPrevention.swift](Sources/SleepPrevention.swift) | Own and stop the app’s `caffeinate -di -w <pid>` child |
| [Localization.swift](Sources/Localization.swift) | Bundled and user-editable translations |

Both automatic features require the shared idle delay, even if only one is enabled. The existing `intervalMinutes` setting stores that delay. Launch and daily schedule entry use elapsed time since the last input; wake and session resume cap it to time since resumption. Invalid idle readings act as recent input. Polling can delay activation or release by about one second.

Manual blackout and its shortcut operate immediately. A completed blackout also delays another automatic blackout by at least the configured interval. Automatic starts are suppressed while Settings or a menu is open. Feature schedules use local time with an inclusive start and exclusive end; equal endpoints mean all day.

`AwakeSettings.update` requires an explicit `idleReady` decision. The optional stop deadline starts on first eligible idle activation and is persisted. Input releases the assertion but preserves that deadline. Expiry disables the feature, including during resumed use or outside scheduled hours; an expired deadline is consumed on relaunch. Changing the timer or toggling the feature restarts its deadline at the next eligible activation. Changes to other controls preserve it.

## Data and translations

- Settings: JSON under `settings` in UserDefaults domain `com.tk.agenticnights`.
- Editable catalogs: `~/Library/Application Support/agenticnights/Translations/`.
- Status: `~/Library/Application Support/agenticnights/status.json`. It includes settings, current idle eligibility, process IDs, display geometry, and language diagnostics. It stores no screen content or keystrokes. Verify `running`, PID, and bundle path because the file remains after exit.

English is the source catalog. Missing or invalid translated values use the selected bundled language, then English. Keep keys and placeholder sets aligned. Legacy exported defaults can adopt new wording without rewriting user files; custom translations remain intact. Translation files are read at launch.

## Input detection references

Reviewed 2026-10-31. These sources inform the design; their behavior is not a substitute for testing this app.

| Source | Implementation | Decision for agenticnights |
| --- | --- | --- |
| [Chromium](https://github.com/chromium/chromium/blob/main/ui/base/idle/idle_mac.mm) | Quartz elapsed-input query with combined login-session state and all input types | Use the same session scope and returned fractional seconds |
| [ActivityWatch](https://github.com/ActivityWatch/aw-watcher-afk/blob/master/aw_watcher_afk/macos.py) | Quartz elapsed-input query with HID-system state | Useful alternative for hardware-source scope; broader session input is appropriate here |
| [Hammerspoon](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/host/libhost.m) | Read `IOHIDSystem/HIDIdleTime` through IOKit | Avoid extra registry access, type handling, resource ownership, and approximate unit conversion |
| [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake/blob/main/Packages/KYASleepWakeTimer/Sources/KYASleepWakeTimer/KYASleepWakeTimer.m) | Manage a `caffeinate` process and activation duration | Reference for sleep-prevention process lifetime; it does not supply this idle-detection algorithm |

[Apple’s state definitions](https://developer.apple.com/documentation/coregraphics/cgeventsourcestateid) distinguish combined login-session sources from HID sources. The app reads elapsed time without installing a global event tap or collecting input contents. Automated and remote input may update different state tables depending on how it is posted; do not claim that all automated input is excluded.

Keep [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) in distributions. The build copies both into the app bundle.

# Development

Swift / AppKit, macOS 13+, no package dependencies. Version 2.1.1 (build 17). [User guide](README.md).

## Build and delivery

| Command | Purpose |
| --- | --- |
| `./Scripts/build.sh` | Build and ad-hoc sign `.build/agenticnights.app`; two compiler threads |
| `./Scripts/install.sh` | Quit the installed app, retain it in Trash, install and compare payloads |
| `open /Applications/agenticnights.app` | Launch the installed app |
| `./Scripts/test.sh` | Schedule/settings migration, localization, simulated brightness and click classification checks |
| `./Scripts/test-interactions.sh` | Carbon shortcut registration and offscreen English/Korean Settings behavior/layout checks |
| `./Scripts/test-privacy-live.sh [output-directory]` | Opt-in real gamma/backlight lifecycle checks |
| `./Scripts/test-privacy-live.sh [output-directory] --authentication` | Open real macOS authentication; requires a human to authenticate or cancel |

Keep generated output in `.build/`. Preserve settings, translations and useful evidence. Use SSH for authenticated Git operations. The installed app root must remain owner-writable; do not change payload permissions recursively. Build, signing, installation, launch and live behavior require separate evidence. See the [current delivery record](docs/no-permission-delivery-2026-11-02.md) for PASS, FAIL and NOT RUN results; commands listed here are instructions, not a claim they were run.

The build packages `Resources/Brand/agenticnights-moon-transparent-v1.png` into `AppIcon.icns` with `Scripts/build-icon.sh`. Source artwork and generation/cleanup records remain in `Resources/Brand/`.

## Ownership

All files below are under `Sources/`.

| File | Responsibility |
| --- | --- |
| `DisplayBlackout.swift` | Save full gamma ramps, blacken connected displays, restore originals |
| `DisplayBrightness.swift` | Optional DisplayServices loading, supported-display brightness capture/dimming/restoration; injectable test backend |
| `PhysicalClickMonitor.swift` | Global and local AppKit mouse-down monitors; source-state 1 classification; pass events through |
| `PrivacyLockController.swift` | Blackout lifecycle, system authentication, temporary black backdrops, VoiceOver observation and macOS lock request |
| `UserActivity.swift` | Physical-input idle duration, capped after wake/session return |
| `Schedule.swift` | Settings decoding/migration, inactivity deadline and independent sleep-prevention deadline |
| `SleepPrevention.swift` | Own `caffeinate -di` or `-i`, bounded by parent PID and optional remaining duration |
| `Shortcut.swift` | Shortcut representation, validation and display |
| `GlobalShortcut.swift` | Carbon shortcut registration and replacement |
| `SettingsWindow.swift` | Four-section settings window; immediate valid edits and minute-field validation |
| `LaunchAtLogin.swift` | `SMAppService.mainApp` login-item registration; macOS owns the state |
| `main.swift` | Menu, icon actions, system notifications, one-shot deadlines, settings persistence and changed-state status output |
| `LegacyPasswordCleanup.swift` | One-time removal of the retired credential through the system utility |
| `Localization.swift` | Bundled English/Korean, language selection, validated user overrides and old-default recognition |

## Behavior

Gamma is the normal blackout mechanism. Global and local mouse monitors run only during active blackout and observe left/right/other button presses. Both monitors are intentional: global monitoring covers other apps, while local monitoring covers this app. Events pass through unchanged. Hardware source-state 1 requests dismissal; normal session/private-source automation does not. Movement, scrolling and keyboard events are not monitored for dismissal. The first click and all keyboard input reach the front app.

Automatic blackout uses HID idle time and a one-shot timer for the remaining quiet interval. Input before the deadline causes recalculation when it fires. Wake, session return, settings changes and menu closure recalculate the wait. Settings and open menus suppress automatic blackout. No one-second polling loop remains. Display configuration changes reapply gamma and brightness immediately, then after 5 and 10 seconds; pending callbacks are cancelled during suspension or authentication.

`LocalAuthentication` uses `.deviceOwnerAuthentication`, allowing Touch ID or the Mac login password. Non-key, mouse-transparent black windows are installed before restoring gamma/backlight for the system dialog. Success ends blackout. Cancellation, failure, switching to another app or display reconfiguration invalidates the context and reapplies blackout. Apple system authentication agents are allowed to take focus. The previously active app is restored afterward. Dialog ordering and focus behavior still require real-device checks.

While blackout is active, enabling VoiceOver requests `SACLockScreenImmediate`. Sleep, login lock and inactive sessions suspend blackout, restore display output and preserve intent for return. Ordinary Quit, Cmd-Q and SIGTERM require authentication when protected blackout is active; system shutdown/logout may proceed. Force termination remains outside this lifecycle.

Sleep prevention is independent of blackout and authentication. It owns one `caffeinate` process: `-di` with Keep Display On, otherwise `-i`, plus `-w <app-pid>` and optional `-t <remaining-seconds>`. Duration changes restart the deadline; input and relaunch do not. A display-option change preserves the deadline. Expiry disables prevention and returns control to macOS. No daily hours or persistent power-setting changes are used.

Open at login registers the app bundle with `SMAppService.mainApp`. The state is read from macOS each time Settings refreshes or becomes key, so approval or removal in System Settings › Login Items is reflected; it is not stored in `VeilSettings`. `status.json` records it as `launchAtLogin` (`enabled`, `disabled`, `requiresApproval`, `unavailable`).

Settings apply immediately. Minute fields commit on Return or focus departure; invalid values preserve the previous setting. A failed shortcut registration preserves the prior shortcut. Turning Require Authentication off needs a separate `.deviceOwnerAuthentication` prompt; the checkbox keeps its value until that prompt succeeds. An account without a login password can turn it off directly. Every other setting, including sleep controls, changes without authentication. Enabling the option is refused when macOS cannot authenticate the account.

## Data and migration

- Settings: JSON under `settings` in UserDefaults domain `com.tk.agenticnights`.
- Translations: `~/Library/Application Support/agenticnights/Translations/`.
- Status: `~/Library/Application Support/agenticnights/status.json`; check `running`, PID and `bundlePath` before relying on it.

Old `passwordProtection` becomes `requireAuthentication`. `LegacyPasswordCleanup` removes the retired `com.tk.agenticnights.unlock` / `privacy-cover-password` entry through `/usr/bin/security`; `legacyPasswordRemoved` is recorded only after removal or confirmation that the item is absent. The app stores no new authentication secret. Old sleep settings default Keep Display On to true. Icon values `both`/`cover` become `blackOut`, and `awake` becomes `toggleSleep`. Obsolete schedules and movement-dismissal fields are discarded on encoding.

English defines translation keys and tokens. Both active catalogs contain the plan wording plus existing Edit-menu and shortcut-editor strings. Invalid overrides fall back to the selected bundled language, then English. `legacy-v1.2.json` through `legacy-v1.5.json` recognize previously exported defaults without rewriting user files. Historical catalogs intentionally retain retired wording as migration data; they are not exported as selectable languages.

Status records blackout/authentication state, settings, localization warnings and the owned caffeinate PID. It does not record credentials, keystrokes or screenshots. Identical status payloads are not rewritten.

## References and verification

[Curtain](https://github.com/acamarata/curtain/tree/0b2295fc15f5a0e3f2ad8ffd36684f8d7c4809a8) informs gamma blackout, event-source classification, temporary non-key backdrops and macOS lock requests. [RustDesk](https://github.com/rustdesk/rustdesk/blob/3b7e2cebd9303a43eecb9bc96921548df846f45d/src/platform/macos.mm) informs display-reconfiguration-triggered gamma refresh. Original gamma ramps are preserved. No RustDesk code is incorporated.

[KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake/blob/2be93dd7f390b23fbca934ff3b1ac03468a80077/Packages/KYASleepWakeTimer/Sources/KYASleepWakeTimer/KYASleepWakeTimer.m) informs the parent-bounded caffeinate process and finite-duration timeout.

The [2.0 delivery record](docs/no-permission-delivery-2026-11-02.md) owns current evidence and pending checks. Pure click classification and injected brightness tests cannot establish physical click delivery, panel appearance or brightness restoration on hardware. The opt-in live harness reads real gamma ramps and can request system authentication; it does not establish every human scenario. Touch ID and password separately, cancellation/Cmd-Tab, VoiceOver lock, protected quit paths, monitor hot-plug, real brightness restoration, agent capture/input compatibility, both UI languages and power comparisons require individually recorded results. DisplayLink is unsupported. `Experiments/PrivacyProbe` remains historical evidence rather than a current product path.

Distribute [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) with the app.

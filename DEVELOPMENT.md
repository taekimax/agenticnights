# Development

Swift / AppKit, macOS 13+, no package dependencies. [User guide](README.md).

## Build and delivery

| Command | Purpose |
| --- | --- |
| `./Scripts/build.sh` | Build and ad-hoc sign `.build/agenticnights.app`; two compiler threads |
| `./Scripts/install.sh` | Quit the installed app, retain it in Trash, install and compare all payloads |
| `open /Applications/agenticnights.app` | Launch the installed app |
| `./Scripts/test.sh` | Existing schedule, localization and memory password checks |
| `./Scripts/test-interactions.sh` | Carbon shortcut registration checks |
| `./Scripts/test-privacy-live.sh` | Opt-in gamma/input experiment; temporarily blocks desk input |

Keep generated output in `.build/`. Preserve user settings, translations and useful evidence. Use SSH for authenticated Git operations. The installed app root must remain owner-writable; do not change payload permissions recursively.

## Ownership

| File | Responsibility |
| --- | --- |
| `DisplayBlackout.swift` | Read full gamma ramps, blacken connected displays, restore originals |
| `PhysicalInputFilter.swift` | HID event tap on a dedicated run loop; discard desk input, allow other sources |
| `PrivacyLockController.swift` | Shared blackout lifecycle, optional authentication, prompt animation and retry limits |
| `UnlockPassword.swift` | Keychain verifier, PBKDF2-SHA256 and constant-time comparison |
| `UserActivity.swift` | HID idle duration, capped after wake/session return |
| `Schedule.swift` | Blackout delay, independent daily hours, persisted awake timer |
| `SleepPrevention.swift` | Own `caffeinate -di -w <app-pid>` and release it on stop |
| `main.swift` | Menus, settings, system notifications, one-second updates and status |
| `Localization.swift` | Bundled text and user translation overrides |

The old `CoverController` and menu-bar hiding preference are removed. Gamma is the only blackout mechanism. Opaque windows exist only while displaying the password prompt.

## Behavior

Blackout waits for physical inactivity. It is suppressed while Settings or a menu is open. Both automatic and manual blackout use the same controller. Ordinary mode consumes the physical key/click that dismisses it; mouse movement dismissal is optional. Synthetic agent input and app activation leave blackout in place.

Sleep prevention starts immediately when enabled within its scheduled hours. Input, menus and Settings do not stop it. Its optional deadline starts at activation and survives restart; expiry disables the feature. Password protection overrides its hours and timer until authenticated unlock. Manual macOS lock, sleep and inactive sessions release interception so login input remains usable.

Three wrong passwords cause a 60-second wait. Each subsequent failure doubles the wait to 120, 240 and 480 seconds. The seventh failure requires macOS login lock. Attempts during a wait are ignored. Escape and prompt timeout retain failure state; only successful app authentication or, after escalation, an observed macOS lock/unlock transition resets it. Failure to invoke macOS lock leaves input blocked and permits another lock request.

The prompt appears above the desktop before gamma is restored. Closing it reapplies gamma blackout before removing the windows. A 30 Hz timer, active only while the prompt is visible, moves one text group per display using phase-modulated sine waves. Smooth interpolation cycles a four-color metallic palette. There is no physics engine, shader or external asset.

The password uses a random 32-byte salt and PBKDF2-HMAC-SHA256 with 210,000 iterations. Keychain holds the verifier, not plaintext. Unlock reads cannot open an authorization dialog behind blackout. No default password is created. A shortcut conflict cannot partially commit a new password.

## Data

- Settings: JSON data under `settings` in UserDefaults domain `com.tk.agenticnights`.
- Keychain: service `com.tk.agenticnights.unlock`, account `privacy-cover-password`.
- Translations: `~/Library/Application Support/agenticnights/Translations/`.
- Status: `~/Library/Application Support/agenticnights/status.json`; inspect `running`, PID and `bundlePath` before using it.

Status records state, permission availability and the owned caffeinate PID; it contains no password, keystrokes or screenshots. English defines translation keys and placeholders. Recognized previously exported defaults use current bundled wording without rewriting custom files.

## References and verification

[Curtain](https://github.com/acamarata/curtain/tree/0b2295fc15f5a0e3f2ad8ffd36684f8d7c4809a8) informs gamma blackout, physical-source filtering and the non-key password prompt. [RustDesk](https://github.com/rustdesk/rustdesk/blob/3b7e2cebd9303a43eecb9bc96921548df846f45d/src/platform/macos.mm) informs the earlier HID interception point. Original ramps are preserved instead of resetting the ColorSync profile. No password-free emergency uncover is provided.

[KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake/blob/2be93dd7f390b23fbca934ff3b1ac03468a80077/Packages/KYASleepWakeTimer/Sources/KYASleepWakeTimer/KYASleepWakeTimer.m) informs the caffeinate process lifetime. Immediate activation closes the previous gap before the blackout delay. No simulated input, periodic user-activity declaration or persistent power-setting change is added. Screen-saver and automatic-login-lock suppression beyond `-di` remains unverified.

[Implementation record](docs/privacy-protection-2026-10-31.md) distinguishes earlier physical checks from current build and delivery checks. Per the 2026-11-01 request, this revision adds no separate tests and does not rerun behavior experiments. Earlier checks do not validate the new backoff or animation. Real Keychain, third-party agents, HDR/EDR workflows and failure-triggered macOS login lock remain separate checks. DisplayLink is unsupported.

Distribute [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) with the app.

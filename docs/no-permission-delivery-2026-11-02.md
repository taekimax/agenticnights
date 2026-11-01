# Permission-free blackout — 2.0.0 (build 14)

Implemented from the supplied v3 plan on 2026-11-01/02 (Asia/Seoul), starting at `227a7df`. The requested scope includes review, implementation, commit/push, recoverable installation, preferences and cleanup.

## Changes and review decisions

- Removed event interception, keyboard polling, the app-specific password, daily schedules and the one-second update loop.
- Added physical-click monitoring, macOS account authentication, VoiceOver-triggered login lock and supported-display brightness restoration.
- Sleep prevention has one switch, optional display wakefulness and one persisted deadline. It is independent of blackout/authentication and uses `caffeinate -i/-di -w <pid>` with an optional `-t`.
- Settings apply immediately. Invalid minutes and failed shortcut changes preserve valid state. Old preferences and customized translation files are retained through migration.
- The user approved adding a local mouse monitor because global monitoring excludes events delivered to this app. Both pass clicks through. An independent review found and fixed same-gesture reblackout when clicking the status icon: Core Graphics mouse event numbers pair the down/up events without a time heuristic. The user subsequently verified the icon flow.
- The user approved Astra in place of unavailable Opus for the designated design/review work. Bounded Sol work covered settings/sleep, brightness and translations. Root integration and final verification remained separate.

## Evidence

Local execution artifacts are under `.build/no-permission-20261101/` (not distributed). The table distinguishes automatic checks, live API checks, agent interaction and human observations.

| Check | Result | Evidence / scope |
| --- | --- | --- |
| Schedule, migration, duration and sleep arguments | PASS | `final-tests.log`: 16 cases |
| Translation keys/tokens, old-default migration and custom-file preservation | PASS | `final-tests.log`: 10 cases; custom bytes unchanged |
| Brightness lifecycle with fake devices | PASS | Repeated refresh, stable UUID reconnect, new/unsupported devices and restoration |
| Click classification | PASS | Hardware source 1 accepted; session/private/missing/unknown rejected |
| Carbon shortcut registration/replacement | PASS | `final-interactions.log` |
| Settings behavior/layout, offscreen | PASS | Both languages, 640/560 px widths; immediate changes, Return/blur validation, edited-text preservation and shortcut rejection |
| Build and ad-hoc signature | PASS | `build.log`; two compiler threads |
| Retired imported APIs | PASS | `undefined-symbols.txt`: no `_AXIsProcessTrusted`, `_CGEventTap*` or `_SecItem*` |
| Permission-free global mouse monitoring | PASS | LaunchServices-launched probe reports `trusted=false`; user's actual clicks have source 1 and increasing HID counts (`click-probe-independent.log`) |
| Agent clicks versus human clicks | PASS | During the user's explicit no-input interval, three computer-use clicks generated no probe callbacks and HID counts stayed `[9793, 128, 0]` (`click-probe-isolated-agent.log`, `counters-after-agent.txt`) |
| Real gamma lifecycle | PASS | `live-ordinary.log`: zero ramps, ordinary suspend/resume, refresh, exact original-ramp restoration |
| Installed ordinary blackout | PASS | User confirmed black physical panels, movement/Shift retaining blackout, click dismissal and brightness restoration |
| Installed agent input/capture during blackout | PASS | Computer-use click and readable Finder capture; `agent-click-during-blackout.json` still reports `covered=true` |
| Actual shortcut and same-icon dismissal | PASS | User verified two shortcut presses and two icon clicks; second icon click leaves blackout ended |
| Authentication dialog ordering and cancellation | PASS | User confirmed the real system dialog above black backdrops and blackout after Cancel |
| Touch ID and protected SIGTERM | PASS | User authenticated with Touch ID after SIGTERM; `sigterm-test.json` plus `live-transitions.jsonl` show protected active state, authentication and process exit |
| Cmd-Tab cancellation and Mac password | PASS | User repeated the sequence after an initially interrupted attempt and confirmed both; state transitions recorded |
| English and Korean visible UI | PASS | Actual installed Settings and menu trees/screenshots inspected; no clipped text observed |
| Invalid minutes in installed Settings | PASS | Entering 0 showed the error while status retained 10; restored displayed 10 |
| Real sleep assertions and expiry | PASS | `sleep-runner-real.log`: `-i` system only, `-di` system+display, replacements release prior assertions, unchanged config retains PID; `-w` plus `-t 3` expires in 3.26 s while parent lives |
| VoiceOver-triggered macOS lock | NOT RUN | User explicitly declined this remaining physical test |
| Physical monitor disconnect/reconnect | NOT RUN | User explicitly declined this remaining physical test; fake-device brightness test is separate |
| Protected Cmd-Q and menu Quit individually | NOT RUN | SIGTERM exercises the common termination delegate, but these UI entry points were not independently demonstrated |
| Real sleep/login/user-switch round trip | NOT RUN | Controller suspend/resume API check is not a physical session test |
| Full default 10-minute inactivity cycle | NOT RUN | Schedule logic and installed one-shot deadline checked; no uninterrupted ten-minute human idle trial |
| Korean macOS authentication sentence | NOT RUN | Both app languages displayed on this Mac; macOS system language itself was not changed |

The initial directly executed probe inherited its launcher's trust and was not used as evidence of permission-free operation. The successful independent probe was opened through LaunchServices and reported `trusted=false`.

The source text check intentionally permits AppKit `setAccessibilityLabel` calls, which label controls and do not request permission. Historical translation snapshots retain retired wording as required for migration. The legacy `passwordProtection` decoding key remains only to migrate existing settings.

## Power observations

`measure.py` records process CPU time across a measured 60-second interval and samples `top` IDLEW before/after. These are process observations, not battery or watt measurements.

| Installed version / state | Interval | CPU time | IDLEW increment |
| --- | ---: | ---: | ---: |
| 1.5.2, ordinary | 60.022 s | 0.39 s | 0 |
| 2.0.0, ordinary | 60.012 s | 0.00 s at 0.01 s reporting resolution | 0 |

Evidence: `baseline-60.json`, `baseline-60.top.txt`, `new-normal-60.json`, `new-normal-60.top.txt`. The earlier exploratory 61-sample recording took 80 seconds and is not presented as a 60-second measurement.

CPU use decreased in this sample. IDLEW did not distinguish the versions, so a reduction in wakeup count is **not established**. Old-version covered-state measurement was not established before replacement (its status retained a permission-related error). The new covered-state timing attempt ended when blackout was dismissed before sampling, so no covered-state 60-second comparison is claimed.

## Installation, preferences and recovery

- PASS: `Scripts/install.sh` retained the prior app in `~/.Trash/agenticnights-20261102-001014-552963.app`, copied `.build/agenticnights.app` to `/Applications/agenticnights.app`, verified its signature and compared the entire installed/staged payload (`install.log`).
- PASS: installed app launched; live checks above used that installed version. Current source Info.plist, translations and notices match its resources.
- PASS: final preferences retain automatic blackout after 10 minutes, sleep prevention on with no limit, Keep Display On on and the default shortcut. Old `both` becomes Black Out Now.
- PASS: per the user's explicit choice, Require Authentication is **off**. It was temporarily enabled only for the recorded authentication checks.
- PASS: temporary Korean selection was restored to the original `language.txt` bytes (`auto`). Existing translation files are preserved, including customized entries. No persistent power or OS permission setting was changed.
- PASS: `legacyPasswordRemoved=true` confirms successful system-utility cleanup or an already-absent retired item; no new app credential is stored.
- Settings/translation recovery copies and the current staged bundle remain under `.build/`. Obsolete task probes, retired test executables and generated icon intermediates are moved to timestamped Trash. Useful caches and prior evidence remain.
- The pre-existing untracked `docs/no-permission-plan-2026-11-01.html` is preserved and excluded from this change.

The commit containing this record is the delivered source revision. The final local delivery receipt records the verified remote revision and cleanup destinations; Git history and the final response identify the commit/push separately from installation.

## References

- [Apple: Monitoring Events](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html): local/global scopes and mouse versus key monitoring.
- [Apple: deviceOwnerAuthentication](https://developer.apple.com/documentation/localauthentication/lapolicy/deviceownerauthentication): system account authentication policy.
- [Apple: CGEventField](https://developer.apple.com/documentation/coregraphics/cgeventfield): paired mouse-event numbers.
- Source-specific attribution remains in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).

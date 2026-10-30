# agenticnights

[English](#english) · [한국어](#한국어)

## English

Keep your Mac awake and cover its displays with black windows at regular intervals.
agenticnights is a small macOS menu bar app with independent screen blackout and
sleep prevention controls, daily schedules, and an optional auto-stop timer.

**Version 1.3.0 · macOS 13 or later · English and Korean included · MIT license**

The interface follows your macOS language by default. You or an AI agent can add
other languages by editing translation files in app data, without rebuilding the app.

### Install from source

You need Git, Swift from the Xcode Command Line Tools, and `python3`. The full
Xcode app and third-party packages are not required. Build on an Apple Silicon or
Intel Mac for that Mac's architecture. Compilation is limited to two threads.

For a new checkout:

```sh
mkdir -p "$HOME/dev"
git clone https://github.com/taekimax/agenticnights.git "$HOME/dev/agenticnights"
cd "$HOME/dev/agenticnights"
./Scripts/test.sh
./Scripts/build.sh
./Scripts/install.sh
open /Applications/agenticnights.app
```

If the checkout already exists, inspect its Git status and preserve local changes
before updating it. Public source downloads do not require a GitHub login or API
key; use SSH for authenticated development work.

- Build output: `.build/agenticnights.app`.
- Installation: `/Applications/agenticnights.app`.
- The installer quits the existing app, moves it to
  `~/.Trash/agenticnights-<timestamp>.app`, and copies the replacement. It verifies
  the signatures and complete staged/installed file equality.
- Builds use a local ad-hoc signature. The app does not request network,
  Accessibility, or Screen Recording permissions.
- Settings open on first launch. Later, use the menu bar or open the app again
  from Applications to view them.

### Install with an AI agent

Give this prompt to an agent that can work locally on your Mac:

```text
Build, install, and launch agenticnights on this Mac from:
https://github.com/taekimax/agenticnights

Check for macOS 13 or later, Git, Xcode Command Line Tools with Swift, and python3.
If a tool installation or system consent needs my action, explain the exact step.
Clone into a suitable directory under my home folder; preserve existing work and
use a separate directory if necessary. Read README.md and Scripts first.

Run Scripts/test.sh, Scripts/build.sh, and Scripts/install.sh in order, then open
/Applications/agenticnights.app. Keep compilation limited to two threads. Follow
the installer's quit-and-backup procedure and preserve my settings and data.
Use the app defaults unless I have requested specific settings.

Verify the installed signature, staged/installed file equality, and actual running
app path. Check the moon menu, quick controls, mouse-movement option, shortcut
recording, saving, cancellation, and persistence after relaunch. Distinguish
in-process event tests from physical input checks. Restore settings changed for testing.
Distinguish the app's own caffeinate process from other sleep prevention tools.
If needed, use a bounded sleep assertion and stop only the one you started.

Complete the installation without changing credentials or security settings.
Do not change product code, commit, or push. Report the installed version/commit,
path, settings, running state, and checks. Mark checks you could not run as NOT RUN.
Remove temporary verification files; preserve recovery copies and useful caches.
```

### Use

Click the moon in the menu bar to open the controls and **Settings…**. Left-click,
right-click, and modifier-click all open the same menu. A filled moon means at
least one feature is enabled; the menu and tooltip show each feature's current
status. Upgrades preserve enabled features and other compatible settings; the old
click-action choice is no longer used.

| Menu control | Effect |
| --- | --- |
| Enable screen blackout / Keep Mac awake | Toggle either feature independently |
| Blackout interval | Choose 5, 10, 15, 30, or 60 minutes; Custom interval opens Settings |
| Restore screen on mouse movement | Turn movement dismissal on or off |
| Auto-stop keep awake | Choose Until turned off, or 30, 60, or 120 minutes; does not turn Keep awake on or off |
| Black out now / Restore screen | Show or dismiss the black windows |
| Shortcut / Settings… | Open Settings to edit the shortcut, custom durations, and daily schedules |

- **Screen blackout** starts enabled, with a 10-minute interval and no daily
  time restriction. The first blackout appears after one full interval. A manual
  blackout restarts the interval while automatic blackout is active.
- **Keep awake** independently prevents automatic system and display sleep. It
  starts enabled, with no timer or daily time restriction. The optional auto-stop
  timer accepts 1–1440 minutes and starts when sleep prevention becomes active.
  It keeps counting outside scheduled hours and while the app is closed. Expiry
  turns Keep awake off. Relaunching, waking the Mac, or changing blackout settings
  does not extend the deadline. Turning Keep awake off and on, changing the timer
  duration, or toggling timer use starts a new timer when active.
- Moving the mouse or trackpad restores the screen by default. Disable **Restore
  screen on mouse movement** in the menu or Settings to keep the blackout until
  you click, press a key, use the shortcut, or switch apps. The dismissing key is
  not sent to the previous app. This option controls the app's black windows;
  waking from actual system or display sleep remains macOS behavior.
- **Control+Option+Command+B** is the default global blackout shortcut. In Settings,
  click **Change…** and press a combination containing Command, Option, or Control
  with A–Z, 0–9, or F1–F20; Shift is optional. Shortcuts use physical key positions
  labeled with the US keyboard layout. Press Escape to cancel recording. **Use
  default** restores the default combination in the draft. Click **Apply settings**
  to save. If a combination is unavailable, the window stays open and the saved
  shortcut and settings remain unchanged.
- Daily schedules use local time, include the start, and exclude the end. Overnight
  ranges such as `22:00–07:00` work; equal start and end times mean all day.
- The menu bar is hidden during a blackout by default. This can be disabled in
  Settings. The previous menu bar and Dock presentation is restored afterward.
- Blackout windows use normal window level. Automatic blackouts are skipped while
  Settings or the menu is open. Canceling or closing Settings preserves saved
  values. Quick menu changes apply immediately, and manual blackout does not
  toggle Keep awake.
- Quitting stops only this app's `caffeinate` process. It does not change permanent
  system sleep settings or other apps' sleep assertions.

The black windows are not a lock screen or a separate full-screen Space. Sleep
prevention does not override manual sleep or macOS lid-close behavior.

### Change or add a language

[Resources/Translations/en.json](Resources/Translations/en.json) is the canonical
English source for interface text; [ko.json](Resources/Translations/ko.json) is the
bundled Korean translation. On first launch, the app copies missing bundled JSON
files into this editable directory and creates `language.txt` there with `auto`:

```text
~/Library/Application Support/agenticnights/Translations/
  en.json
  ko.json
  language.txt
```

Existing translation files and language choices are preserved. Files are read only
when the app launches; there is no language selector in Settings.

- Leave `language.txt` as `auto` to follow macOS preferred languages. The app tries
  a regional language code, then its base language, and falls back to English.
- Put `en`, `ko`, or a custom language code such as `de` in `language.txt` to choose
  that language explicitly. **Fully quit and reopen the app** after changes.
- To add German, copy `en.json` to `de.json` in the same directory and translate
  only the values. Keep all keys and named `{placeholders}` exactly as written.
  Save valid UTF-8 JSON, retaining valid escapes such as `\n` and `\"`.
  Set `language.txt` to `de`, then fully quit and reopen the app.

Do not edit the signed app bundle or Swift files to translate the interface. App
data changes need no rebuild or signature changes. Existing custom files are never
overwritten by the app, including during upgrades. Use the current canonical
English file as your reference when updating a translation; an existing app-data
copy may lack newer keys.

Missing or invalid entries, including new keys, use the current bundled translation
for the selected language when available, then English. The same fallback applies
when a whole JSON file is invalid. Exact default values exported by v1.2 use updated
bundled wording; values edited away from those defaults remain custom overrides.
This migration never rewrites the user's translation files. The bundled
`legacy-v1.2.json` records old defaults and is not a selectable language or exported
editable catalog. The local status snapshot exposes `uiLanguage`,
`translationDirectory`, and `localizationWarnings` to help diagnose the selection.

#### Translate with an AI agent

Replace German and `de` below with the language you want:

```text
Translate the agenticnights interface into German (de). Work only in:
~/Library/Application Support/agenticnights/Translations/

Use en.json as the English template and create or update de.json. Translate values
only; preserve all keys, named {placeholders}, UTF-8 encoding, and valid JSON escapes.
Preserve existing custom translations and change only what is needed for this
language. Validate the JSON and compare keys/placeholders against the English source.
Set language.txt in this same directory to de. Do not change Swift files, the app
bundle, signatures, other translation files, or app settings. Fully quit/reopen
the app and inspect its language/warnings only if I request a relaunch. Report the
files changed, validation results, and whether relaunch verification was performed.
```

### Development and tests

Run `./Scripts/test.sh` and `./Scripts/build.sh` from the repository root. The test
script runs **24 schedule/settings tests** and **10 localization tests**. These
cover schedule boundaries, overnight ranges, daylight-saving time, timer
expiry/persistence, settings migration, independent features, mouse-movement and
shortcut preferences, language selection, translation upgrades, and placeholders.

`./Scripts/test-interactions.sh` separately runs **2 AppKit interaction tests**.
They exercise movement dismissal and its opt-out using in-process events, plus
real Carbon shortcut registration, conflict preservation, and recorder restoration.
These checks do not establish physical mouse/trackpad or keyboard behavior.

The build produces an app for the current Mac architecture and verifies its
signature. These commands do not install or launch the app. Actual menu controls,
shortcut recording, dismissal with physical input, multi-display presentation,
and lock/sleep behavior require separate checks in the running app.

| File or directory | Responsibility |
| --- | --- |
| `Sources/Schedule.swift` | Settings models, schedules, and auto-stop timer |
| `Sources/CoverController.swift` | Display covers and dismissal |
| `Sources/SleepPrevention.swift` | App-owned sleep prevention process |
| `Sources/SettingsWindow.swift` | Settings editing, saving, and cancellation |
| `Sources/Shortcut.swift` | Persisted shortcut model and supported keys |
| `Sources/GlobalShortcut.swift` | Global shortcut registration and conflict preservation |
| `Sources/Localization.swift` | Launch-time language selection and translation fallback |
| `Sources/main.swift` | Menu bar, persistence, and app coordination |
| `Resources/Translations/` | Canonical English and bundled Korean interface text |

Settings are stored as `settings` JSON data in the `com.tk.agenticnights`
UserDefaults domain. The local status snapshot is
`~/Library/Application Support/agenticnights/status.json`; it includes the app path,
feature states, schedules, deadlines, movement dismissal, shortcut settings,
cover geometry, process IDs, and localization
details (`uiLanguage`, `translationDirectory`, `localizationWarnings`). It does not
record screen content or keystrokes. Check the process ID and executable path to
confirm that the app is running, since the snapshot may outlive the process.

Build and verification output belongs in `.build/`, which Git ignores. Source code,
comments, and developer documents use English. Translations belong in JSON data,
where Korean and other languages are supported. This README is available in
English and Korean.

### License and third-party code

The source, documentation, and build scripts use the [MIT license](LICENSE), which
permits personal and commercial use, modification, redistribution, and sale while
retaining the required notices. The software is provided without warranty.

The process-lifetime `caffeinate` approach in `Sources/SleepPrevention.swift` is
adapted from [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake),
copyright Marcel Dierkes, under MIT. [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
contains the pinned upstream references and full original notice. Retain both
license files in source and binary distributions; the build copies them into the
app's `Contents/Resources/` directory. macOS frameworks and the system `caffeinate`
executable are platform components, not bundled or relicensed by this project.

## 한국어

Mac이 자동으로 잠들지 않게 유지하고, 일정한 간격마다 디스플레이를 검은 창으로
덮는 작은 메뉴 막대 앱입니다. 스크린 블랙아웃과 잠자기 방지를 따로 제어하고, 매일의
작동 시간대와 잠자기 방지 자동 종료 타이머를 설정할 수 있습니다.

**버전 1.3.0 · macOS 13 이상 · 영어·한국어 기본 제공 · MIT 라이선스**

인터페이스는 기본적으로 macOS의 언어를 따릅니다. 사용자나 AI 에이전트가 앱 데이터의
번역 파일을 편집하여 다른 언어를 추가할 수 있으며, 앱을 다시 빌드할 필요가 없습니다.

### 소스에서 설치

Git, Xcode Command Line Tools의 Swift, `python3`가 필요합니다. 전체 Xcode 앱이나
외부 패키지는 필요하지 않습니다. Apple Silicon 또는 Intel Mac에서 해당 Mac의
아키텍처로 빌드하며, 컴파일 스레드는 2개로 제한합니다.

새 체크아웃을 만드는 경우:

```sh
mkdir -p "$HOME/dev"
git clone https://github.com/taekimax/agenticnights.git "$HOME/dev/agenticnights"
cd "$HOME/dev/agenticnights"
./Scripts/test.sh
./Scripts/build.sh
./Scripts/install.sh
open /Applications/agenticnights.app
```

기존 체크아웃이 있다면 업데이트 전에 Git 상태를 확인하고 로컬 변경을 보존하세요.
공개 소스를 받는 데 GitHub 로그인이나 API 키는 필요하지 않습니다. 인증이 필요한
개발 작업에는 SSH를 사용하세요.

- 빌드 결과: `.build/agenticnights.app`.
- 설치 위치: `/Applications/agenticnights.app`.
- 설치 스크립트는 기존 앱을 종료하고 `~/.Trash/agenticnights-<timestamp>.app`으로
  옮긴 뒤 새 앱을 복사합니다. 서명과 설치 전후 전체 파일 일치를 확인합니다.
- 로컬 ad-hoc 서명을 사용합니다. 앱은 네트워크·접근성·화면 녹화 권한을 요청하지 않습니다.
- 처음 실행하면 설정 창이 열립니다. 이후에는 메뉴 막대에서 설정을 열거나
  Applications의 앱을 다시 열면 됩니다.

### AI 에이전트로 설치

Mac에서 로컬 작업이 가능한 에이전트에 다음 메시지를 전달하세요.

```text
이 Mac에 agenticnights를 소스에서 빌드하여 설치하고 실행해 주세요.
저장소: https://github.com/taekimax/agenticnights

macOS 13 이상인지, Git, Xcode Command Line Tools의 Swift, python3가 준비되어
있는지 확인하세요. 도구 설치나 시스템 동의에 사용자 조치가 필요하면 정확한
단계를 알려 주세요. 홈 아래 적절한 위치에 복제하되 기존 작업을 보존하고,
필요하면 별도 폴더를 사용하세요. README.md와 Scripts부터 읽어 주세요.

Scripts/test.sh, Scripts/build.sh, Scripts/install.sh를 순서대로 실행한 뒤
/Applications/agenticnights.app을 여세요. 컴파일 스레드 2개 제한을 유지하고,
설치 스크립트의 종료·백업 절차를 따르며 설정과 데이터를 보존하세요.
별도로 요청한 설정이 없다면 앱의 기본값을 사용하세요.

설치본 서명, 설치 전후 파일 일치, 실제 실행 경로를 확인하세요. 달 아이콘 메뉴,
빠른 제어, 마우스 이동 옵션, 단축키 입력, 저장·취소, 재실행 후 설정 유지를
검사하세요. 프로세스 내부 이벤트 검사는 실제 마우스·키보드 입력 검사와 구분하고,
검사용으로 바꾼 설정은 복원하세요. 앱 소유 caffeinate를 다른 잠자기 방지
프로세스와 구분하세요. 필요하면 시간 제한이 있는 잠자기 방지를 사용하고,
직접 시작한 것만 완료 후 해제하세요.

인증·보안 설정을 바꾸지 않고 설치를 완료하세요. 제품 코드 변경, 커밋·푸시는
하지 마세요. 설치한 버전·커밋, 경로, 설정, 실행 상태와 검사 결과를 보고하고,
실행하지 못한 검사는 NOT RUN으로 표시하세요. 임시 검증 파일은 정리하되
복구본과 유용한 빌드 캐시는 보존하세요.
```

### 사용

메뉴 막대의 달 아이콘을 클릭하면 자주 쓰는 기능과 **설정…**을 바로 열 수 있습니다.
좌클릭, 우클릭, 보조 키를 누른 클릭 모두 같은 메뉴를 엽니다. 기능이 하나라도 켜져
있으면 채워진 달을 표시하고, 메뉴와 툴팁에서 각 기능의 현재 상태를 확인할 수
있습니다. 업데이트는 기존 기능의 켜짐 상태와 호환되는 설정을 유지하며, 이전의
아이콘 클릭 동작 선택은 더 이상 사용하지 않습니다.

| 메뉴 항목 | 동작 |
| --- | --- |
| 스크린 블랙아웃 켜기 / Mac 잠자기 방지 | 각 기능을 독립적으로 켜거나 끄기 |
| 블랙아웃 간격 | 5·10·15·30·60분 선택, 간격 직접 설정은 설정 창 열기 |
| 마우스 이동으로 화면 가림 해제 | 마우스 이동 해제를 켜거나 끄기 |
| 잠자기 방지 자동 종료 | 직접 끌 때까지 또는 30·60·120분 후 선택; 잠자기 방지의 켜짐 상태는 유지 |
| 지금 화면 가리기 / 화면 가림 해제 | 검은 창 표시 또는 해제 |
| 단축키 / 설정… | 단축키, 사용자 지정 시간과 매일의 시간대를 편집하는 설정 창 열기 |

- **스크린 블랙아웃**은 처음에 켜져 있으며, 기본 간격은 10분이고 시간대 제한은
  없습니다. 한 주기가 지나면 처음 가립니다. 자동 블랙아웃 작동 중 수동으로
  가리면 그 시점부터 다음 주기를 계산합니다.
- **잠자기 방지**는 블랙아웃과 별도로 Mac과 디스플레이의 자동 잠자기를 막습니다.
  처음에는 켜져 있고 타이머와 시간대 제한은 없습니다. 자동 종료 타이머는
  1–1440분이며 잠자기 방지가 실제 작동할 때 시작합니다. 시간대 밖이나 앱이
  종료된 동안에도 시간이 흐르고, 만료되면 잠자기 방지가 꺼집니다. 재실행,
  잠자기 후 복귀, 블랙아웃 설정 변경은 종료 시각을 연장하지 않습니다.
  잠자기 방지를 껐다 켜거나 타이머 분수·사용 여부를 바꾸면 작동 시 새 타이머를 시작합니다.
- 기본적으로 마우스나 트랙패드를 움직이면 화면 가림을 해제합니다. 메뉴나 설정에서
  **마우스 이동으로 화면 가림 해제**를 끄면 클릭, 키 입력, 단축키 또는 앱 전환으로
  해제할 때까지 유지합니다. 해제에 사용한 키는 이전 앱에 전달되지 않습니다.
  이 옵션은 앱의 검은 창에 적용되며, 실제 시스템·디스플레이 잠자기 해제는
  macOS의 동작을 따릅니다.
- 기본 전역 단축키는 **Control+Option+Command+B**입니다. 설정에서 **변경…**을
  누른 뒤 Command·Option·Control 중 하나와 A–Z·0–9·F1–F20을 조합해 누르세요.
  Shift도 함께 사용할 수 있습니다. 단축키는 키의 물리적 위치를 사용하고 미국식
  키보드 배열의 이름으로 표시합니다. Esc는 단축키 입력만 취소합니다. **기본값 사용**은
  편집 중인 조합을 기본값으로 되돌립니다. **설정 적용**을 눌러 저장하세요.
  사용할 수 없는 조합이면 창을 열어둔 채 기존 단축키와 저장된 설정을 유지합니다.
- 매일의 시간대는 시스템의 현지 시각을 사용하며, 시작 시각을 포함하고 종료
  시각에 멈춥니다. `22:00–07:00`처럼 자정을 넘는 시간대를 지원합니다.
  시작과 종료가 같으면 하루 종일 작동합니다.
- 검은 창이 표시되는 동안 메뉴 막대를 숨기는 것이 기본값이며 설정에서 해제할 수
  있습니다. 가림이 끝나면 이전 메뉴 막대·Dock 표시 상태로 돌아갑니다.
- 가림 창은 일반 창 높이를 사용하며, 설정이나 메뉴가 열린 동안에는 자동 가림을
  건너뜁니다. 설정을 취소하거나 창을 닫으면 저장값을 보존합니다. 메뉴에서 바꾼
  값은 즉시 적용하며, 수동 가림은 잠자기 방지를 켜거나 끄지 않습니다.
- 앱을 종료하면 이 앱이 시작한 `caffeinate`만 종료합니다. 시스템의 영구 잠자기
  설정이나 다른 앱의 잠자기 방지는 변경하지 않습니다.

검은 창은 잠금 화면이나 별도 전체화면 Space가 아닙니다. 잠자기 방지는 수동
잠자기나 macOS의 덮개 닫기 동작을 우회하지 않습니다.

### 언어 변경과 번역 추가

[Resources/Translations/en.json](Resources/Translations/en.json)은 인터페이스 문구의
기준 영어 원문이며, [ko.json](Resources/Translations/ko.json)은 기본 제공 한국어
번역입니다. 앱은 처음 실행할 때 아래 폴더에 없는 기본 JSON 파일을 복사하고,
같은 폴더에 `auto`가 적힌 `language.txt`를 만듭니다.

```text
~/Library/Application Support/agenticnights/Translations/
  en.json
  ko.json
  language.txt
```

기존 번역 파일과 언어 선택은 보존합니다. 파일은 앱을 시작할 때만 읽으며,
Settings에는 언어 선택 메뉴가 없습니다.

- `language.txt`를 `auto`로 두면 macOS의 선호 언어를 따릅니다. 지역을 포함한
  언어 코드, 기본 언어 순서로 찾고, 사용할 수 없으면 영어로 표시합니다.
- `language.txt`에 `en`, `ko` 또는 `de` 같은 사용자 지정 언어 코드를 적으면
  해당 언어를 직접 선택합니다. 변경 후에는 **앱을 완전히 종료하고 다시 실행**하세요.
- 독일어를 추가하려면 같은 폴더의 `en.json`을 `de.json`으로 복사하고 값만
  번역하세요. 키와 이름이 있는 `{placeholders}`는 그대로 유지해야 합니다.
  `\n`, `\"` 같은 이스케이프를 보존하고 유효한 UTF-8 JSON으로 저장하세요.
  `language.txt`를 `de`로 바꾼 뒤 앱을 완전히 종료하고 다시 실행하면 됩니다.

번역을 위해 서명된 앱 번들이나 Swift 파일을 수정하지 마세요. 앱 데이터만 바꾸므로
다시 빌드하거나 서명을 바꿀 필요가 없습니다. 앱은 업데이트할 때도 기존 사용자 번역을
덮어쓰지 않습니다. 기존 앱 데이터의 영어 파일에는 새 키가 없을 수 있으므로,
번역을 갱신할 때는 최신 기준 영어 파일을 참고하세요.

새 키를 포함하여 일부 항목이 없거나 잘못된 경우 선택한 언어의 최신 기본 제공
번역을 먼저 사용하고, 없으면 영어로 표시합니다. JSON 파일 전체가 잘못된 경우도
같습니다. v1.2가 내보낸 기본 문구와 정확히 같은 값은 최신 기본 문구로 표시하고,
사용자가 다르게 편집한 값은 유지합니다. 이 과정에서 사용자 번역 파일을 다시 쓰지
않습니다. 번들의 `legacy-v1.2.json`은 이전 기본 문구를 기록한 자료이며, 선택할 수
있는 언어나 내보내는 편집용 번역 파일이 아닙니다. 로컬 상태 스냅샷의 `uiLanguage`,
`translationDirectory`, `localizationWarnings`에서 언어 선택과 경고를 확인할 수 있습니다.

#### AI 에이전트로 번역

아래의 독일어와 `de`를 원하는 언어로 바꿔 전달하세요.

```text
agenticnights 인터페이스를 독일어(de)로 번역해 주세요. 다음 폴더에서만 작업하세요.
~/Library/Application Support/agenticnights/Translations/

en.json을 영어 기준으로 삼아 de.json을 만들거나 갱신하세요. 값만 번역하고,
키, 이름이 있는 {placeholders}, UTF-8 인코딩과 유효한 JSON 이스케이프를 유지하세요.
기존 사용자 번역을 보존하며 이 언어에 필요한 부분만 수정하세요. JSON 문법을
검사하고 영어 원문의 키·플레이스홀더와 비교하세요. 같은 폴더의 language.txt를
de로 설정하세요. Swift 파일, 앱 번들, 서명, 다른 번역 파일이나 앱 설정은 바꾸지
마세요. 제가 재실행을 요청한 경우에만 앱을 완전히 종료·실행하고 언어와 경고를
확인하세요. 바꾼 파일, 검증 결과와 재실행 검증 여부를 보고하세요.
```

### 개발과 테스트

저장소 루트에서 `./Scripts/test.sh`와 `./Scripts/build.sh`를 실행합니다.
테스트 스크립트는 **일정·설정 테스트 24개**와 **현지화 테스트 10개**를 실행합니다.
일정 경계, 자정을 넘는 시간대, 서머타임, 타이머 만료·저장, 설정 호환성,
독립적인 기능 제어, 마우스 이동·단축키 설정, 언어 선택, 번역 업데이트와
플레이스홀더를 확인합니다.

`./Scripts/test-interactions.sh`는 별도로 **AppKit 상호작용 테스트 2개**를 실행합니다.
프로세스 내부 이벤트로 마우스 이동 해제와 끄기 옵션을 확인하고, 실제 Carbon
단축키 등록으로 충돌 시 기존 조합 보존과 입력 취소 후 복원을 확인합니다.
이 검사는 사람이 실제 마우스·트랙패드·키보드를 조작한 결과를 입증하지 않습니다.

빌드는 현재 Mac 아키텍처용 앱을 만들고 서명을 검사합니다. 이 명령들은 앱을
설치하거나 실행하지 않습니다. 실제 메뉴 조작, 단축키 입력, 물리적 입력을 통한
해제, 여러 디스플레이의 표시와 잠금·잠자기 동작은 실행 중인 앱에서 별도로
확인해야 합니다.

| 파일·폴더 | 역할 |
| --- | --- |
| `Sources/Schedule.swift` | 설정 모델, 일정과 자동 종료 타이머 |
| `Sources/CoverController.swift` | 디스플레이 가림과 해제 |
| `Sources/SleepPrevention.swift` | 앱 소유 잠자기 방지 프로세스 |
| `Sources/SettingsWindow.swift` | 설정 편집·저장·취소 |
| `Sources/Shortcut.swift` | 단축키 저장 모델과 지원 키 |
| `Sources/GlobalShortcut.swift` | 전역 단축키 등록과 충돌 시 보존 |
| `Sources/Localization.swift` | 시작 시 언어 선택과 번역 대체 처리 |
| `Sources/main.swift` | 메뉴 막대, 저장과 앱 동작 연결 |
| `Resources/Translations/` | 기준 영어 원문과 기본 제공 한국어 인터페이스 문구 |

설정은 `com.tk.agenticnights` UserDefaults의 `settings` JSON 데이터로 저장합니다.
로컬 상태 스냅샷은 `~/Library/Application Support/agenticnights/status.json`이며,
앱 경로, 기능 상태, 시간대, 종료 시각, 마우스 이동 해제·단축키 설정, 가림 창 크기,
프로세스 ID와 현지화 정보
(`uiLanguage`, `translationDirectory`, `localizationWarnings`)를 기록합니다.
화면 내용이나 키 입력은 저장하지 않습니다. 앱이 종료된 뒤에도 파일이 남을 수
있으므로 실제 실행 여부는 프로세스 ID와 실행 경로를 함께 확인하세요.

빌드·검증 결과는 Git에서 제외하는 `.build/`에 둡니다. 소스 코드, 주석과 개발 문서는
영어를 사용합니다. 번역은 JSON 데이터에 두며 한국어와 다른 언어를 지원합니다.
이 README는 영어와 한국어로 제공합니다.

### 라이선스와 외부 코드

소스·문서·빌드 스크립트는 [MIT 라이선스](LICENSE)로 공개합니다. 필요한 고지를
유지하는 조건으로 개인·상업적 이용, 수정, 재배포와 판매를 허용하며 소프트웨어는
보증 없이 제공됩니다.

`Sources/SleepPrevention.swift`의 앱 수명에 연결한 `caffeinate` 방식은
[KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake)의 MIT 코드를
Swift로 적용한 것입니다. 저작권자는 Marcel Dierkes이며,
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)에 고정 원본 링크와 고지 전문이
있습니다. 소스와 실행 파일을 배포할 때 두 라이선스 문서를 유지하세요. 빌드는
이 파일들을 앱의 `Contents/Resources/`에 복사합니다. macOS 프레임워크와 시스템
`caffeinate`는 플랫폼 구성 요소로, 이 프로젝트에 포함하거나 재라이선스하지 않습니다.

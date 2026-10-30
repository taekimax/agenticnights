# agenticnights

[English](#english) · [한국어](#한국어)

## English

Keep your Mac awake and cover its displays with black windows at regular intervals.
agenticnights is a small macOS menu bar app with independent screen protection and
sleep prevention controls, daily schedules, and an optional auto-stop timer.

**Version 1.2.0 · macOS 13 or later · English and Korean included · MIT license**

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
app path. Check the moon icon, selected click action, toggles, settings, saving,
cancellation, and persistence after relaunch. Restore settings changed for testing.
Distinguish the app's own caffeinate process from other sleep prevention tools.
If needed, use a bounded sleep assertion and stop only the one you started.

Complete the installation without changing credentials or security settings.
Do not change product code, commit, or push. Report the installed version/commit,
path, settings, running state, and checks. Mark checks you could not run as NOT RUN.
Remove temporary verification files; preserve recovery copies and useful caches.
```

### Use

The menu bar shows one moon icon. In **Settings**, choose what clicking it controls.
The control names below use the English translation:

| Choice | Moon icon click |
| --- | --- |
| Screen protection | Toggle automatic screen covers |
| Keep awake | Toggle sleep prevention |
| Screen protection + keep awake (default) | Toggle both features |

If any selected feature is enabled, clicking turns the selected features off;
otherwise, it enables them. Unselected features are unchanged. Changing the click
action alone does not toggle features or restart timers. A filled moon means at
least one selected feature is enabled; hover over it for the current status.
Right-click, Control-click, or Option-click opens the settings and manual controls.

- **Screen protection** starts enabled, with a 10-minute interval and no daily
  time restriction. The first cover appears after one full interval. A manual
  cover restarts the interval while automatic screen protection is active.
- **Keep awake** independently prevents automatic system and display sleep. It
  starts enabled, with no timer or daily time restriction. The optional auto-stop
  timer accepts 1–1440 minutes and starts when sleep prevention becomes active.
  It keeps counting outside scheduled hours and while the app is closed. Expiry
  turns Keep awake off. Relaunching, waking the Mac, or changing screen protection
  does not extend the deadline. Turning Keep awake off and on, changing the timer
  duration, or toggling timer use starts a new timer when active.
- Daily schedules use local time, include the start, and exclude the end. Overnight
  ranges such as `22:00–07:00` work; equal start and end times mean all day.
- The menu bar is hidden during a cover by default. This can be disabled in
  Settings. The previous menu bar and Dock presentation is restored afterward.
- Use **Cover now**, **Uncover**, or **Control+Option+Command+B** for manual control.
  A key press or mouse click dismisses a cover; the key is not sent to the previous
  app. Switching to another app also dismisses it. Manual covers do not toggle Keep awake.
- Covers use normal window level. Automatic covers are skipped while Settings
  is open. Canceling or closing Settings preserves saved values, and app updates
  retain compatible saved settings.
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
overwritten by the app, including during upgrades. New keys use bundled English
until you add their translations; use the current canonical English file as your
reference when updating a translation.

Missing or invalid individual entries fall back to bundled English. If an entire
JSON file is invalid, the app uses the bundled translation for the selected language
when available, otherwise English. The local status snapshot exposes `uiLanguage`,
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
script runs both the schedule and localization suites. The **25 schedule tests**
cover schedule boundaries, overnight ranges, daylight-saving
time, timer expiry/persistence, settings compatibility, independent feature
toggles, and icon action selection. That suite reports `PASS: 25 schedule tests`.
Separate localization tests check language selection, editable translation data,
fallback behavior, and placeholder validation.

The build produces an app for the current Mac architecture and verifies its
signature. These commands do not install or launch it. Actual menu bar interaction,
keyboard dismissal, multi-display presentation, and lock/sleep behavior require
separate checks in the running app.

| File or directory | Responsibility |
| --- | --- |
| `Sources/Schedule.swift` | Settings models, schedules, and auto-stop timer |
| `Sources/CoverController.swift` | Display covers and dismissal |
| `Sources/SleepPrevention.swift` | App-owned sleep prevention process |
| `Sources/SettingsWindow.swift` | Settings editing, saving, and cancellation |
| `Sources/GlobalShortcut.swift` | Global shortcut registration |
| `Sources/Localization.swift` | Launch-time language selection and translation fallback |
| `Sources/main.swift` | Menu bar, persistence, and app coordination |
| `Resources/Translations/` | Canonical English and bundled Korean interface text |

Settings are stored as `settings` JSON data in the `com.tk.agenticnights`
UserDefaults domain. The local status snapshot is
`~/Library/Application Support/agenticnights/status.json`; it includes the app path,
feature states, schedules, deadlines, cover geometry, process IDs, and localization
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
덮는 작은 메뉴 막대 앱입니다. 화면 보호와 잠자기 방지를 따로 제어하고, 매일의
작동 시간대와 잠자기 방지 자동 종료 타이머를 설정할 수 있습니다.

**버전 1.2.0 · macOS 13 이상 · 영어·한국어 기본 제공 · MIT 라이선스**

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

설치본 서명, 설치 전후 파일 일치, 실제 실행 경로를 확인하세요. 달 아이콘,
클릭 작업 선택, 기능 전환, 설정, 저장·취소, 재실행 후 설정 유지를 검사하고,
검사용으로 바꾼 설정은 복원하세요. 앱 소유 caffeinate를 다른 잠자기 방지
프로세스와 구분하세요. 필요하면 시간 제한이 있는 잠자기 방지를 사용하고,
직접 시작한 것만 완료 후 해제하세요.

인증·보안 설정을 바꾸지 않고 설치를 완료하세요. 제품 코드 변경, 커밋·푸시는
하지 마세요. 설치한 버전·커밋, 경로, 설정, 실행 상태와 검사 결과를 보고하고,
실행하지 못한 검사는 NOT RUN으로 표시하세요. 임시 검증 파일은 정리하되
복구본과 유용한 빌드 캐시는 보존하세요.
```

### 사용

메뉴 막대에는 달 아이콘 하나만 표시합니다. **Settings**에서 달 아이콘을 클릭할 때
제어할 기능을 선택합니다. 아래 항목 이름은 영어 번역을 기준으로 표기했습니다.

| 선택 항목 | 달 아이콘 클릭 |
| --- | --- |
| Screen protection | 자동 화면 보호 켜기/끄기 |
| Keep awake | 잠자기 방지 켜기/끄기 |
| Screen protection + keep awake (기본값) | 두 기능을 함께 켜기/끄기 |

선택한 기능 중 하나라도 켜져 있으면 클릭으로 모두 끄고, 모두 꺼져 있으면 켭니다.
선택하지 않은 기능은 유지됩니다. 클릭할 작업만 바꾸는 것은 기능을 전환하거나
타이머를 다시 시작하지 않습니다. 선택한 기능 중 하나라도 켜져 있으면 채워진 달이
표시되며, 포인터를 올리면 현재 상태를 볼 수 있습니다. 우클릭, Control-클릭 또는
Option-클릭으로 설정과 수동 제어 메뉴를 엽니다.

- **Screen protection**은 처음에 켜져 있으며, 기본 간격은 10분이고 시간대 제한은
  없습니다. 한 주기가 지나면 처음 가립니다. 자동 화면 보호 작동 중 수동으로
  가리면 그 시점부터 다음 주기를 계산합니다.
- **Keep awake**는 화면 보호와 별도로 Mac과 디스플레이의 자동 잠자기를 막습니다.
  처음에는 켜져 있고 타이머와 시간대 제한은 없습니다. 선택 가능한 자동 종료
  타이머는 1–1440분이며 잠자기 방지가 실제 작동할 때 시작합니다. 시간대 밖이나
  앱이 종료된 동안에도 시간이 흐르고, 만료되면 Keep awake가 꺼집니다. 재실행,
  잠자기 후 복귀, 화면 보호 설정 변경은 종료 시각을 연장하지 않습니다.
  Keep awake를 껐다 켜거나 타이머 분수·사용 여부를 바꾸면 작동 시 새 타이머를 시작합니다.
- 매일의 시간대는 시스템의 현지 시각을 사용하며, 시작 시각을 포함하고 종료
  시각에 멈춥니다. `22:00–07:00`처럼 자정을 넘는 시간대를 지원합니다.
  시작과 종료가 같으면 하루 종일 작동합니다.
- 검은 창이 표시되는 동안 메뉴 막대를 숨기는 것이 기본값이며 Settings에서
  해제할 수 있습니다. 가림이 끝나면 이전 메뉴 막대·Dock 표시 상태로 돌아갑니다.
- **Cover now**, **Uncover**, **Control+Option+Command+B**로 수동 제어합니다.
  키 입력이나 마우스 클릭으로 가림을 해제하며, 해제에 사용한 키는 이전 앱에
  전달되지 않습니다. 다른 앱으로 전환해도 해제됩니다. 수동 가림은 Keep awake를
  켜거나 끄지 않습니다.
- 가림 창은 일반 창 높이를 사용하며, Settings가 열린 동안에는 자동 가림을
  건너뜁니다. 설정을 취소하거나 창을 닫으면 저장값을 보존하고, 앱 업데이트 시에도
  호환되는 기존 설정을 유지합니다.
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
덮어쓰지 않습니다. 새 키는 번역을 추가할 때까지 기본 제공 영어로 표시합니다.
번역을 갱신할 때는 최신 기준 영어 파일을 참고하세요.

일부 항목이 없거나 잘못된 경우 해당 문구는 기본 제공 영어로 표시합니다. JSON 파일
전체가 잘못된 경우에는 선택한 언어의 기본 제공 번역을 사용하고, 없으면 영어를
사용합니다. 로컬 상태 스냅샷의 `uiLanguage`, `translationDirectory`,
`localizationWarnings`에서 언어 선택과 경고를 확인할 수 있습니다.

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
테스트 스크립트는 일정과 현지화 테스트 모음을 모두 실행합니다.
**일정 테스트 25개**는 일정 경계, 자정을 넘는 시간대, 서머타임, 타이머
만료·저장, 설정 호환성, 독립적인 기능 전환과 아이콘 작업 선택을 확인합니다.
이 테스트 모음은 성공하면 `PASS: 25 schedule tests`를 출력합니다. 별도의
현지화 테스트는 언어 선택, 편집 가능한 번역 데이터, 대체 문구 처리와
플레이스홀더 검증을 확인합니다.

빌드는 현재 Mac 아키텍처용 앱을 만들고 서명을 검사합니다. 이 명령들은 앱을
설치하거나 실행하지 않습니다. 실제 메뉴 막대 조작, 키 입력 해제, 여러
디스플레이의 표시와 잠금·잠자기 동작은 실행 중인 앱에서 별도로 확인해야 합니다.

| 파일·폴더 | 역할 |
| --- | --- |
| `Sources/Schedule.swift` | 설정 모델, 일정과 자동 종료 타이머 |
| `Sources/CoverController.swift` | 디스플레이 가림과 해제 |
| `Sources/SleepPrevention.swift` | 앱 소유 잠자기 방지 프로세스 |
| `Sources/SettingsWindow.swift` | 설정 편집·저장·취소 |
| `Sources/GlobalShortcut.swift` | 전역 단축키 등록 |
| `Sources/Localization.swift` | 시작 시 언어 선택과 번역 대체 처리 |
| `Sources/main.swift` | 메뉴 막대, 저장과 앱 동작 연결 |
| `Resources/Translations/` | 기준 영어 원문과 기본 제공 한국어 인터페이스 문구 |

설정은 `com.tk.agenticnights` UserDefaults의 `settings` JSON 데이터로 저장합니다.
로컬 상태 스냅샷은 `~/Library/Application Support/agenticnights/status.json`이며,
앱 경로, 기능 상태, 시간대, 종료 시각, 가림 창 크기, 프로세스 ID와 현지화 정보
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

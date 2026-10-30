# agenticnights

[English](#english) · [한국어](#한국어)

## English

A macOS menu bar app for periodic screen blackout and automatic sleep prevention.
**Version 1.3.1 (build 8) · macOS 13+ · English / Korean · MIT**

### Install

Requires Git, `python3`, and Swift from Xcode Command Line Tools.
Builds use the current Mac's architecture and two compiler threads.

```sh
mkdir -p "$HOME/dev"
git clone https://github.com/taekimax/agenticnights.git "$HOME/dev/agenticnights"
cd "$HOME/dev/agenticnights"
./Scripts/test.sh
./Scripts/build.sh
./Scripts/install.sh
open /Applications/agenticnights.app
```

Preserve local changes before updating an existing checkout. Use SSH for authenticated Git work.

- Build: `.build/agenticnights.app`, with a local ad-hoc signature.
- Install: `/Applications/agenticnights.app`.
- The installer quits the old app, moves it to `~/.Trash/agenticnights-<timestamp>.app`,
  copies the replacement, and checks its signature and all files against the build.
- Settings and app data remain in place. Settings open on first launch.

AI installation prompt: “Build, install, and launch this repository using this README.
Preserve existing work, settings, and recovery copies. Verify the installed app and
report untested behavior. Restore test settings. Do not edit code or Git.”

### Use

Click the app's menu bar icon to open controls and Settings. Menu changes save immediately.
Screen blackout and Sleep prevention start enabled; the blackout interval is 10 minutes.
Mouse movement restores the screen by default. Daily schedules and auto-stop start disabled.

| Control | Action |
| --- | --- |
| Automatic blackout / Prevent sleep | Turn each feature on or off |
| Blackout interval | Choose 5, 10, 15, 30, or 60 minutes; open Settings for another value |
| Restore on mouse movement | Enable or disable movement dismissal |
| Sleep prevention timer | Choose No timer, or 30, 60, or 120 minutes; preserves the feature's on/off state |
| Black out now / Restore screen | Show or dismiss the black windows |
| Settings | Edit the shortcut, custom durations, and daily schedules |

- Blackout starts after one full interval. While enabled, a manual blackout restarts it.
  Automatic blackout is skipped while Settings or the menu is open.
- Move the mouse or trackpad, click, press a key, or switch apps to dismiss a blackout.
  When movement dismissal is off, clicks, keys, and app switching still work.
  The dismissing key is consumed. Menu bar hiding is on by default and can be disabled.
- Sleep prevention blocks automatic system and display sleep. Its timer starts on
  activation, counts while outside scheduled hours or while the app is closed,
  and disables the feature at expiry. Relaunching does not extend it. Changing the
  timer or turning the feature off and on starts a new deadline when active.
- Intervals and timers accept 1–1440 minutes. Schedules use local time: start included,
  end excluded; `22:00–07:00` spans midnight; equal times mean all day.
- These are normal black windows, not a screen lock. Waking from actual sleep is
  controlled by macOS. Sleep prevention does not override manual sleep or lid closing.
  Quitting stops only this app's `caffeinate` process.

### Change the shortcut

Default: **Control+Option+Command+B**. Open Settings, click **Change…**,
then press Command, Option, or Control with A–Z, 0–9, or F1–F20. Shift is optional.
Keys use physical positions and US keyboard labels.

Escape cancels shortcut capture. **Save** applies the draft; **Cancel** or closing the window
preserves saved settings. An unavailable shortcut leaves the window open and preserves
the saved shortcut. **Default** restores the default combination in the draft.

### Language

The interface follows macOS by default. Editable files are in:

```text
~/Library/Application Support/agenticnights/Translations/
  en.json
  ko.json
  language.txt
```

- Set `language.txt` to `auto`, `en`, `ko`, or a custom language code. Fully quit and reopen.
- To add a language, copy the current [en.json](Resources/Translations/en.json) to
  `<code>.json` in that folder. Translate values; preserve keys, `{placeholders}`,
  UTF-8, and JSON escapes. Set `language.txt` to the code and reopen the app.
- Missing or invalid entries use the bundled selected language, then English.
  Unchanged v1.2 and v1.3 default text uses current wording. Custom edits and file
  bytes are preserved. Translation changes require no build or app-bundle edits.

AI translation prompt: “Translate the current en.json into <language> (<code>).
Edit only <code>.json and language.txt in app data. Preserve custom edits, keys and
placeholders; validate UTF-8 JSON. Relaunch only if requested.”

### Tests and data

| Command | Checks |
| --- | --- |
| `./Scripts/test.sh` | 24 schedule/settings tests; 10 localization tests |
| `./Scripts/test-interactions.sh` | 2 tests: in-process AppKit events and Carbon shortcut registration |
| `./Scripts/build.sh` | Compile and verify the signed bundle; does not install |

Test events do not prove physical input behavior. Check menus, shortcut capture,
physical input, multiple displays, and actual sleep separately in the running app.

Settings: `settings` JSON in the `com.tk.agenticnights` UserDefaults domain.
Status: `~/Library/Application Support/agenticnights/status.json` contains settings,
process IDs, display geometry, and language diagnostics. It records no screen content
or keystrokes. Check the PID and executable path; the file can remain after exit.
Build/test output: Git-ignored `.build/`.

### License

[MIT](LICENSE). `Sources/SleepPrevention.swift` adapts code from
[KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake), copyright Marcel Dierkes.
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) contains the source references and
original license. Keep both license files in distributions; the build includes them.

## 한국어

일정한 간격으로 화면을 가리고 자동 잠자기를 방지하는 macOS 메뉴 막대 앱입니다.
**버전 1.3.1 (빌드 8) · macOS 13 이상 · 영어 / 한국어 · MIT**

### 설치

Git, `python3`, Xcode Command Line Tools의 Swift가 필요합니다.
현재 Mac의 아키텍처로 빌드하며 컴파일 스레드는 2개를 사용합니다.

```sh
mkdir -p "$HOME/dev"
git clone https://github.com/taekimax/agenticnights.git "$HOME/dev/agenticnights"
cd "$HOME/dev/agenticnights"
./Scripts/test.sh
./Scripts/build.sh
./Scripts/install.sh
open /Applications/agenticnights.app
```

기존 체크아웃을 갱신하기 전에 로컬 변경을 보존하세요. 인증이 필요한 Git 작업에는 SSH를 사용하세요.

- 빌드: `.build/agenticnights.app`. 로컬 ad-hoc 서명을 사용합니다.
- 설치: `/Applications/agenticnights.app`.
- 설치 스크립트는 기존 앱을 종료하고 `~/.Trash/agenticnights-<timestamp>.app`으로
  옮긴 뒤 새 앱을 복사합니다. 설치본 서명과 빌드 결과의 전체 파일 일치를 검사합니다.
- 설정과 앱 데이터는 보존합니다. 처음 실행하면 설정 창이 열립니다.

AI 설치 지시: “이 README에 따라 저장소를 빌드·설치·실행하세요. 기존 작업, 설정과
복구본을 보존하고 설치본을 검증하세요. 검사용 설정을 복원하고 미검증 항목을 보고하세요.
코드나 Git은 변경하지 마세요.”

### 사용

메뉴 막대의 앱 아이콘을 클릭하면 기능과 설정을 엽니다. 메뉴에서 바꾼 값은 즉시 저장합니다.
기본값은 화면 가리기와 잠자기 방지 켜짐, 가림 간격 10분, 마우스 이동 해제 켜짐입니다.
시간대 제한과 자동 종료 타이머는 처음에 꺼져 있습니다.

| 기능 | 동작 |
| --- | --- |
| 자동으로 화면 가리기 / 잠자기 방지 | 각 기능을 켜거나 끄기 |
| 화면 가리기 간격 | 5·10·15·30·60분 선택; 다른 값은 설정에서 입력 |
| 마우스 이동으로 해제 | 이동으로 가림을 해제하는 기능 켜기/끄기 |
| 잠자기 방지 자동 종료 | 타이머 없음 또는 30·60·120분; 기능의 켜짐 상태는 유지 |
| 지금 화면 가리기 / 화면 가림 해제 | 검은 창 표시 또는 해제 |
| 설정 | 단축키, 사용자 지정 시간, 매일의 시간대 편집 |

- 한 주기가 지나면 처음 가립니다. 자동 가림 작동 중 수동으로 가리면 다음 주기를 다시 계산합니다.
  설정이나 메뉴가 열려 있으면 자동 가림을 건너뜁니다.
- 마우스·트랙패드 이동, 클릭, 키 입력, 앱 전환으로 가림을 해제합니다. 이동 해제를
  꺼도 클릭·키 입력·앱 전환은 작동합니다. 해제에 사용한 키는 이전 앱에 전달하지 않습니다.
  가림 중 메뉴 막대 숨기기는 기본으로 켜져 있으며 설정에서 끌 수 있습니다.
- 잠자기 방지는 시스템과 화면의 자동 잠자기를 막습니다. 타이머는 작동 시 시작하고,
  시간대 밖이나 앱이 종료된 동안에도 흐르며, 만료되면 기능을 끕니다. 재실행으로
  연장되지 않습니다. 타이머를 변경하거나 기능을 껐다 켜면 작동 시 새 종료 시각을 설정합니다.
- 간격과 타이머는 1–1440분입니다. 시간대는 현지 시각으로 시작을 포함하고 종료를 제외합니다.
  `22:00–07:00`은 자정을 넘는 시간대이며, 시작과 종료가 같으면 하루 종일 작동합니다.
- 검은 창은 화면 잠금이 아닙니다. 실제 잠자기 해제는 macOS가 처리합니다.
  잠자기 방지는 수동 잠자기나 덮개 닫기를 막지 않습니다.
  종료하면 이 앱이 시작한 `caffeinate`만 종료합니다.

### 단축키 변경

기본값은 **Control+Option+Command+B**입니다. 설정에서 **변경…**을 누르고
Command·Option·Control 중 하나와 A–Z·0–9·F1–F20을 조합하세요. Shift도 사용할 수 있습니다.
키의 물리적 위치를 사용하며 미국식 키보드 이름으로 표시합니다.

Esc는 단축키 입력만 취소합니다. **저장**하면 편집한 값을 적용하고, **취소**하거나 창을 닫으면
저장값을 유지합니다. 사용할 수 없는 단축키는 창을 열어둔 채 기존 조합을 유지합니다.
**기본값**은 편집 중인 조합을 기본값으로 되돌립니다.

### 언어

기본적으로 macOS 언어를 따릅니다. 편집할 파일은 다음 폴더에 있습니다.

```text
~/Library/Application Support/agenticnights/Translations/
  en.json
  ko.json
  language.txt
```

- `language.txt`에 `auto`, `en`, `ko` 또는 사용자 지정 언어 코드를 적고 앱을 완전히 종료·재실행하세요.
- 언어를 추가하려면 최신 [en.json](Resources/Translations/en.json)을 위 폴더의
  `<code>.json`으로 복사하세요. 값만 번역하고 키, `{placeholders}`, UTF-8과 JSON 이스케이프를
  유지하세요. `language.txt`를 해당 코드로 바꾸고 앱을 다시 실행하세요.
- 없거나 잘못된 항목은 선택한 언어의 기본 제공 문구, 영어 순서로 대체합니다.
  수정하지 않은 v1.2·v1.3 기본 문구는 최신 문구로 표시합니다. 사용자 편집과 파일 내용은
  보존합니다. 번역을 바꿀 때 빌드하거나 앱 번들을 편집할 필요가 없습니다.

AI 번역 지시: “최신 en.json을 <언어>(<코드>)로 번역하세요. 앱 데이터의 <코드>.json과
language.txt만 편집하고 기존 편집, 키와 플레이스홀더를 보존하세요. UTF-8 JSON을
검사하고 요청한 경우에만 재실행하세요.”

### 테스트와 데이터

| 명령 | 검사 |
| --- | --- |
| `./Scripts/test.sh` | 일정·설정 24개, 현지화 10개 |
| `./Scripts/test-interactions.sh` | 프로세스 내부 AppKit 이벤트와 Carbon 단축키 등록 2개 |
| `./Scripts/build.sh` | 컴파일과 서명 검사; 설치는 별도 |

테스트 이벤트는 물리적 입력을 입증하지 않습니다. 메뉴, 단축키 입력, 실제 입력,
여러 디스플레이, 실제 잠자기는 실행 중인 앱에서 별도로 확인하세요.

설정은 `com.tk.agenticnights` UserDefaults의 `settings` JSON으로 저장합니다.
`~/Library/Application Support/agenticnights/status.json`에는 설정, 프로세스 ID,
화면 크기와 언어 진단을 기록합니다. 화면 내용과 키 입력은 저장하지 않습니다.
종료 후에도 파일이 남을 수 있으므로 PID와 실행 경로를 함께 확인하세요.
빌드·테스트 결과는 Git에서 제외하는 `.build/`에 둡니다.

### 라이선스

[MIT](LICENSE). `Sources/SleepPrevention.swift`는 Marcel Dierkes의
[KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake) 코드를 적용했습니다.
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)에 원본 링크와 라이선스 전문이 있습니다.
배포 시 두 라이선스 파일을 유지하세요. 빌드에 자동으로 포함됩니다.

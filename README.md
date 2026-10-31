# agenticnights

[English](#english) · [한국어](#한국어)

## English

A macOS menu bar app that covers the screen and prevents automatic sleep after a period without input.

**1.4.0 (build 10) · macOS 13+ · English / Korean · MIT**

### Install

Requires Git, Python 3, and Swift from Xcode Command Line Tools.

```sh
mkdir -p "$HOME/dev"
git clone https://github.com/taekimax/agenticnights.git "$HOME/dev/agenticnights"
cd "$HOME/dev/agenticnights"
./Scripts/build.sh
./Scripts/install.sh
open /Applications/agenticnights.app
```

The installer preserves settings and moves the previous app to a timestamped app bundle in Trash.
Settings open on first launch. See [Development](DEVELOPMENT.md) for tests and build details.

### Use

Both features start enabled with a **10-minute idle delay**. Each mouse, keyboard, or trackpad event restarts that delay. For example, with a five-minute delay, an input at 10:04 moves activation to 10:09. While you keep using the Mac, neither automatic feature starts.

| Action | Result |
| --- | --- |
| Left-click the moon icon | Toggle the features selected in Settings; the default is Both |
| Right-click the icon | Open the menu; Control-click and Option-click also work |
| Change Idle delay | Set the shared delay for screen blackout and sleep prevention |
| Black out now or **Control+Option+Command+B** | Immediately show or dismiss the cover |
| Move the mouse/trackpad, click, press a key, or switch apps | Dismiss the cover |

You can enable each feature separately. If either selected feature is enabled, left-click turns the selection off. Menu edits save immediately; Settings edits require **Save**. **Cancel** and closing Settings preserve saved values.

- Input stops sleep prevention until the next idle period, even when blackout is disabled. The app checks once per second, so changes can take about a second.
- Disable **Restore on mouse movement** to keep the cover during pointer movement. Clicks, keys, and app switching still dismiss it. The dismissing key is consumed.
- Settings and menus suspend automatic actions. Launching the app uses time since the last input; waking or returning from another user session starts a fresh idle delay.
- **Sleep prevention timer** optionally turns that feature off after a fixed duration. It starts on first idle activation and keeps counting during resumed use, outside scheduled hours, and while the app is closed. Relaunching preserves the deadline; changing the timer or switching the feature off/on restarts it at the next activation.
- Each feature has its own daily scheduled hours. Delays and stop timers accept 1–1440 minutes. `22:00–07:00` crosses midnight; equal start/end times mean all day.

The cover is a black window, not a screen lock. Sleep prevention blocks automatic system and display sleep; manual sleep and lid closing still work. Quitting releases this app’s sleep prevention.

To change the shortcut, open **Settings → Change…** and press Command, Option, or Control with A–Z, 0–9, or F1–F20. Shift is optional; key labels use US keyboard positions. Escape cancels capture. Save applies the new shortcut.

### Language

The interface follows macOS by default. Editable translation files are in:

```text
~/Library/Application Support/agenticnights/Translations/
```

Set `language.txt` to `auto`, `en`, `ko`, or a custom language code, then quit and reopen the app. To add a language, copy [en.json](Resources/Translations/en.json) to `<code>.json` in that folder and translate the values. Preserve keys, `{placeholders}`, and valid UTF-8 JSON. Missing or invalid entries fall back to bundled text. Custom edits are preserved; rebuilding is unnecessary.

### License

[MIT](LICENSE). Sleep-prevention process management adapts [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake) by Marcel Dierkes. Attribution and its license are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## 한국어

입력이 없는 동안 화면을 가리고 자동 잠자기를 방지하는 macOS 메뉴 막대 앱입니다.

**1.4.0 (빌드 10) · macOS 13 이상 · 영어 / 한국어 · MIT**

### 설치

Git, Python 3, Xcode Command Line Tools의 Swift가 필요합니다.

```sh
mkdir -p "$HOME/dev"
git clone https://github.com/taekimax/agenticnights.git "$HOME/dev/agenticnights"
cd "$HOME/dev/agenticnights"
./Scripts/build.sh
./Scripts/install.sh
open /Applications/agenticnights.app
```

설정은 유지하며 이전 앱은 날짜가 붙은 이름으로 휴지통에 보관합니다.
처음 실행하면 설정 창이 열립니다. 테스트와 빌드 정보는 [개발 문서](DEVELOPMENT.md)에 있습니다.

### 사용

기본값은 두 기능 켜짐, **입력이 없을 때 대기 시간 10분**입니다. 마우스·키보드·트랙패드 입력이 들어올 때마다 다시 계산합니다. 예를 들어 5분 설정에서 10:04에 입력하면 10:09부터 작동합니다. 계속 사용하는 동안에는 두 자동 기능이 시작되지 않습니다.

| 조작 | 동작 |
| --- | --- |
| 달 아이콘 좌클릭 | 설정에서 선택한 기능을 켜거나 끄기; 기본값은 둘 다 |
| 아이콘 우클릭 | 메뉴 열기; Control-클릭과 Option-클릭도 가능 |
| 입력 없을 때 대기 시간 변경 | 화면 가리기와 잠자기 방지에 같은 대기 시간 적용 |
| 지금 화면 가리기 또는 **Control+Option+Command+B** | 즉시 화면 가리기 또는 해제 |
| 마우스·트랙패드 이동, 클릭, 키 입력, 앱 전환 | 화면 가림 해제 |

각 기능을 따로 켜거나 끌 수 있습니다. 선택한 기능 중 하나라도 켜져 있으면 좌클릭으로 모두 끕니다. 메뉴 변경은 즉시 저장하고, 설정 창에서는 **저장**을 눌러 적용합니다. **취소**하거나 창을 닫으면 기존 설정을 유지합니다.

- 입력이 다시 들어오면 잠자기 방지를 중단하고 다음 무입력 시간을 기다립니다. 화면 가리기를 꺼도 같은 대기 시간을 적용합니다. 1초마다 확인하므로 반영에 약 1초가 걸릴 수 있습니다.
- **마우스 이동으로 해제**를 끄면 포인터를 움직여도 화면을 계속 가립니다. 클릭·키 입력·앱 전환으로는 해제할 수 있습니다. 해제에 사용한 키는 이전 앱에 전달하지 않습니다.
- 설정이나 메뉴가 열려 있으면 자동 동작을 중단합니다. 앱 실행 시에는 마지막 입력부터 지난 시간을 반영하고, 잠자기나 다른 사용자 세션에서 돌아오면 대기 시간을 새로 계산합니다.
- **잠자기 방지 자동 종료**는 정해진 시간이 지나면 해당 기능을 끄는 선택 사항입니다. 처음 실제 작동할 때 시작하며 사용 재개·시간대 밖·앱 종료 중에도 계속 흐릅니다. 재실행해도 종료 시각을 유지합니다. 타이머를 바꾸거나 기능을 껐다 켜면 다음 작동 시 새로 시작합니다.
- 기능마다 매일 작동할 시간대를 따로 지정할 수 있습니다. 대기 시간과 자동 종료는 1–1440분입니다. `22:00–07:00`은 자정을 넘는 시간대이며 시작과 종료가 같으면 하루 종일 작동합니다.

화면 가리기는 검은 창을 표시하며 화면 잠금 기능은 없습니다. 잠자기 방지는 시스템과 화면의 자동 잠자기를 막습니다. 수동 잠자기와 덮개 닫기는 그대로 작동합니다. 앱을 종료하면 이 앱의 잠자기 방지도 해제합니다.

단축키는 **설정 → 변경…**에서 바꿉니다. Command·Option·Control 중 하나와 A–Z, 0–9, F1–F20을 조합하세요. Shift도 사용할 수 있으며 키 이름은 미국식 키보드의 물리적 위치를 따릅니다. Escape는 입력을 취소하고 **저장**은 새 단축키를 적용합니다.

### 언어

기본적으로 macOS 언어를 따릅니다. 번역 파일은 다음 폴더에서 편집합니다.

```text
~/Library/Application Support/agenticnights/Translations/
```

`language.txt`에 `auto`, `en`, `ko` 또는 사용자 지정 언어 코드를 적고 앱을 종료·재실행하세요. 언어를 추가하려면 [en.json](Resources/Translations/en.json)을 이 폴더의 `<code>.json`으로 복사해 값만 번역합니다. 키, `{placeholders}`, 올바른 UTF-8 JSON 형식을 유지하세요. 없거나 잘못된 항목은 기본 제공 문구로 대체합니다. 사용자 편집은 보존하며 다시 빌드할 필요가 없습니다.

### 라이선스

[MIT](LICENSE). 잠자기 방지 프로세스 관리는 Marcel Dierkes의 [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake)를 참고했습니다. 출처와 원본 라이선스는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)에 있습니다.

# agenticnights

[English](#english) · [한국어](#한국어)

## English

Screen blackout and sleep prevention for macOS.

**1.5.0 · macOS 13+ · English / Korean · MIT**

### Install

Requires Git, Python 3 and Xcode Command Line Tools.

```sh
git clone https://github.com/taekimax/agenticnights.git
cd agenticnights
./Scripts/build.sh
./Scripts/install.sh
open /Applications/agenticnights.app
```

The installer keeps settings and moves the previous app to Trash. Enable **agenticnights** in **System Settings → Privacy & Security → Accessibility** to use blackout.

### Controls

| Action | Result |
| --- | --- |
| Left-click the moon | Toggle the selected features; default: both |
| Right-click the moon | Open the menu |
| Control+Option+Command+B | Black out or restore the screen |
| Settings → Change… | Set the blackout shortcut |
| Settings → Save / Cancel | Apply or discard edits |

### Blackout

Blackout starts after **10 minutes without physical input** by default. Each keyboard, mouse or trackpad input restarts the delay. Normal agent input can continue without postponing blackout.

Every blackout uses display gamma. The desktop remains available to compatible agents for input and capture. Original display colors are restored on exit. DisplayLink is not supported.

Without password protection, a physical key or click restores the screen. **Restore on mouse movement** also allows pointer movement to restore it. App activation and normal agent input do not restore it.

### Password

Enable **Require a password to restore the screen**, enter and confirm an app password, then save. Use 8–128 printable ASCII characters. Blank fields keep the saved password. The verifier is stored in Keychain.

A physical key or click opens the prompt. Return submits; Escape or 15 seconds without input hides the prompt and preserves protection. The text moves slowly and changes between metallic tones. The prompt is visible in agent captures while open.

| Consecutive failed attempts | Action |
| --- | --- |
| 3 | Wait 1 minute |
| 4 | Wait 2 minutes |
| 5 | Wait 4 minutes |
| 6 | Wait 8 minutes |
| 7 | Request macOS login lock |

Waiting and closing the prompt do not reset the count. Successful app authentication resets it; after escalation, a macOS lock/unlock cycle is required before retrying. Menus, shortcuts and ordinary Quit cannot bypass authentication.

This is app-level protection. Agents that inject hardware-source events may be blocked. Compatibility depends on the Mac, displays and agent. See the [implementation record](docs/privacy-protection-2026-10-31.md) for verified scope.

### Sleep prevention

**Prevent system and display sleep** starts immediately and continues during input. It has no idle delay. While password-locked, prevention stays on until authenticated unlock.

Each feature has separate scheduled hours. An optional sleep-prevention timer starts on activation and retains its deadline across app restarts. Delays and timers accept 1–1440 minutes. Equal schedule start/end times mean all day.

When macOS locks or sleeps, the app releases input interception for the login screen. Lid closing can still put the Mac to sleep. The app does not change macOS lock or screen-saver settings or guarantee prevention of every automatic lock path.

### Language

Edit files in `~/Library/Application Support/agenticnights/Translations/`, then restart. `language.txt` accepts `auto`, `en`, `ko` or a custom language code. To add a language, copy [en.json](Resources/Translations/en.json) to `<code>.json`; preserve keys and `{placeholders}`. Custom edits are preserved.

### Development and license

[Development](DEVELOPMENT.md) · [MIT](LICENSE) · [Third-party notices](THIRD_PARTY_NOTICES.md)

## 한국어

macOS 화면 가림과 잠자기 방지 앱입니다.

**1.5.0 · macOS 13 이상 · 영어 / 한국어 · MIT**

### 설치

Git, Python 3, Xcode Command Line Tools가 필요합니다.

```sh
git clone https://github.com/taekimax/agenticnights.git
cd agenticnights
./Scripts/build.sh
./Scripts/install.sh
open /Applications/agenticnights.app
```

설정을 유지하고 이전 앱은 휴지통에 보관합니다. 화면 가림을 사용하려면 **시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용**에서 **agenticnights**를 허용하세요.

### 조작

| 조작 | 동작 |
| --- | --- |
| 달 아이콘 좌클릭 | 선택한 기능 켜기·끄기; 기본값은 둘 다 |
| 달 아이콘 우클릭 | 메뉴 열기 |
| Control+Option+Command+B | 화면 가리기·해제 |
| 설정 → 변경… | 화면 가림 단축키 변경 |
| 설정 → 저장 / 취소 | 변경 적용·취소 |

### 화면 가림

기본값은 **물리 입력 없이 10분 후 가리기**입니다. 키보드·마우스·트랙패드 입력이 들어오면 다시 계산합니다. 일반적인 에이전트 입력은 대기 시간을 초기화하지 않습니다.

모든 화면 가림은 디스플레이 감마를 사용합니다. 호환되는 에이전트는 작업 화면을 계속 캡처하고 조작할 수 있습니다. 해제하면 원래 색상을 복원합니다. DisplayLink는 지원하지 않습니다.

암호 보호가 꺼져 있으면 물리 키나 클릭으로 해제합니다. **마우스 이동으로 해제**를 켜면 포인터 이동으로도 해제합니다. 앱 전환 자체나 일반적인 에이전트 입력으로는 해제되지 않습니다.

### 암호

**화면 가림 해제 시 암호 요구**를 켜고 앱 암호를 두 번 입력한 뒤 저장하세요. 영문·숫자·공백·기호 8–128자를 사용합니다. 빈칸으로 두면 기존 암호를 유지합니다. 암호 검증값은 Keychain에 저장합니다.

물리 키나 클릭으로 암호창을 엽니다. Return은 확인, Escape 또는 15초 무입력은 암호창만 닫기입니다. 텍스트는 천천히 이동하며 금속 계열 색상으로 변합니다. 암호창이 열린 동안에는 에이전트 캡처에도 표시됩니다.

| 연속 실패 횟수 | 동작 |
| --- | --- |
| 3회 | 1분 대기 |
| 4회 | 2분 대기 |
| 5회 | 4분 대기 |
| 6회 | 8분 대기 |
| 7회 | macOS 로그인 잠금 요청 |

대기하거나 암호창을 닫아도 실패 횟수는 유지됩니다. 앱 암호 인증에 성공하면 초기화합니다. macOS 잠금 단계에 도달하면 macOS 잠금·해제 후에 다시 시도할 수 있습니다. 메뉴·단축키·일반 종료로 인증을 건너뛸 수 없습니다.

앱 수준의 보호 기능입니다. 하드웨어 출처로 입력하는 에이전트는 차단될 수 있으며, Mac·디스플레이·에이전트에 따라 호환성이 달라집니다. 확인한 범위는 [구현 기록](docs/privacy-protection-2026-10-31.md)에 있습니다.

### 잠자기 방지

**잠자기·화면 꺼짐 방지**는 즉시 시작하고 사용 중에도 유지합니다. 무입력 대기 시간이 없습니다. 암호로 잠긴 동안에는 인증 해제까지 유지합니다.

각 기능의 작동 시간대를 따로 지정할 수 있습니다. 선택형 자동 종료 타이머는 잠자기 방지 시작부터 계산하며 재실행해도 종료 시각을 유지합니다. 대기 시간과 타이머는 1–1440분이고, 시간대의 시작·종료가 같으면 하루 종일 작동합니다.

macOS가 잠기거나 잠자기에 들어가면 로그인 화면을 사용할 수 있도록 입력 차단을 해제합니다. 덮개를 닫으면 Mac이 잠들 수 있습니다. macOS 잠금·화면 보호기 설정을 변경하지 않으며 모든 자동 잠금 경로를 차단하지는 않습니다.

### 언어

`~/Library/Application Support/agenticnights/Translations/`의 파일을 편집하고 재실행하세요. `language.txt`는 `auto`, `en`, `ko` 또는 사용자 지정 언어 코드를 받습니다. 언어를 추가하려면 [en.json](Resources/Translations/en.json)을 `<code>.json`으로 복사하고 키와 `{placeholders}`를 유지하세요. 사용자 편집은 보존합니다.

### 개발·라이선스

[개발 문서](DEVELOPMENT.md) · [MIT](LICENSE) · [외부 코드 출처](THIRD_PARTY_NOTICES.md)

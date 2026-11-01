# agenticnights

<img src="Resources/Brand/agenticnights-moon-transparent-v1.png" width="96" height="96" alt="agenticnights">

[English](#english) · [한국어](#한국어)

## English

Screen blackout and sleep prevention for macOS, without a system permission grant.

**2.0.0 · build 14 · macOS 13+ · English / Korean · MIT**

### Install

Requires Git, Python 3 and Xcode Command Line Tools.

```sh
git clone https://github.com/taekimax/agenticnights.git
cd agenticnights
./Scripts/build.sh
./Scripts/install.sh
open /Applications/agenticnights.app
```

The installer preserves settings and translations and moves the previous app to Trash. Build, installation and launch are separate steps. Current verification and delivery results are recorded in the [2.0 delivery record](docs/no-permission-delivery-2026-11-02.md).

### Controls

| Action | Result |
| --- | --- |
| Left-click the moon | Black Out Now by default; choose Open menu or Turn sleep prevention on or off in Settings |
| Right-click the moon | Open the menu |
| Control+Option+Command+B | Black out the screen or end blackout; change the shortcut in Settings |
| Change a setting | Apply immediately; minute fields apply on Return or leaving the field |

### Blackout

Automatic Blackout starts after **10 minutes of physical inactivity** by default. Keyboard, mouse and trackpad activity restarts the wait. Normal synthetic agent input does not postpone it. Choose a delay from the menu or enter 1–1440 minutes in Settings. Invalid input keeps the previous value and displays an error.

Blackout sets display gamma to zero, so compatible agents can still capture and use the desktop. Brightness is also reduced on displays macOS can control, including the built-in display. Ending or suspending blackout restores saved colors and brightness. Other external monitors need their own brightness controls; DisplayLink is unsupported.

**Click to end blackout.** Mouse movement, scrolling and typing leave it in place. Keyboard input and the first click pass through to the front app. Normal synthetic agent clicks leave blackout in place; agents sending hardware-source events may be treated as human input.

Enable **Require Touch ID or password to end the blackout** to use the macOS authentication dialog. Touch ID or your Mac login password ends blackout. Cancelling, failed authentication or switching to another app restores blackout. While the dialog is open, black windows cover the desktop and appear in agent captures. The menu, shortcut and ordinary Quit requests use the same authentication flow. System shutdown and logout proceed normally. If macOS cannot authenticate the account, the option cannot be enabled. If the account has no login password, an active blackout ends without authentication.

Turning on VoiceOver during blackout requests macOS login lock. Sleep, macOS lock and user switching suspend blackout and restore display output; blackout resumes on return. Force quitting can end blackout and leave brightness low; restore it with the brightness controls. This is a personal screen-hiding utility, not a replacement for macOS login lock.

### Sleep prevention

**Prevent Sleep** starts immediately and operates independently of blackout and authentication. **Keep Display On**, enabled by default, also prevents automatic display sleep. Screen-using agents need this; when the display turns off, macOS may lock the screen.

Choose **No Limit** or a duration of 1–1440 minutes. The duration starts when enabled and does not change with keyboard or mouse activity. Changing a running duration restarts it from that moment. Its deadline survives app restarts. When it expires, macOS settings apply again. There are no scheduled hours. Closing the lid can still put the Mac to sleep.

### Language and upgrades

Edit files in `~/Library/Application Support/agenticnights/Translations/`, then restart. `language.txt` accepts `auto`, `en`, `ko` or a custom language code. To add a language, copy [en.json](Resources/Translations/en.json) to `<code>.json`; preserve keys and `{placeholders}`. Missing or invalid entries fall back to bundled text. Previously exported default wording updates in memory; your files and custom edits are preserved.

Existing authentication preferences move to macOS account authentication. The retired app credential is removed once. Sleep prevention keeps the display on when importing older settings. Old icon actions map to the corresponding single action; obsolete daily hours and movement dismissal are removed.

### Development and license

[Development](DEVELOPMENT.md) · [MIT](LICENSE) · [Third-party notices](THIRD_PARTY_NOTICES.md)

## 한국어

시스템 권한 허용 없이 사용하는 macOS 화면 가리기·잠자기 방지 앱입니다.

**2.0.0 · 빌드 14 · macOS 13 이상 · 영어 / 한국어 · MIT**

### 설치

Git, Python 3, Xcode Command Line Tools가 필요합니다.

```sh
git clone https://github.com/taekimax/agenticnights.git
cd agenticnights
./Scripts/build.sh
./Scripts/install.sh
open /Applications/agenticnights.app
```

설치 프로그램은 설정과 번역 파일을 보존하고 이전 앱을 휴지통에 보관합니다. 빌드·설치·실행은 별도 단계입니다. 이번 버전의 검증과 배포 결과는 [2.0 배포 기록](docs/no-permission-delivery-2026-11-02.md)에 정리합니다.

### 조작

| 조작 | 동작 |
| --- | --- |
| 달 아이콘 좌클릭 | 기본값은 지금 화면 가리기. 설정에서 메뉴 열기 또는 잠자기 방지 켜기·끄기로 변경 |
| 달 아이콘 우클릭 | 항상 메뉴 열기 |
| Control+Option+Command+B | 화면 가리기·해제. 설정에서 단축키 변경 가능 |
| 설정 변경 | 즉시 적용. 분 입력 칸은 Return을 누르거나 다른 칸으로 옮기면 적용 |

### 화면 가리기

기본값은 **10분 동안 사용하지 않으면 자동으로 화면 가리기**입니다. 키보드·마우스·트랙패드 입력이 있으면 대기 시간이 다시 시작됩니다. 일반적인 에이전트 입력은 대기 시간을 연장하지 않습니다. 메뉴에서 대기 시간을 고르거나 설정에서 1–1440분을 입력하세요. 잘못된 입력은 이전 값을 유지하고 오류를 표시합니다.

디스플레이 감마를 0으로 만들어 화면을 가립니다. 호환되는 에이전트는 계속 화면을 캡처하고 조작할 수 있습니다. 내장 화면 등 macOS에서 밝기를 조절할 수 있는 디스플레이는 밝기도 낮춥니다. 해제하거나 일시 중지하면 저장한 색상과 밝기를 복원합니다. 그 밖의 외장 모니터 밝기는 모니터 자체 메뉴로 조절하세요. DisplayLink는 지원하지 않습니다.

**클릭하면 화면 가리기를 해제합니다.** 마우스 이동·스크롤·키 입력으로는 해제하지 않습니다. 키 입력과 첫 클릭은 맨 앞 앱에 그대로 전달됩니다. 일반적인 에이전트 클릭은 무시하지만, 하드웨어 출처로 입력하는 에이전트는 사람 입력으로 판정될 수 있습니다.

**화면 가리기 해제 시 Touch ID 또는 암호 요구**를 켜면 macOS 인증 창을 사용합니다. Touch ID 또는 Mac 로그인 암호로 해제합니다. 취소·실패하거나 다른 앱으로 전환하면 다시 화면을 가립니다. 인증 중에는 검은 창으로 바탕 화면을 덮으며, 에이전트 캡처에도 검은 창과 인증 창이 보입니다. 메뉴·단축키·일반 종료 요청도 같은 인증 절차를 거칩니다. 시스템 종료와 로그아웃은 그대로 진행합니다. macOS가 계정을 인증할 수 없으면 이 설정을 켤 수 없습니다. 계정에 로그인 암호가 없으면 진행 중인 화면 가리기는 인증 없이 해제합니다.

화면을 가린 동안 VoiceOver를 켜면 macOS 화면 잠금을 요청합니다. Mac 잠자기·macOS 잠금·사용자 전환 중에는 화면 가리기를 일시 중지하고 색상과 밝기를 복원하며, 돌아오면 다시 가립니다. 강제 종료하면 가림이 풀리고 밝기는 낮게 남을 수 있으므로 밝기 조절로 되돌리세요. 개인용 화면 가리기 도구이며 macOS 로그인 잠금을 대신하지 않습니다.

### 잠자기 방지

**잠자기 방지**는 켜는 즉시 시작하며 화면 가리기·인증과 독립적으로 동작합니다. 기본으로 켜진 **디스플레이 켜 두기**는 자동 화면 꺼짐도 막습니다. 화면을 사용하는 에이전트에 필요하며, 디스플레이가 꺼지면 macOS 설정에 따라 화면이 잠길 수 있습니다.

**제한 없음** 또는 1–1440분의 유지 시간을 선택하세요. 켠 시점부터 계산하며 키보드·마우스를 사용해도 종료 시각은 바뀌지 않습니다. 실행 중 유지 시간을 바꾸면 바꾼 시점부터 다시 계산합니다. 앱을 다시 실행해도 종료 시각은 유지됩니다. 시간이 지나면 다시 macOS 설정을 따릅니다. 시간대 지정은 없습니다. 덮개를 닫으면 Mac이 잠들 수 있습니다.

### 언어와 업그레이드

`~/Library/Application Support/agenticnights/Translations/`의 파일을 편집하고 재실행하세요. `language.txt`는 `auto`, `en`, `ko` 또는 사용자 지정 언어 코드를 받습니다. 언어를 추가하려면 [en.json](Resources/Translations/en.json)을 `<code>.json`으로 복사하고 키와 `{placeholders}`를 유지하세요. 없거나 잘못된 항목은 앱에 포함된 문구를 사용합니다. 이전 기본 문구는 파일을 덮어쓰지 않고 새 문구로 표시하며, 사용자 편집은 보존합니다.

이전 인증 설정은 macOS 계정 인증으로 이전하고, 앱 전용 인증 정보는 한 번 삭제합니다. 이전 잠자기 방지 설정은 디스플레이 켜 두기를 켠 상태로 가져옵니다. 아이콘 동작은 해당하는 단일 동작으로 이전하며, 시간대 지정과 마우스 이동 해제 설정은 제거합니다.

### 개발·라이선스

[개발 문서](DEVELOPMENT.md) · [MIT](LICENSE) · [외부 코드 출처](THIRD_PARTY_NOTICES.md)

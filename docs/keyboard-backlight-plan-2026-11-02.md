# 화면 가리기 중 내장 키보드 백라이트 끄기 — 계획

작성 2026-11-02 (Asia/Seoul). 기준 커밋 `de12542` (2.0.1, build 15). 구현 전 계획 문서다.

> **결정 (2026-11-02): 기능 제거.** 2.1.0(`b8c655a`)에 구현했다가 2.1.1에서 되돌렸다. macOS에는 이미 시스템 설정 → 키보드 → "비활성화된 후 키보드 백라이트 끄기"가 있다. 앱이 백라이트에 개입하지 않고 이 시스템 설정에 맡긴다. 기록 보존을 위해 이 문서는 남긴다.
>
> 미확인: 앱이 "디스플레이 켜 두기"(`caffeinate -d`)로 디스플레이 sleep을 막는 동안에도 이 시스템 설정이 백라이트를 끄는지는 아직 실기기에서 확인하지 않았다.

## 결론

- **구현 가능하다.** 시스템 권한 요청 없이 구현할 수 있다. 앱의 무권한 원칙과도 맞는다.
- **사용할 API**는 비공개 프레임워크 `CoreBrightness`의 `KeyboardBrightnessClient`(KBC)다. 이 클래스로 내장 키보드를 찾고, 현재 밝기를 저장하고, 0으로 낮추고, 원래 값으로 되돌린다.
- **설정**: Settings에 체크박스 하나를 둔다.
- **동작 조건**: 다음 세 가지를 모두 만족할 때만 백라이트를 끈다.
  1. 설정이 켜져 있다.
  2. 내장 디스플레이가 활성 상태다.
  3. 내장 키보드 백라이트가 있다.
- **단, 착수 전 실기기 확인이 한 건 필요하다.** M5 + macOS 26.6.x에서 KBC 쓰기가 `true`를 반환하고도 LED는 바뀌지 않는다는 외부 보고가 두 건 있다(아래 3절). 이 Mac에서는 읽기 값이 0으로 바뀌는 것까지 확인했다. 하지만 키보드에 실제로 불이 꺼지는지는 눈으로 보지 않았다.

## 1. 현재 구조

- `PrivacyLockController`는 화면 가리기 시작·일시 해제·재개·종료 때 `DisplayBlackout`(gamma)과 `DisplayBrightness`(DisplayServices)를 함께 호출한다([PrivacyLockController.swift](../Sources/PrivacyLockController.swift)).
- `DisplayBrightness`의 구조는 다음과 같다([DisplayBrightness.swift](../Sources/DisplayBrightness.swift)).
  - 비공개 프레임워크를 `dlopen`으로 선택적으로 불러온다. 심볼이 없으면 아무것도 하지 않는다.
  - `Backend`를 주입하는 구조라서 실제 하드웨어 없이 테스트할 수 있다.
  - `refresh()`를 반복 호출해도 이미 어두워진 값을 원래 값으로 다시 저장하지 않는다.
- 키보드 백라이트도 이 구조를 그대로 따른다.
- 인증 대화상자를 띄울 때 `brightness.end()`가 호출된다. 키보드 백라이트도 이 시점에 복원해야 사용자가 암호를 입력할 수 있다.

## 2. 이 Mac에서 직접 확인한 사실

환경: Mac17,4 (M5), macOS 26.6.2 (25G83), 2026-11-02.

| 항목 | 결과 |
| --- | --- |
| 클래스 로드 | `CoreBrightness.framework`에 `dlopen` 성공. KBC 메서드 20개 확인. `copyKeyboardBacklightIDs`, `isKeyboardBuiltIn:`, `brightnessForKeyboard:`, `setBrightness:forKeyboard:`, `setBrightness:fadeSpeed:commit:forKeyboard:`, `isAutoBrightnessEnabledForKeyboard:`, `enableAutoBrightness:forKeyboard:`, `isBacklightSuppressedOnKeyboard:`, `isBacklightDimmedOnKeyboard:`, `registerNotificationForKeys:keyboardID:block:` 등 |
| 키보드 ID | `95158272` 1개, `isKeyboardBuiltIn`=true. 외부 프로젝트가 많이 쓰는 ID `1`과 다르다 |
| 현재 상태 | brightness 0.328, level 4.87, 자동 밝기 켜짐, idleDimTime 0 |
| 권한 | 읽기·쓰기 모두 권한 요청이나 오류 없이 동작 |
| 0 설정 (자동 밝기 유지) | `setBrightness:0 fadeSpeed:0 commit:NO` → true. 6초 동안 brightness와 level 모두 0으로 유지. 키 입력이 없는 상태였다. 복원 후 0.328, 4.87로 돌아왔다 |
| 0 설정 (자동 밝기 끈 뒤) | 위와 같게 유지되고 같게 복원. 자동 밝기 설정도 원래 값(true)으로 돌아왔다 |
| 프로세스 종료 후 지속성 | 0으로 설정하고 복원 없이 종료하자 다른 프로세스에서 0이 읽혔다. `commit:NO`여도 마찬가지였다. 강제 종료나 크래시가 나면 백라이트가 꺼진 채 남는다 |

모든 시험이 끝난 뒤 값은 시험 전 값(0.328, 자동 밝기 켜짐)으로 되돌려 두었다.

## 3. 유사 오픈소스 검토

| 프로젝트 | 라이선스 | 방식 | 참고할 점 / 문제점 |
| --- | --- | --- | --- |
| [alin23/Lunar](https://github.com/alin23/Lunar) | MIT | KBC. BlackOut 때 자동 밝기를 끄고 0으로 설정. 설정 키 `keyboardBacklightOffBlackout`(기본 켬) | 이번 기능과 가장 비슷한 선례다. 다만 ID를 `1`로 고정하고, 해제할 때 원래 값이 아니라 0.5로 복원한다 |
| [alin23/mac-utils](https://github.com/alin23/mac-utils) `SetKeyboardBacklight.swift` | MIT | `copyKeyboardBacklightIDs` → `isKeyboardBuiltIn:` → `setBrightness:forKeyboard:` | 키보드 ID 조회 방식을 참고한다 |
| [krishhgg/Insomnia](https://github.com/krishhgg/Insomnia) | MIT | KBC. 호출 전에 selector와 type encoding을 검증 | encoding 검증 방식을 참고한다. 디스플레이 sleep 중에는 0이 읽히고, wake 직후 시스템이 값을 덮어쓴다는 기록이 있다 |
| [dmartoon/MacBook-Keyboard-Backlight-Limiter](https://github.com/dmartoon/MacBook-Keyboard-Backlight-Limiter) | MIT | `BrightnessSystemClient`(BSC) `setProperty:withKey:keyboardID:` | M5 Pro + 26.6.2에서 KBC 쓰기가 효과 없다고 보고. `enableAutoBrightness:` 토글이 영구 설정을 바꾼다고 경고 |
| [RTCK-DEV/mknb](https://github.com/RTCK-DEV/mknb) | MIT | BSC 쓰기 + KBC로 자동 밝기 제어 | 원래 값과 자동 밝기 설정을 저장했다가 복원. 시그널 핸들러로 중단 시에도 복원한다 |
| [anishcreations/nighty-keyboard](https://github.com/anishcreations/nighty-keyboard) | MIT | BSC | 복원 기록을 파일에 원자적으로 저장했다가 복구한다 |
| [EthanRDoesMC/KBPulse](https://github.com/EthanRDoesMC/KBPulse), [rakalex/mac-brightnessctl](https://github.com/rakalex/mac-brightnessctl) | MIT | KBC, ID `1` 고정 | 기기에 따라 크래시나 -1이 반환된다는 보고가 있다. ID를 고정하면 안 된다는 근거다 |
| [pirate/mac-keyboard-brightness](https://github.com/pirate/mac-keyboard-brightness) 과거 코드 | 미표기 | Intel `AppleLMUController` IOKit | 현재 프로젝트들은 쓰지 않는다. 이번 범위에서 제외한다 |
| [MonitorControl](https://github.com/MonitorControl/MonitorControl) | MIT | 키보드 백라이트 기능 없음 | 해당 없음 |

**외부 보고와 직접 확인 결과가 엇갈리는 부분**

- 외부 보고는 M5에서 KBC 쓰기가 LED에 반영되지 않는다고 한다.
- 이 Mac에서는 KBC 쓰기 후 `backlightLevelForKeyboard:`(nits)가 0으로 읽혔다.
- 다만 그 시간 동안 키보드를 직접 보지는 않았다. 따라서 LED 반영 여부는 아직 확정하지 못했다.

**코드 재사용 방침**

- 코드는 복사하지 않고 공개 패턴만 참고한다. 따라서 `THIRD_PARTY_NOTICES.md`에 추가할 항목은 없을 것으로 본다.
- 구현 중 특정 코드를 옮겨 오게 되면 MIT 고지를 추가한다.

## 4. 설계

### 4.1 `KeyboardBacklight` (새 파일 `Sources/KeyboardBacklight.swift`)

- `DisplayBrightness`와 같은 인터페이스를 둔다: `begin()` / `refresh()` / `end()`, `isActive`, `Backend` 주입.
- `Backend`는 다음 항목으로 구성한다.
  - 내장 키보드 ID 목록
  - 내장 디스플레이 활성 여부
  - 밝기 읽기와 쓰기
  - 억제(suppressed)·자동 감광(dimmed) 상태 읽기
- 실제 백엔드는 다음 순서로 동작한다.
  1. `dlopen` 후 `NSClassFromString("KeyboardBrightnessClient")`로 클래스를 얻는다.
  2. 각 selector에 대해 `responds(to:)`와 type encoding(`B@:fQ`, `f@:Q` 등 arm64 기준)을 확인한다. 하나라도 맞지 않으면 백엔드를 비활성으로 둔다. 비공개 API가 바뀌어도 크래시 대신 기능이 꺼지게 하려는 것이다.
  3. ID는 `copyKeyboardBacklightIDs`로 받아 `isKeyboardBuiltIn:`으로 거른다. 고정 ID는 쓰지 않는다.
- **내장 디스플레이 조건**
  - `CGGetActiveDisplayList`의 디스플레이 중 `CGDisplayIsBuiltin`이 참인 것이 있을 때만 끈다.
  - 덮개를 닫은 클램쉘 상태에서는 내장 디스플레이가 활성 목록에서 빠지므로 끄지 않는다.
  - 화면 구성이 바뀌면 `refresh()`가 조건을 다시 평가한다.
    - 가리기 도중 내장 디스플레이가 비활성이 되면 백라이트를 복원한다.
    - 다시 활성이 되면 백라이트를 다시 끈다.
- **저장 규칙**
  - 키보드 ID별 원래 값은 처음 한 번만 저장한다.
  - suppressed나 dimmed 상태일 때 읽은 값과 범위 밖의 값은 저장하지 않는다. 이 경우 그 키보드는 건드리지 않는다.
- **복원 규칙**
  - 현재 값이 여전히 앱이 설정한 0일 때만 원래 값으로 되돌린다.
  - 가리기 중에 사용자가 밝기 키로 값을 바꿨다면 사용자 값을 유지한다.
  - 기존 `DisplayBrightness`와 다른 규칙이다. 키보드 밝기 키는 화면 가리기 중에도 입력이 통과하기 때문이다.
- **자동 밝기(주변광) 설정은 건드리지 않는 것을 기본안으로 한다.**
  - 이유 1: `enableAutoBrightness:`는 시스템 설정의 영구 값이다. 크래시가 나면 꺼진 채 남는다.
  - 이유 2: 이 Mac에서는 자동 밝기를 켠 상태에서도 0이 6초간 유지됐다.
  - 실기기 시험(5절 S2)에서 타이핑이나 주변광 변화로 백라이트가 다시 켜지면 다음 두 가지 중 하나를 추가한다.
    - 가리기 중 `registerNotificationForKeys:keyboardID:block:` 알림을 받으면 0을 다시 쓴다.
    - 또는 자동 밝기를 일시적으로 끈다.
- **쓰기 경로**
  - 기본은 KBC `setBrightness:forKeyboard:`다.
  - S1에서 LED가 꺼지지 않으면 BSC `setProperty:withKey:@"KeyboardBacklightBrightness" keyboardID:`로 바꾼다. 쓰기 후에는 `backlightLevelForKeyboard:`를 다시 읽어 확인한다.

### 4.2 비정상 종료 복구

- 강제 종료하면 백라이트가 꺼진 채 남는다(2절에서 확인).
- `begin()`에서 0을 쓰기 전에 원래 값을 기록 파일에 원자적으로 저장한다. 위치는 `~/Library/Application Support/agenticnights/keyboard-backlight.json`이고, 내용은 ID와 원래 값이다. `end()`에서 기록 파일을 지운다.
- 앱을 실행할 때 기록 파일이 남아 있으면 처리한다.
  - 해당 ID의 현재 값이 0이면 원래 값으로 복원한다.
  - 0이 아니면 사용자가 그사이 값을 바꾼 것으로 보고 덮어쓰지 않는다.
  - 처리 후 기록 파일을 삭제한다.
- 화면 밝기의 강제 종료 문제(README에 기재)는 이번 범위에 포함하지 않는다. 같은 방식을 나중에 적용할 수 있다.

### 4.3 `PrivacyLockController` 연동

| 시점 | 화면 밝기 (기존) | 키보드 백라이트 (추가) |
| --- | --- | --- |
| `start` | `begin()` | 설정이 켜져 있으면 `begin()` |
| 인증 대화상자 표시 (`requestUnlock`) | `end()` | `end()`. 암호 입력에 필요하다 |
| 인증 취소 (`cancelAuthentication`) | `begin()` | 설정이 켜져 있으면 `begin()` |
| `suspend` (sleep, 잠금, 사용자 전환) | `end()` | `end()` |
| `resume` | `begin()` | 설정이 켜져 있으면 `begin()` |
| 화면 구성 변경 (`refreshDisplays`) | `refresh()` | `refresh()`. 내장 디스플레이 조건을 다시 평가한다 |
| `shutdown`, `deinit` | `end()` | `end()` |

- `start(requireAuthentication:)`에 `dimKeyboard: Bool` 인자를 추가한다.
- 화면을 가린 상태에서 설정을 바꾸면 즉시 반영한다. `setKeyboardDimming(_:)`가 `begin()` 또는 `end()`를 호출한다.

### 4.4 설정과 UI

- `VeilSettings`에 `dimKeyboardBacklight: Bool`를 추가하고 CodingKeys에 넣는다.
  - 저장된 값이 없으면 기본값을 쓴다. 기본값은 사용자가 정한다(7절).
  - 이 설정은 인증 없이 바꿀 수 있다. 다른 일반 설정과 같다.
- Settings의 화면 가리기 섹션에 체크박스를 추가한다.
  - 문구 키 `blackout.keyboard`: "Also turn off the keyboard backlight" / "키보드 백라이트도 끄기"
  - 힌트 키 `blackout.keyboardHint`: "Applies only when the built-in display is in use." / "내장 디스플레이를 사용할 때만 적용됩니다."
  - 내장 키보드 백라이트가 없거나 API를 쓸 수 없는 Mac에서는 체크박스를 비활성으로 두고 힌트를 "이 Mac에서는 사용할 수 없습니다."로 바꾼다.
- 메뉴에는 항목을 추가하지 않는다. 메뉴는 자주 쓰는 동작만 둔다.
- `en.json`, `ko.json`에 키를 추가한다. `LocalizationTests`의 키·토큰 일치 검사가 통과해야 한다.
- 진단 스냅샷(`main.swift`의 상태 기록)에 `dimKeyboardBacklight`를 추가한다.

### 4.5 변경 파일

| 파일 | 변경 내용 |
| --- | --- |
| `Sources/KeyboardBacklight.swift` | 신규. 백엔드, 수명주기, 기록 파일 |
| `Sources/PrivacyLockController.swift` | 4.3절 연동 |
| `Sources/Schedule.swift` | `VeilSettings` 필드와 디코딩 |
| `Sources/SettingsWindow.swift` | 체크박스와 사용 가능 여부 표시 |
| `Sources/main.swift` | 설정 전달, 실행 시 복구, 스냅샷 |
| `Resources/Translations/en.json`, `ko.json` | 문구 2개 |
| `Tests/KeyboardBacklightTests.swift`, `Scripts/test.sh` | 가짜 백엔드 테스트 |
| `Tests/ScheduleTests.swift`, `Tests/SettingsWindowTests.swift` | 디코딩 기본값, 체크박스 레이아웃 |
| `README.md` | Blackout 절에 한 문단 (영문·한국어) |

`Scripts/build.sh`는 `Sources/*.swift`를 모두 컴파일하므로 수정할 필요가 없다.

## 5. 검증 계획

### 자동 시험 (가짜 백엔드)

- begin → refresh 반복 → end에서 원래 값이 한 번만 저장되고 정확히 복원되는지
- suppressed·dimmed 상태이거나 범위 밖 값이면 저장하지 않는지
- 사용자가 바꾼 값(0이 아닌 값)은 덮어쓰지 않는지
- 내장 디스플레이 활성 상태가 바뀔 때 복원·재설정되는지. 클램쉘 상태로 시작하면 아무것도 쓰지 않는지
- API를 쓸 수 없는 경우(클래스 없음, encoding 불일치) 아무 동작도 하지 않는지
- 기록 파일: 저장·삭제, 실행 시 복구 조건(현재 값 0일 때만 복원)
- 설정 디코딩: 키가 없을 때 기본값, 기존 설정 보존

### 실기기 시험 (사용자 관찰 필요)

| ID | 내용 | 통과 기준 |
| --- | --- | --- |
| S1 | 가리기 시작 | **키보드 LED가 실제로 꺼진다** (구현 착수 전 단독 probe로 먼저 확인) |
| S2 | 가리기 중 타이핑·마우스 이동, 밝은 곳과 어두운 곳 | 백라이트가 다시 켜지지 않는다. 켜지면 4.1절 대안을 적용한다 |
| S3 | 클릭으로 해제 | 원래 밝기로 복원된다 |
| S4 | 인증 대화상자 표시 / 취소 | 표시 중에는 켜지고, 취소하면 다시 꺼진다 |
| S5 | 가리기 중 밝기 키 조작 후 해제 | 사용자가 바꾼 값이 유지된다 |
| S6 | 외부 모니터 + 클램쉘 | 백라이트를 건드리지 않는다 |
| S7 | sleep/wake, 잠금 | 해제·재개 때 복원·재설정되고, wake 직후 시스템 덮어쓰기가 없다 |
| S8 | 가리기 중 강제 종료 → 재실행 | 기록 파일로 원래 값이 복원된다 |
| S9 | 설정 끄기 / 켜기 (가리기 중) | 즉시 반영된다 |

## 6. 위험과 한계

- **비공개 API다.** macOS 업데이트로 동작이 바뀔 수 있다. encoding 검증으로 크래시는 막을 수 있다. 하지만 "true를 반환하고 효과는 없는" 변화는 다시 읽어 확인하는 방법으로만 일부 감지할 수 있다.
- **확인한 기기가 하나뿐이다.** 검증은 M5 + 26.6.2 한 대로 한다. 다른 칩이나 macOS 13~15에서의 동작은 외부 보고에만 의존한다.
- **Intel Mac은 제외한다.** BOOL encoding이 `c`라서 검증 단계에서 자동으로 비활성이 된다. 빌드가 호스트 아키텍처 전용이라 실제 영향은 Intel에서 직접 빌드하는 경우로 한정된다.
- **재부팅 후 상태는 미확인이다.** 강제 종료 후 재부팅까지 하면 0이 유지되는지 확인하지 않았다. 기록 파일 복구가 이 경우도 처리한다.

## 7. 사용자 결정 사항

1. **기본값**: 켬 / 끔. 켬으로 하면 업데이트한 기존 사용자에게도 바로 적용된다. Lunar는 기본값이 켬이다.
2. **자동 밝기 처리**: S2 결과에 따라 정한다. 권장 순서는 "건드리지 않음 → 알림으로 0 재설정 → 일시적으로 끄기"다.
3. **강제 종료 복구(4.2절)를 이번 범위에 넣을지**: 권장은 포함이다.
4. **S1 probe를 먼저 실행할지**: 약 10초 동안 키보드 LED를 끄고 복원한다. 사용자가 키보드를 보고 있어야 한다.

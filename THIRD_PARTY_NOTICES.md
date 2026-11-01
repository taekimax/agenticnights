# Third-party notices

agenticnights uses the [MIT license](LICENSE). Retain the notices below with
redistributed code and binaries.

## KeepingYouAwake

- Project: [newmarcel/KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake)
- Author and copyright holder: Marcel Dierkes
- License: MIT
- Local implementation: [Sources/SleepPrevention.swift](Sources/SleepPrevention.swift)
- Upstream source: [KYASleepWakeTimer.m](https://github.com/newmarcel/KeepingYouAwake/blob/2be93dd7f390b23fbca934ff3b1ac03468a80077/Packages/KYASleepWakeTimer/Sources/KYASleepWakeTimer/KYASleepWakeTimer.m)
- Upstream license: [LICENSE](https://github.com/newmarcel/KeepingYouAwake/blob/2be93dd7f390b23fbca934ff3b1ac03468a80077/LICENSE)
- Reviewed revision: `2be93dd7f390b23fbca934ff3b1ac03468a80077`
  (source and license checked 2026-10-30).

`Sources/SleepPrevention.swift` adapts KeepingYouAwake’s parent-bounded
`caffeinate` lifecycle and finite-duration `-t` timeout to Swift `Process`.
The display option selects `-di` or `-i`, with `-w <pid>` in both modes.
The original source notice is
`Copyright (c) 2014 Marcel Dierkes. All rights reserved.`

### KeepingYouAwake license text

```text
MIT License

Copyright (c) 2014 - present Marcel Dierkes

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Platform components

AppKit, Foundation, CoreGraphics, ColorSync, Carbon, LocalAuthentication, OSLog,
SF Symbols, DisplayServices, the login framework, `/usr/bin/security` and
`/usr/bin/caffeinate` are macOS components. Their licenses are separate from
this project's MIT license.

## Curtain

- Project: [acamarata/curtain](https://github.com/acamarata/curtain)
- Reviewed revision: `0b2295fc15f5a0e3f2ad8ffd36684f8d7c4809a8` (2026-10-31).
- License: MIT; Copyright (c) 2026 Aric Camarata.
- Local implementations: [DisplayBlackout.swift](Sources/DisplayBlackout.swift) follows gamma blackout and restoration; [PhysicalClickMonitor.swift](Sources/PhysicalClickMonitor.swift) uses event-source classification with global/local AppKit mouse monitors; [PrivacyLockController.swift](Sources/PrivacyLockController.swift) uses temporary non-key black backdrops during system authentication and the macOS lock request. Input interception and the former app-password prompt are removed.
- The current implementation is recorded in [the 2.0 delivery record](docs/no-permission-delivery-2026-11-02.md); [the earlier record](docs/privacy-protection-2026-10-31.md) preserves historical differences. [RustDesk display reconfiguration handling](https://github.com/rustdesk/rustdesk/blob/3b7e2cebd9303a43eecb9bc96921548df846f45d/src/platform/macos.mm) informs event-triggered gamma refresh. No RustDesk source code is incorporated.

```text
MIT License

Copyright (c) 2026 Aric Camarata

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

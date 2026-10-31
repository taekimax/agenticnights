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

`Sources/SleepPrevention.swift` adapts the `caffeinate -di -w <pid>` lifecycle
from KeepingYouAwake to Swift `Process`. The original source notice is
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

AppKit, Foundation, Carbon, OSLog, SF Symbols and `/usr/bin/caffeinate` are macOS
components. Their licenses are separate from this project's MIT license.

## Curtain

- Project: [acamarata/curtain](https://github.com/acamarata/curtain)
- Reviewed revision: `0b2295fc15f5a0e3f2ad8ffd36684f8d7c4809a8` (2026-10-31).
- License: MIT; Copyright (c) 2026 Aric Camarata.
- Local implementations: `PhysicalInputFilter.swift`, `DisplayBlackout.swift`, and `PrivacyLockController.swift` follow Curtain's physical-input filtering, gamma blackout, non-key password prompt, and macOS lock fallback.
- Differences and RustDesk design references are recorded in `docs/privacy-protection-2026-10-31.md`. No RustDesk source code is incorporated.

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

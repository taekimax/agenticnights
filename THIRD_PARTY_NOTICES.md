# Third-party notices

agenticnights is released under the MIT License in [LICENSE](LICENSE).
The following attribution and license must also be retained when distributing
copies or substantial portions of the corresponding adapted code, including
binary distributions of agenticnights.

## KeepingYouAwake

- Project: [newmarcel/KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake)
- Author and copyright holder: Marcel Dierkes
- License: MIT
- Local implementation: [Sources/SleepPrevention.swift](Sources/SleepPrevention.swift)
- Upstream source: [KYASleepWakeTimer.m](https://github.com/newmarcel/KeepingYouAwake/blob/2be93dd7f390b23fbca934ff3b1ac03468a80077/Packages/KYASleepWakeTimer/Sources/KYASleepWakeTimer/KYASleepWakeTimer.m)
- Upstream license: [LICENSE](https://github.com/newmarcel/KeepingYouAwake/blob/2be93dd7f390b23fbca934ff3b1ac03468a80077/LICENSE)
- Reviewed revision: `2be93dd7f390b23fbca934ff3b1ac03468a80077`
  (source and license checked 2026-10-30).

The process-lifetime `caffeinate -di -w <pid>` approach and its start/stop
lifecycle were adapted into Swift using Foundation `Process`. agenticnights
implements its own screen covers, settings, schedules and finite-timer handling.
It does not bundle KeepingYouAwake's application, icons, updater, or dependencies.
The original source file carries the notice
`Copyright (c) 2014 Marcel Dierkes. All rights reserved.`; the repository's MIT
grant and copyright notice are reproduced verbatim below.

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

AppKit, Foundation, Carbon, OSLog, SF Symbols supplied by the system, and
`/usr/bin/caffeinate` are provided by macOS or Apple's development tools.
Their implementations and the `caffeinate` executable are not copied into this
repository or app bundle. This project's MIT license does not relicense those
platform components. No third-party package manager or bundled external library
is required to build agenticnights.

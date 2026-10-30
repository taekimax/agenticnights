#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h}"
build_root="$project_root/.build"
app_bundle="$build_root/agenticnights.app"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources" "$build_root/ModuleCache"
xcrun swiftc -swift-version 5 -O -num-threads 2 \
  -module-cache-path "$build_root/ModuleCache" \
  -target "$(uname -m)-apple-macosx13.0" \
  "$project_root"/Sources/*.swift \
  -framework AppKit -framework Carbon \
  -o "$app_bundle/Contents/MacOS/agenticnights"
cp "$project_root/Resources/Info.plist" "$app_bundle/Contents/Info.plist"
cp "$project_root/LICENSE" "$app_bundle/Contents/Resources/LICENSE"
cp "$project_root/THIRD_PARTY_NOTICES.md" "$app_bundle/Contents/Resources/THIRD_PARTY_NOTICES.md"
chmod u+w "$app_bundle"
codesign --force --sign - --identifier com.tk.agenticnights "$app_bundle"
codesign --verify --deep --strict --verbose=2 "$app_bundle"
print -r -- "$app_bundle"

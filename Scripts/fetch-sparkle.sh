#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h}"
version=2.10.1
checksum=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
dependency="$project_root/.build/Sparkle-$version"
if [[ ! -f "$dependency/.verified-$checksum" ]]; then
  mkdir -p "$dependency"
  archive="$dependency/Sparkle-$version.tar.xz"
  curl --fail --location --retry 3 --output "$archive" \
    "https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-$version.tar.xz"
  print -r -- "$checksum  $archive" | shasum -a 256 --check >&2
  tar -xJf "$archive" -C "$dependency"
  touch "$dependency/.verified-$checksum"
fi
print -r -- "$dependency"

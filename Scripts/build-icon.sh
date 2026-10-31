#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h}"
iconset="$project_root/.build/AppIcon.iconset"
source_image="$project_root/Resources/Brand/agenticnights-moon-transparent-v1.png"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$source_image" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  doubled=$((size * 2))
  sips -z "$doubled" "$doubled" "$source_image" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$project_root/.build/AppIcon.icns"

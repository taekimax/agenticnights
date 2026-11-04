#!/bin/zsh
# Build once, archive with symlinks intact, and sign using the login Keychain.
set -euo pipefail
project_root="${0:A:h:h}"
if (( $# != 1 )); then
  print -u2 'Usage: ./Scripts/prepare-release.sh release-notes.html'
  exit 1
fi
notes="${1:A}"
[[ -f "$notes" ]]
sparkle_root="$("$project_root/Scripts/fetch-sparkle.sh")"
plist="$project_root/Resources/Info.plist"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$plist")
build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$plist")
expected_key=$(/usr/libexec/PlistBuddy -c 'Print SUPublicEDKey' "$plist")
actual_key=$("$sparkle_root/bin/generate_keys" --account com.tk.agenticnights -p)
[[ "$expected_key" == "$actual_key" ]] || { print -u2 'Signing key does not match Info.plist'; exit 1; }
output="$project_root/.build/releases/v$version"
[[ ! -e "$output" ]] || { print -u2 "Release already staged: $output"; exit 1; }
"$project_root/Scripts/build.sh"
mkdir -p "$output"
asset="agenticnights-$version-$(uname -m)"
ditto -c -k --sequesterRsrc --keepParent "$project_root/.build/agenticnights.app" "$output/$asset.zip"
cp "$notes" "$output/$asset.html"
"$sparkle_root/bin/generate_appcast" --account com.tk.agenticnights \
  --download-url-prefix "https://github.com/taekimax/agenticnights/releases/download/v$version/" \
  --link https://github.com/taekimax/agenticnights \
  --full-release-notes-url "https://github.com/taekimax/agenticnights/releases/tag/v$version" \
  --embed-release-notes --maximum-deltas 0 "$output"
python3 - "$output/appcast.xml" "$build" "$output/$asset.zip" <<'PY'
import pathlib, sys, xml.etree.ElementTree as ET
path, build, archive = sys.argv[1:]
ns = {'s': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}
item = ET.parse(path).find('./channel/item')
assert item.findtext('s:version', namespaces=ns) == build
enclosure = item.find('enclosure')
assert int(enclosure.attrib['length']) == pathlib.Path(archive).stat().st_size
assert enclosure.attrib['{'+ns['s']+'}edSignature']
print('PASS: appcast build, archive length and EdDSA signature present')
PY
signature=$(python3 - "$output/appcast.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
print(ET.parse(sys.argv[1]).find('./channel/item/enclosure').attrib['{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature'])
PY
)
"$sparkle_root/bin/sign_update" --account com.tk.agenticnights --verify "$output/$asset.zip" "$signature"
print -r -- "Ready for GitHub Release: $output"

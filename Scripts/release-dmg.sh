#!/bin/zsh
# Builds Cafe.dmg the way AnyAction ships: Developer ID signature, hardened
# runtime, a styled window (background, Cafe on the left, Applications on the
# right), notarized and stapled so it opens with a double-click on any Mac.
#
#   Scripts/release-dmg.sh               the real release
#   Scripts/release-dmg.sh --dry-run     ad-hoc signed, no notarization (to try the layout)
#   Scripts/release-dmg.sh --skip-layout plain window, no Finder scripting
#
# Needs, once, on this Mac (the same ones AnyAction's scripts/release.sh uses):
#   - the "Developer ID Application" certificate of team 3KK6H4J24W in the keychain
#   - a notarytool keychain profile, by default "MainLabNotary":
#       xcrun notarytool store-credentials MainLabNotary --apple-id … --team-id 3KK6H4J24W
# The first run with the layout asks once to let Terminal control Finder: allow it.
set -euo pipefail

team="3KK6H4J24W"
notary_profile="${CAFE_NOTARY_PROFILE:-MainLabNotary}"
dry_run=false
layout=true
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    --skip-layout) layout=false ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

root="${0:A:h:h}"
build="$root/.build/release"
archive="$build/Cafe.xcarchive"
export_dir="$build/export"
staging="$build/dmg"
rw_dmg="$build/Cafe-rw.dmg"
dmg="$root/Cafe.dmg"
background="$root/Scripts/dmg_bg.tiff"

say() { print -P "%F{cyan}▸ $1%f"; }
fail() { print -P "%F{red}✘ $1%f" >&2; exit 1; }

rm -rf "$build" "$dmg"
mkdir -p "$build"

if $dry_run; then
  say "Building (ad-hoc signed, dry run)"
  xcodebuild -project "$root/Cafe.xcodeproj" -scheme Cafe -configuration Release \
    -derivedDataPath "$build/dd" CODE_SIGN_IDENTITY=- ENABLE_HARDENED_RUNTIME=YES build -quiet
  mkdir -p "$export_dir"
  cp -R "$build/dd/Build/Products/Release/Cafe.app" "$export_dir/"
else
  security find-identity -v -p codesigning | grep -q "Developer ID Application: .*($team)" \
    || fail "no Developer ID Application certificate for team $team"
  xcrun notarytool history --keychain-profile "$notary_profile" >/dev/null 2>&1 \
    || fail "no notarytool keychain profile \"$notary_profile\""
  say "Archiving with Developer ID"
  xcodebuild -project "$root/Cafe.xcodeproj" -scheme Cafe -configuration Release \
    -archivePath "$archive" archive -quiet \
    DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" \
    ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS=--timestamp
  cat > "$build/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$team</string>
  <key>signingStyle</key><string>manual</string>
</dict></plist>
PLIST
  xcodebuild -exportArchive -archivePath "$archive" -exportPath "$export_dir" \
    -exportOptionsPlist "$build/ExportOptions.plist" -quiet
fi

app="$export_dir/Cafe.app"
[[ -d "$app" ]] || fail "the build produced no Cafe.app"
say "Checking the signature"
codesign --verify --deep --strict "$app"
$dry_run || codesign -dvv "$app" 2>&1 | grep -q "flags=.*runtime" || $dry_run || fail "hardened runtime is off"

say "Laying out the disk image"
mkdir -p "$staging/.background"
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
[[ -f "$background" ]] && cp "$background" "$staging/.background/background.tiff"
hdiutil create -quiet -volname "Cafe" -srcfolder "$staging" -fs HFS+ -format UDRW -ov "$rw_dmg"

if $layout && [[ -f "$background" ]]; then
  # The window matches the background's 1x size.
  w=$(sips -g pixelWidth "$root/Scripts/dmg_bg_1x.png" | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$root/Scripts/dmg_bg_1x.png" | awk '/pixelHeight/{print $2}')
  mount_point=$(hdiutil attach -readwrite -noverify -noautoopen "$rw_dmg" | awk -F'\t' '/\/Volumes\//{print $NF}')
  osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "Cafe"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 200 + $w, 120 + $h}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 128
    set text size of opts to 13
    set background picture of opts to file ".background:background.tiff"
    set position of item "Cafe.app" of container window to {round($w * 0.28), round($h * 0.5)}
    set position of item "Applications" of container window to {round($w * 0.72), round($h * 0.5)}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT
  sync
  hdiutil detach -quiet "$mount_point"
fi

say "Compressing"
hdiutil convert -quiet "$rw_dmg" -format ULFO -o "$dmg"
rm -f "$rw_dmg"

if $dry_run; then
  print -P "%F{yellow}! dry run: not signed with Developer ID, not notarized%f"
else
  say "Signing and notarizing the disk image"
  codesign --sign "Developer ID Application" --timestamp "$dmg"
  xcrun notarytool submit "$dmg" --keychain-profile "$notary_profile" --wait
  xcrun stapler staple "$dmg"
  spctl -a -t open --context context:primary-signature -v "$dmg"
fi

print -P "%F{green}✔ $dmg%f"
print "Upload it to anyaction.app/downloads/Cafe.dmg."

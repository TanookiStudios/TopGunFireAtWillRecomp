#!/usr/bin/env bash
# Build "Top Gun Fire at Will.app" for every Mac (Apple chips and Intel,
# macOS 11+), signed with the Developer ID, and zip it as
# TopGunFireAtWill-Mac.zip. Copies the zip (and the app) to ~/Downloads.
#
#   tools/make_app.sh            build + sign + zip
#   tools/make_app.sh --notarize also notarize with Apple and staple, then zip
#
# Needs: vendor/ from setup.sh, generated/ from tools/regen.sh (your disc is
# needed to make it, and again here to scan the finished app for game bytes),
# a "Developer ID Application" certificate (without one the app is signed
# ad-hoc and says so), and for --notarize the notarytool keychain profile
# "notarytool". The app contains no disc data: the launcher asks for the disc.
# SDL3 is built from source by the engine's CMake and linked into the program.
#
# The program inside is named TopGunFireAtWill because on a Mac the settings
# folder is ~/Library/Application Support/<program name>/ (patch 0002).
set -euo pipefail
cd "$(dirname "$0")/.."
NOTARIZE=0; [ "${1:-}" = "--notarize" ] && NOTARIZE=1
ID="Developer ID Application"
NAME="Top Gun Fire at Will"   # no colon: Finder shows it, and colons are path separators
EXE=TopGunFireAtWill

# Homebrew's SDL3/freetype/harfbuzz must never leak into the Mac build: they
# are Apple-chip-only dylibs that other Macs do not have. Hide them from CMake;
# the engine then builds SDL3 itself, static and universal.
cmake -S . -B build-mac -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
    -DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON \
    -DCMAKE_DISABLE_FIND_PACKAGE_Freetype=ON -DCMAKE_DISABLE_FIND_PACKAGE_PkgConfig=ON \
    -DCMAKE_IGNORE_PREFIX_PATH=/opt/homebrew:/usr/local \
    -DPSXRECOMP_REQUIRE_GAME_C=ON >/dev/null
cmake --build build-mac --parallel 8 >/dev/null

# The engine's own packager gathers what the runtime reads beside the program
# (assets, the bundled OpenBIOS and its notice, game.toml, the mod catalog,
# licenses). No overlay cache: it is compiled from the disc, so it never ships.
bash tools/stage_release.sh build-mac macos-universal
STAGE=dist/stage-game-macos-universal

APP="dist/$NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -R "$STAGE/." "$APP/Contents/MacOS/"
# The launcher looks for its pictures under Contents/Resources inside a bundle.
cp -R "$STAGE/assets" "$APP/Contents/Resources/assets"
cp assets/icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)
VERSION=${VERSION:-$(tr -d '[:space:]' < VERSION)}
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>com.tanookistudios.topgunfireatwillrecomp</string>
  <key>CFBundleExecutable</key><string>$EXE</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.simulation-games</string>
</dict></plist>
PLIST

# Checks before signing: both chips, nothing but system libraries, no disc data.
BIN="$APP/Contents/MacOS/$EXE"
ARCHS=$(lipo -archs "$BIN")
case "$ARCHS" in *arm64*x86_64*|*x86_64*arm64*) ;; *) echo "FAIL: app is not universal (got: $ARCHS)" >&2; exit 1;; esac
BAD=$(otool -L "$BIN" | grep '^[[:space:]]' | awk '{print $1}' | grep -v -E '^(/usr/lib/|/System/Library/)' || true)
if [ -n "$BAD" ]; then echo "FAIL: app needs libraries other Macs do not have:" >&2; echo "$BAD" >&2; exit 1; fi
python3 -I tools/release_scan.py "$APP"

if [ -n "$(security find-identity -v -p codesigning | grep "$ID")" ]; then
    codesign --force --deep --options runtime --timestamp --sign "$ID" "$APP" >/dev/null
    echo "Signed with: $ID"
else
    # Not notarizable, and other Macs will warn; fine for a local test.
    codesign --force --deep --sign - "$APP" >/dev/null
    echo "WARNING: no Developer ID certificate in the keychain; signed AD-HOC." >&2
    [ "$NOTARIZE" = 1 ] && { echo "FAIL: --notarize needs the Developer ID certificate" >&2; exit 1; }
fi
codesign --verify --deep --strict "$APP"

ZIP=dist/TopGunFireAtWill-Mac.zip
rm -f "$ZIP"
if [ "$NOTARIZE" = 1 ]; then
    ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile notarytool --wait
    xcrun stapler staple "$APP"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    spctl --assess --type execute --verbose "$APP"
else
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "NOT notarized: other Macs will show a Gatekeeper warning. Run with --notarize for release."
fi

# Finished games always go to Downloads (Maddie, 14 Oct 2026).
cp -f "$ZIP" "$HOME/Downloads/"
rm -rf "$HOME/Downloads/$NAME.app"
cp -R "$APP" "$HOME/Downloads/"
echo "$HOME/Downloads/TopGunFireAtWill-Mac.zip"
echo "$HOME/Downloads/$NAME.app"

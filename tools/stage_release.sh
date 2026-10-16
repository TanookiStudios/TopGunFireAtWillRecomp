#!/usr/bin/env bash
# Gather one platform's release files with the engine's own packager (stage
# only, no zip): dist/stage-game-<artifact>/. Used by make_app.sh,
# make_windows_zip.sh and make_linux.sh.
#   tools/stage_release.sh <build-dir> <artifact>
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD=$1 ART=$2
STAGE="dist/stage-game-$ART"
if [ "$ART" = windows-x64 ]; then
    # The engine's packager wants MinGW DLLs beside the .exe, but ours is fully
    # static (cmake/mingw-w64.cmake), so stage the same file set directly.
    rm -rf "$STAGE"; mkdir -p "$STAGE/bios" "$STAGE/licenses" "$STAGE/saves"
    cp "$BUILD/TopGunFireAtWill.exe" "$BUILD/game.toml" "$BUILD/game_options.toml" "$BUILD/psx_game_version.txt" "$STAGE/"
    cp -R "$BUILD/assets" "$BUILD/mods" "$STAGE/"
    cp "$BUILD/bios/openbios.bin" "$BUILD/bios/OpenBIOS.LICENSE" "$STAGE/bios/"
    cp vendor/psxrecomp/runtime/licenses/* "$STAGE/licenses/"
    cp vendor/psxrecomp/LICENSE "$STAGE/licenses/psxrecomp-LICENSE"
    cp vendor/recomp-ui/LICENSE "$STAGE/licenses/recomp-ui-LICENSE"
    cp LICENSE THIRD_PARTY_NOTICES.md "$STAGE/"
    echo "staged $STAGE"
    exit 0
fi
RELEASE_VERSION=$(tr -d '[:space:]' < VERSION) \
bash vendor/psxrecomp/tools/package_game_release.sh \
    --build-dir "$BUILD" \
    --artifact "$ART" \
    --zip-prefix TopGunFireAtWill \
    --exe-name TopGunFireAtWill \
    --display-name "Top Gun: Fire at Will" \
    --recompiler-build vendor/psxrecomp/recompiler/build \
    --no-overlay-toolchain \
    --ship-without-overlay-cache-because "an overlay cache is compiled from the disc, and nothing made from the disc ships" \
    --disc-hint "your own Top Gun: Fire at Will (USA) disc" \
    --stage-only >/dev/null
# Our own files the engine does not know about.
cp LICENSE THIRD_PARTY_NOTICES.md "$STAGE/"
echo "staged $STAGE"
